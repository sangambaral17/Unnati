// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.
// Founder: Sangam Baral

package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"github.com/walsong/unnati-backend/internal/api"
	"github.com/walsong/unnati-backend/internal/middleware"
	"github.com/walsong/unnati-backend/internal/queue"
)

func main() {
	// ── Load environment ──────────────────────────────────────────────────────
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, reading from environment")
	}

	// ── Logger ────────────────────────────────────────────────────────────────
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	port := getEnv("PORT", "8080")
	dbURL := getEnv("DATABASE_URL", "postgres://unnati:unnati@localhost:5432/unnati?sslmode=disable")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379/0")
	jwtSecret := getEnv("JWT_SECRET", "change-me-in-production")

	// ── PostgreSQL ────────────────────────────────────────────────────────────
	db, err := sqlx.Connect("postgres", dbURL)
	if err != nil {
		logger.Fatal("Failed to connect to PostgreSQL", zap.Error(err))
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	logger.Info("Connected to PostgreSQL")

	// ── Redis ─────────────────────────────────────────────────────────────────
	rdb, err := connectRedis(redisURL)
	if err != nil {
		logger.Fatal("Failed to connect to Redis", zap.Error(err))
	}
	logger.Info("Connected to Redis")

	// ── Sync Queue Consumer (background) ─────────────────────────────────────
	syncQueue := queue.NewRedisSyncQueue(rdb, logger)
	go syncQueue.StartConsumer(context.Background(), db)

	// ── Gin Router ────────────────────────────────────────────────────────────
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.Logger(logger))
	router.Use(middleware.CORS())

	// ── Health Check ──────────────────────────────────────────────────────────
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "unnati-backend",
			"version": "0.1.0",
		})
	})

	// ── API v1 Routes ─────────────────────────────────────────────────────────
	v1 := router.Group("/api/v1")
	v1.Use(middleware.JWTAuth(jwtSecret))
	{
		api.RegisterSyncRoutes(v1, db, syncQueue, logger)
		api.RegisterProductRoutes(v1, db, logger)
		api.RegisterSaleRoutes(v1, db, logger)
		api.RegisterLedgerRoutes(v1, db, logger)
		api.RegisterStaffRoutes(v1, db, logger, jwtSecret)
	}

	// Auth routes (no JWT required)
	auth := router.Group("/api/v1/auth")
	api.RegisterAuthRoutes(auth, db, logger, jwtSecret)

	// ── HTTP Server with graceful shutdown ────────────────────────────────────
	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("Unnati Backend starting", zap.String("port", port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}
	logger.Info("Server exited cleanly")
}

func connectRedis(url string) (*redis.Client, error) {
	opt, err := redis.ParseURL(url)
	if err != nil {
		return nil, err
	}
	rdb := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return rdb, rdb.Ping(ctx).Err()
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
