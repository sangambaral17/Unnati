# 🏪 Unnati Retail OS

> **The Local-First, Privacy-First Retail Operating System for Nepal**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8?logo=go)](https://golang.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://www.postgresql.org)
[![TimescaleDB](https://img.shields.io/badge/TimescaleDB-Enabled-FDB515)](https://www.timescale.com)
[![License](https://img.shields.io/badge/License-Proprietary-red)](./LICENSE)

---

**Founder & CEO:** Sangam Baral  
**Company:** Walsong Group  
**Market:** Nepal (VAT/PAN Compliant · Annexure 10 · Fonepay QR)  
**Version:** 0.1.0-alpha  
**Year:** 2026

---

## 🌟 What is Unnati?

Unnati is a **world-class Retail Operating System** built specifically for Nepal's hardware, electrical, and kirana sectors. It is built on a **Local-First** philosophy — your data lives on your device, your app responds in milliseconds, and your business keeps running even when the internet is down for days.

```
┌─────────────────────────────────────────────────────────────────┐
│                    UNNATI ARCHITECTURE                          │
│                                                                 │
│  ┌──────────────────┐     Silent Sync      ┌─────────────────┐ │
│  │   Flutter App    │ ──────────────────►  │  Home Server    │ │
│  │  (Windows/Android│     CDC Deltas        │  (Go + Postgres │ │
│  │                  │                       │  + Redis)       │ │
│  │  SQLite (Drift)  │ ◄──────────────────  │                 │ │
│  │  Source of Truth │     Conflict Resolve  │  Tailscale VPN  │ │
│  └──────────────────┘                       └─────────────────┘ │
│                                                                 │
│  ✅ Zero Loading Spinners   ✅ 48h Offline Resilience           │
│  ✅ Privacy-First           ✅ Smart Analytics (TimescaleDB)    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Monorepo Structure

```
Unnati/
├── apps/
│   └── unnati_pos/          # Flutter App (Windows Desktop + Android)
│       ├── lib/
│       │   ├── core/        # Auth, Theme, Router
│       │   ├── data/        # Drift DB, Repositories
│       │   ├── domain/      # Business Logic, Entities
│       │   ├── presentation/# Screens & Widgets
│       │   └── services/    # Sync, VAT, Printing, Fonepay
│       └── pubspec.yaml
│
├── backend/                 # Go API Server
│   ├── cmd/server/          # Entry point
│   ├── internal/
│   │   ├── api/             # HTTP Handlers & Routes
│   │   ├── domain/          # Go Structs (Product, Sale, Ledger...)
│   │   ├── middleware/      # JWT Auth, RBAC
│   │   ├── queue/           # Redis Queue
│   │   └── repository/      # DB Layer (sqlx)
│   ├── db/migrations/       # PostgreSQL DDL
│   ├── Dockerfile
│   ├── go.mod
│   └── .env.example
│
├── infra/                   # Home Server Infrastructure
│   ├── docker-compose.yml   # postgres + redis + api + tailscale + nginx
│   ├── nginx/               # Reverse Proxy Config
│   └── postgres/            # DB Init Scripts
│
├── .github/
│   └── workflows/           # Go CI + Flutter Analyze
│
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🚀 Key Modules

| Module | Description |
|---|---|
| **Inventory Pro** | Multi-unit support (Buy in Rolls → Sell in Meters/Pieces) |
| **Smart Billing** | VAT/PAN compliant, Hold Bill, ESC/POS thermal printing (58mm/80mm) |
| **Digital Ledger (Udhari)** | Credit aging, Fonepay QR reconciliation |
| **Staff Control** | JWT RBAC — Cashier cannot see Cost Price or Net Profit |
| **Sync Engine** | CDC delta sync, Last-Write-Wins conflict resolution, 48h offline |
| **Smart Analytics** | TimescaleDB-powered stock forecasting |

---

## ⚡ Quick Start

### Prerequisites
- Flutter 3.x (stable channel)
- Go 1.22+
- Docker & Docker Compose
- Tailscale account (for remote access)

### 1. Home Server Setup
```bash
cd infra/
cp ../backend/.env.example .env
docker compose up -d
```

### 2. Flutter App
```bash
cd apps/unnati_pos/
flutter pub get
flutter run -d windows
```

### 3. Go Backend (Development)
```bash
cd backend/
cp .env.example .env
go run cmd/server/main.go
```

---

## 🔒 Security & Privacy

- All business data is stored **on your own device and home server**
- No data is sent to any third-party cloud service
- JWT tokens with role-based access (Owner vs Cashier)
- Secure remote access via **Tailscale** mesh VPN
- Cashier role: **Cost Price and Net Profit are permanently hidden**

---

## 📜 VAT/PAN Compliance

- 13% VAT calculation on all taxable items
- PAN number printed on every invoice
- Annexure 10 report generation ready
- Fonepay QR payment reconciliation

---

## 📄 License & Copyright

Copyright © 2026 **Walsong Group**. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or use of this software, via any medium, is strictly prohibited.

**Unnati** is a registered trademark of Walsong Group.

Founded by **Sangam Baral**.

---

*Built with ❤️ for Nepal's hardworking shopkeepers.*
