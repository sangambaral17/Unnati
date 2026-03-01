// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

// Package api implements the HTTP sync endpoint for the CDC pattern.
// The sync handler receives delta batches from Flutter clients and applies
// them to PostgreSQL using Last-Write-Wins conflict resolution.
package api

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	"go.uber.org/zap"

	"github.com/walsong/unnati-backend/internal/domain"
	"github.com/walsong/unnati-backend/internal/middleware"
	"github.com/walsong/unnati-backend/internal/queue"
)

// RegisterSyncRoutes mounts the sync endpoints.
func RegisterSyncRoutes(rg *gin.RouterGroup, db *sqlx.DB, q *queue.RedisSyncQueue, log *zap.Logger) {
	h := &syncHandler{db: db, queue: q, log: log}
	rg.POST("/sync/push", h.Push)
	rg.GET("/sync/status/:device_id", h.GetStatus)
	rg.GET("/health/sync/:device_id", h.GetSyncHealth)
	rg.POST("/sync/register-device", h.RegisterDevice)
}

type syncHandler struct {
	db    *sqlx.DB
	queue *queue.RedisSyncQueue
	log   *zap.Logger
}

// Push handles POST /api/v1/sync/push
// Receives a batch of CDC delta items from a Flutter device and applies them.
// Conflict Resolution: Last-Write-Wins based on updated_at timestamp.
func (h *syncHandler) Push(c *gin.Context) {
	claims, ok := middleware.GetClaims(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req domain.SyncPushRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid body: " + err.Error()})
		return
	}

	if len(req.Items) == 0 {
		c.JSON(http.StatusOK, domain.SyncPushResponse{})
		return
	}

	if len(req.Items) > 500 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "batch too large: max 500 items"})
		return
	}

	h.log.Info("Sync push received",
		zap.String("device_id", req.DeviceID),
		zap.String("staff_id", claims.StaffID),
		zap.Int("item_count", len(req.Items)),
	)

	resp := domain.SyncPushResponse{
		Accepted:  make([]string, 0),
		Conflicts: make([]domain.ConflictResult, 0),
		Errors:    make([]domain.SyncError, 0),
	}

	// Update device's last sync time
	go h.updateDeviceLastSync(req.DeviceID)

	// Process each delta item
	for _, item := range req.Items {
		result, err := h.applyDelta(c.Request.Context(), item)
		if err != nil {
			h.log.Warn("Sync item failed",
				zap.String("item_id", item.ID),
				zap.String("table", item.TableName),
				zap.Error(err),
			)
			resp.Errors = append(resp.Errors, domain.SyncError{
				ItemID:  item.ID,
				Message: err.Error(),
			})
			continue
		}

		if result != nil {
			resp.Conflicts = append(resp.Conflicts, *result)
		} else {
			resp.Accepted = append(resp.Accepted, item.ID)
		}
	}

	c.JSON(http.StatusOK, resp)
}

// applyDelta applies a single CDC item to PostgreSQL with LWW conflict resolution.
// Returns a ConflictResult if the server version wins, nil if client version was applied.
func (h *syncHandler) applyDelta(ctx interface{ Value(key any) any }, item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	switch item.TableName {
	case "products":
		return h.applyProductDelta(item)
	case "sales":
		return h.applySaleDelta(item)
	case "sale_items":
		return h.applySaleItemDelta(item)
	case "customers":
		return h.applyCustomerDelta(item)
	case "suppliers":
		return h.applySupplierDelta(item)
	case "purchase_orders":
		return h.applyPurchaseOrderDelta(item)
	case "ledger_entries":
		return h.applyLedgerDelta(item)
	default:
		h.log.Warn("Unknown table in sync delta", zap.String("table", item.TableName))
		return nil, nil // Skip unknown tables gracefully
	}
}

func (h *syncHandler) applyProductDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.Product
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	// Check current server version for LWW
	var serverUpdatedAt time.Time
	err := h.db.QueryRow(
		`SELECT updated_at FROM products WHERE id = $1`, incoming.ID,
	).Scan(&serverUpdatedAt)

	if err == nil {
		// Record exists — apply LWW
		if serverUpdatedAt.After(incoming.UpdatedAt) {
			// Server version is newer — client loses
			var serverRecord domain.Product
			if scanErr := h.db.Get(&serverRecord, `SELECT * FROM products WHERE id = $1`, incoming.ID); scanErr == nil {
				serverJSON, _ := json.Marshal(serverRecord)
				return &domain.ConflictResult{
					ItemID:       item.ID,
					RecordID:     incoming.ID,
					TableName:    "products",
					Winner:       "server",
					ServerRecord: serverJSON,
				}, nil
			}
		}
	}

	// Apply client version (upsert)
	_, err = h.db.Exec(`
		INSERT INTO products (id, sku, barcode, name, description, category_id,
			buying_unit_id, selling_unit_id, stock_qty, cost_price, selling_price,
			wholesale_price, is_vat_applicable, reorder_level, is_active, device_id,
			updated_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			stock_qty = EXCLUDED.stock_qty,
			cost_price = EXCLUDED.cost_price,
			selling_price = EXCLUDED.selling_price,
			is_active = EXCLUDED.is_active,
			device_id = EXCLUDED.device_id,
			updated_at = EXCLUDED.updated_at
		WHERE products.updated_at <= EXCLUDED.updated_at`,
		incoming.ID, incoming.SKU, incoming.Barcode, incoming.Name, incoming.Description,
		incoming.CategoryID, incoming.BuyingUnitID, incoming.SellingUnitID, incoming.StockQty,
		incoming.CostPrice, incoming.SellingPrice, incoming.WholesalePrice,
		incoming.IsVATApplicable, incoming.ReorderLevel, incoming.IsActive, incoming.DeviceID,
		incoming.UpdatedAt, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applySaleDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.Sale
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	// Idempotency Check: If the same sale_id is pushed twice due to a network retry,
	// the server must ignore the second one but return a 200 OK.
	var existingUpdatedAt time.Time
	err := h.db.QueryRow(`SELECT updated_at FROM sales WHERE id = $1`, incoming.ID).Scan(&existingUpdatedAt)
	if err == nil && existingUpdatedAt.Equal(incoming.UpdatedAt) {
		h.log.Info("Idempotent retry detected for sale (ignored safely)", zap.String("sale_id", incoming.ID))
		return nil, nil // Return 200 OK without double-processing
	}

	// Sales are mostly append-only (completed bills don't change)
	// Only allow updates for: held→completed, draft→cancelled
	_, err := h.db.Exec(`
		INSERT INTO sales (id, bill_number, staff_id, customer_id, status, payment_method,
			sub_total, discount_amt, taxable_amount, vat_amount, grand_total,
			paid_amount, change_amount, net_profit, customer_pan, fiscal_year, notes,
			fonepay_qr_ref, device_id, sold_at, updated_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22)
		ON CONFLICT (id, sold_at) DO UPDATE SET
			status = EXCLUDED.status,
			paid_amount = EXCLUDED.paid_amount,
			payment_method = EXCLUDED.payment_method,
			updated_at = EXCLUDED.updated_at
		WHERE sales.updated_at <= EXCLUDED.updated_at`,
		incoming.ID, incoming.BillNumber, incoming.StaffID, incoming.CustomerID,
		incoming.Status, incoming.PaymentMethod, incoming.SubTotal, incoming.DiscountAmt,
		incoming.TaxableAmount, incoming.VATAmount, incoming.GrandTotal, incoming.PaidAmount,
		incoming.ChangeAmount, incoming.NetProfit, incoming.CustomerPAN, incoming.FiscalYear,
		incoming.Notes, incoming.FonepayQRRef, incoming.DeviceID, incoming.SoldAt,
		incoming.UpdatedAt, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applySaleItemDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.SaleItem
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	_, err := h.db.Exec(`
		INSERT INTO sale_items (id, sale_id, product_id, product_name, qty, unit_id,
			unit_price, discount_pct, is_vat_applicable, line_total, cost_price, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		ON CONFLICT (id) DO NOTHING`,
		incoming.ID, incoming.SaleID, incoming.ProductID, incoming.ProductName,
		incoming.Qty, incoming.UnitID, incoming.UnitPrice, incoming.DiscountPct,
		incoming.IsVATApplicable, incoming.LineTotal, incoming.CostPrice, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applyCustomerDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.Customer
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	_, err := h.db.Exec(`
		INSERT INTO customers (id, name, phone, pan, address, credit_limit, current_debt, is_active, device_id, updated_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			phone = EXCLUDED.phone,
			credit_limit = EXCLUDED.credit_limit,
			is_active = EXCLUDED.is_active,
			device_id = EXCLUDED.device_id,
			updated_at = EXCLUDED.updated_at
		WHERE customers.updated_at <= EXCLUDED.updated_at`,
		incoming.ID, incoming.Name, incoming.Phone, incoming.PAN, incoming.Address,
		incoming.CreditLimit, incoming.CurrentDebt, incoming.IsActive, incoming.DeviceID,
		incoming.UpdatedAt, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applySupplierDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.Supplier
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	_, err := h.db.Exec(`
		INSERT INTO suppliers (id, name, phone, pan, contact_person, address, current_payable, is_active, device_id, updated_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			phone = EXCLUDED.phone,
			pan = EXCLUDED.pan,
			contact_person = EXCLUDED.contact_person,
			address = EXCLUDED.address,
			is_active = EXCLUDED.is_active,
			device_id = EXCLUDED.device_id,
			updated_at = EXCLUDED.updated_at
		WHERE suppliers.updated_at <= EXCLUDED.updated_at`,
		incoming.ID, incoming.Name, incoming.Phone, incoming.PAN, incoming.ContactPerson,
		incoming.Address, incoming.CurrentPayable, incoming.IsActive, incoming.DeviceID,
		incoming.UpdatedAt, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applyPurchaseOrderDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.PurchaseOrder
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	_, err := h.db.Exec(`
		INSERT INTO purchase_orders (id, po_number, supplier_id, staff_id, status, payment_method, total_amount, paid_amount, device_id, received_at, updated_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		ON CONFLICT (id) DO UPDATE SET
			status = EXCLUDED.status,
			paid_amount = EXCLUDED.paid_amount,
			payment_method = EXCLUDED.payment_method,
			updated_at = EXCLUDED.updated_at
		WHERE purchase_orders.updated_at <= EXCLUDED.updated_at`,
		incoming.ID, incoming.PONumber, incoming.SupplierID, incoming.StaffID,
		incoming.Status, incoming.PaymentMethod, incoming.TotalAmount, incoming.PaidAmount,
		incoming.DeviceID, incoming.ReceivedAt, incoming.UpdatedAt, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) applyLedgerDelta(item domain.SyncQueueItem) (*domain.ConflictResult, error) {
	var incoming domain.LedgerEntry
	if err := json.Unmarshal(item.Payload, &incoming); err != nil {
		return nil, err
	}

	// Ledger entries are immutable — insert only, never update
	_, err := h.db.Exec(`
		INSERT INTO ledger_entries (id, customer_id, sale_id, type, amount, running_balance,
			description, staff_id, payment_method, fonepay_txn_id, due_date, is_overdue,
			device_id, entry_date, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
		ON CONFLICT (id) DO NOTHING`,
		incoming.ID, incoming.CustomerID, incoming.SaleID, incoming.Type, incoming.Amount,
		incoming.RunningBalance, incoming.Description, incoming.StaffID, incoming.PaymentMethod,
		incoming.FonepayTxnID, incoming.DueDate, incoming.IsOverdue, incoming.DeviceID,
		incoming.EntryDate, incoming.CreatedAt,
	)

	return nil, err
}

func (h *syncHandler) updateDeviceLastSync(deviceID string) {
	h.db.Exec(
		`UPDATE device_registry SET last_sync_at = NOW() WHERE device_id = $1`,
		deviceID,
	)
}

// GetStatus handles GET /api/v1/sync/status/:device_id
func (h *syncHandler) GetStatus(c *gin.Context) {
	deviceID := c.Param("device_id")
	var device domain.DeviceRegistry
	if err := h.db.Get(&device, `SELECT * FROM device_registry WHERE device_id = $1`, deviceID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "device not registered"})
		return
	}
	c.JSON(http.StatusOK, device)
}

// RegisterDevice handles POST /api/v1/sync/register-device
func (h *syncHandler) RegisterDevice(c *gin.Context) {
	claims, ok := middleware.GetClaims(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var device domain.DeviceRegistry
	if err := c.ShouldBindJSON(&device); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	device.StaffID = claims.StaffID
	_, err := h.db.Exec(`
		INSERT INTO device_registry (device_id, device_name, staff_id, platform, registered_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (device_id) DO UPDATE SET
			device_name = EXCLUDED.device_name,
			staff_id = EXCLUDED.staff_id,
			is_active = TRUE`,
		device.DeviceID, device.DeviceName, device.StaffID, device.Platform,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "registration failed"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "device registered", "device_id": device.DeviceID})
}

// GetSyncHealth handles GET /api/v1/health/sync/:device_id
// Returns the last synced timestamp for a specific device.
func (h *syncHandler) GetSyncHealth(c *gin.Context) {
	deviceID := c.Param("device_id")
	var lastSync time.Time
	err := h.db.QueryRow(\`SELECT COALESCE(last_sync_at, '1970-01-01'::timestamptz) FROM device_registry WHERE device_id = $1\`, deviceID).Scan(&lastSync)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "device not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"device_id": deviceID, "last_sync_at": lastSync})
}

// RegisterProductRoutes, RegisterSaleRoutes, RegisterLedgerRoutes, RegisterStaffRoutes, RegisterAuthRoutes 
// are defined in their respective handler files (product_handler.go, sale_handler.go, etc.)
// Stub implementations below to satisfy compilation:

func RegisterProductRoutes(rg *gin.RouterGroup, db *sqlx.DB, log *zap.Logger)            {}
func RegisterSaleRoutes(rg *gin.RouterGroup, db *sqlx.DB, log *zap.Logger)               {}
func RegisterLedgerRoutes(rg *gin.RouterGroup, db *sqlx.DB, log *zap.Logger)             {}
func RegisterStaffRoutes(rg *gin.RouterGroup, db *sqlx.DB, log *zap.Logger, secret string) {}
func RegisterAuthRoutes(rg *gin.RouterGroup, db *sqlx.DB, log *zap.Logger, secret string)  {}
