// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// ─────────────────────────────────────────────────────────────────────────────
// Change Data Capture (CDC) Sync Engine
// ─────────────────────────────────────────────────────────────────────────────

// SyncStatus represents the state of a sync queue item.
type SyncStatus string

const (
	SyncStatusPending  SyncStatus = "pending"   // Not yet pushed
	SyncStatusSyncing  SyncStatus = "syncing"   // Currently being pushed
	SyncStatusSynced   SyncStatus = "synced"    // Successfully pushed
	SyncStatusFailed   SyncStatus = "failed"    // Push failed, will retry
	SyncStatusConflict SyncStatus = "conflict"  // Server resolved conflict
)

// SyncOperation is the type of data change captured.
type SyncOperation string

const (
	SyncOpInsert SyncOperation = "INSERT"
	SyncOpUpdate SyncOperation = "UPDATE"
	SyncOpDelete SyncOperation = "DELETE"
)

// SyncQueueItem represents a single CDC delta ready for sync.
// Every write to the local SQLite creates one of these.
type SyncQueueItem struct {
	ID          string          `db:"id"           json:"id"`
	DeviceID    string          `db:"device_id"    json:"device_id"`    // Source device UUID
	TableName   string          `db:"table_name"   json:"table_name"`   // e.g., "sales", "products"
	RecordID    string          `db:"record_id"    json:"record_id"`    // PK of the changed row
	Operation   SyncOperation   `db:"operation"    json:"operation"`
	Payload     json.RawMessage `db:"payload"      json:"payload"`      // Full JSON of the changed entity
	LocalSeq    int64           `db:"local_seq"    json:"local_seq"`    // Monotonic counter on device
	Status      SyncStatus      `db:"status"       json:"status"`
	RetryCount  int             `db:"retry_count"  json:"retry_count"`
	ErrorMsg    *string         `db:"error_msg"    json:"error_msg,omitempty"`
	CreatedAt   time.Time       `db:"created_at"   json:"created_at"`
	SyncedAt    *time.Time      `db:"synced_at"    json:"synced_at,omitempty"`
}

func NewSyncQueueItem(deviceID, table, recordID string, op SyncOperation, payload interface{}) (*SyncQueueItem, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return &SyncQueueItem{
		ID:        uuid.NewString(),
		DeviceID:  deviceID,
		TableName: table,
		RecordID:  recordID,
		Operation: op,
		Payload:   data,
		Status:    SyncStatusPending,
		CreatedAt: time.Now().UTC(),
	}, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Device Registry
// ─────────────────────────────────────────────────────────────────────────────

// DeviceRegistry tracks all devices that sync with this server.
type DeviceRegistry struct {
	DeviceID     string    `db:"device_id"      json:"device_id"`
	DeviceName   string    `db:"device_name"    json:"device_name"` // e.g., "Counter-1-Windows"
	StaffID      string    `db:"staff_id"       json:"staff_id"`
	Platform     string    `db:"platform"       json:"platform"` // "windows" | "android"
	LastSyncAt   *time.Time `db:"last_sync_at"   json:"last_sync_at,omitempty"`
	LastSyncSeq  int64     `db:"last_sync_seq"  json:"last_sync_seq"` // Highest local_seq received
	IsActive     bool      `db:"is_active"      json:"is_active"`
	RegisteredAt time.Time `db:"registered_at"  json:"registered_at"`
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Request / Response (API contract)
// ─────────────────────────────────────────────────────────────────────────────

// SyncPushRequest is the payload sent by Flutter to /api/v1/sync/push.
type SyncPushRequest struct {
	DeviceID string           `json:"device_id"`
	Items    []SyncQueueItem  `json:"items"`
}

// SyncPushResponse is the server's reply after processing a batch.
type SyncPushResponse struct {
	Accepted  []string          `json:"accepted"`   // IDs successfully applied
	Conflicts []ConflictResult  `json:"conflicts"`  // IDs with conflict info
	Errors    []SyncError       `json:"errors"`     // IDs that errored
}

// ConflictResult describes a Last-Write-Wins resolution outcome.
type ConflictResult struct {
	ItemID       string          `json:"item_id"`
	RecordID     string          `json:"record_id"`
	TableName    string          `json:"table_name"`
	Winner       string          `json:"winner"` // "client" | "server"
	ServerRecord json.RawMessage `json:"server_record,omitempty"`
}

// SyncError records a sync item that could not be applied.
type SyncError struct {
	ItemID  string `json:"item_id"`
	Message string `json:"message"`
}
