// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

// Package queue implements a Redis List-based reliable message queue for CDC sync.
// The queue ensures that sync operations survive API restarts by persisting
// to Redis AOF (Append-Only File). If the home server goes offline for up to
// 48 hours, the Flutter device stores deltas locally in SQLite and retries.
package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"github.com/walsong/unnati-backend/internal/domain"
)

const (
	syncQueueKey    = "unnati:sync_queue"    // Main queue
	syncDLQKey      = "unnati:sync_dlq"      // Dead letter queue (failed after max retries)
	maxRetries      = 5
	retryBackoffBase = 2 * time.Second
)

// RedisSyncQueue wraps a Redis client for reliable CDC message queuing.
type RedisSyncQueue struct {
	rdb *redis.Client
	log *zap.Logger
}

// NewRedisSyncQueue creates a new queue.
func NewRedisSyncQueue(rdb *redis.Client, log *zap.Logger) *RedisSyncQueue {
	return &RedisSyncQueue{rdb: rdb, log: log}
}

// Enqueue pushes a SyncQueueItem to the Redis list.
func (q *RedisSyncQueue) Enqueue(ctx context.Context, item *domain.SyncQueueItem) error {
	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("queue: marshal error: %w", err)
	}
	return q.rdb.RPush(ctx, syncQueueKey, data).Err()
}

// StartConsumer runs a blocking consumer loop (BLPOP) that processes sync items.
// This runs in a goroutine and applies items to PostgreSQL for reporting/analytics.
// Note: The primary sync write path is in the HTTP sync handler.
// This consumer handles async, non-critical analytics updates.
func (q *RedisSyncQueue) StartConsumer(ctx context.Context, db *sqlx.DB) {
	q.log.Info("Sync queue consumer started", zap.String("queue", syncQueueKey))

	for {
		select {
		case <-ctx.Done():
			q.log.Info("Sync queue consumer stopped")
			return
		default:
		}

		// Blocking pop with 5s timeout to allow graceful shutdown checks
		results, err := q.rdb.BLPop(ctx, 5*time.Second, syncQueueKey).Result()
		if err == redis.Nil {
			continue // Timeout — loop and check ctx.Done()
		}
		if err != nil {
			q.log.Error("Redis BLPop error", zap.Error(err))
			time.Sleep(time.Second)
			continue
		}

		if len(results) < 2 {
			continue
		}

		var item domain.SyncQueueItem
		if err := json.Unmarshal([]byte(results[1]), &item); err != nil {
			q.log.Error("Failed to unmarshal sync item", zap.Error(err))
			continue
		}

		q.processItem(ctx, db, item)
	}
}

func (q *RedisSyncQueue) processItem(ctx context.Context, db *sqlx.DB, item domain.SyncQueueItem) {
	err := q.applyToAnalytics(ctx, db, item)
	if err != nil {
		item.RetryCount++
		errMsg := err.Error()
		item.ErrorMsg = &errMsg

		if item.RetryCount >= maxRetries {
			q.log.Error("Sync item exceeded max retries, moving to DLQ",
				zap.String("item_id", item.ID),
				zap.String("table", item.TableName),
			)
			q.sendToDLQ(ctx, item)
			return
		}

		// Re-enqueue with backoff
		backoff := retryBackoffBase * time.Duration(item.RetryCount)
		time.Sleep(backoff)

		if enqErr := q.Enqueue(ctx, &item); enqErr != nil {
			q.log.Error("Failed to re-enqueue item", zap.Error(enqErr))
		}
		return
	}

	q.log.Debug("Sync item processed", zap.String("item_id", item.ID), zap.String("table", item.TableName))
}

// applyToAnalytics handles analytics-side updates triggered by CDC events.
// The sync handler handles the primary data writes; this handles side effects.
func (q *RedisSyncQueue) applyToAnalytics(_ context.Context, db *sqlx.DB, item domain.SyncQueueItem) error {
	switch item.TableName {
	case "sale_items":
		// Deduct stock on completed sales
		var si domain.SaleItem
		if err := json.Unmarshal(item.Payload, &si); err != nil {
			return err
		}
		if item.Operation == domain.SyncOpInsert {
			_, err := db.Exec(
				`UPDATE products SET stock_qty = stock_qty - $1, updated_at = NOW()
				 WHERE id = $2 AND stock_qty >= $1`,
				si.Qty, si.ProductID,
			)
			return err
		}
	case "ledger_entries":
		// Mark overdue entries
		_, _ = db.Exec(`
			UPDATE ledger_entries
			SET is_overdue = TRUE
			WHERE type = 'debit' AND is_overdue = FALSE
			  AND due_date IS NOT NULL AND due_date < NOW()`)
	}
	return nil
}

func (q *RedisSyncQueue) sendToDLQ(ctx context.Context, item domain.SyncQueueItem) {
	data, _ := json.Marshal(item)
	q.rdb.RPush(ctx, syncDLQKey, data)
}

// QueueLength returns how many items are waiting to be processed.
func (q *RedisSyncQueue) QueueLength(ctx context.Context) (int64, error) {
	return q.rdb.LLen(ctx, syncQueueKey).Result()
}
