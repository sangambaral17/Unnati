# ============================================================================
# Unnati Retail OS — Multi-Stage Docker Build
# Copyright (c) 2026 Walsong Group. All rights reserved.
# ============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Download dependencies (cached layer)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s -X main.Version=0.1.0" \
    -o unnati-server ./cmd/server/main.go

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    wget \
    curl

# Create non-root user for security
RUN addgroup -g 1001 unnati && adduser -D -u 1001 -G unnati unnati

WORKDIR /app

# Copy binary and migrations
COPY --from=builder /build/unnati-server ./
COPY --from=builder /build/db/migrations ./db/migrations/
COPY --chown=unnati:unnati . .

USER unnati

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/unnati-server"]
