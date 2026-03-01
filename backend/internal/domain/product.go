// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

// Package domain contains the core business entities for Unnati Retail OS.
package domain

import (
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

// ─────────────────────────────────────────────────────────────────────────────
// Unit & Unit Conversion (Multi-Unit Inventory)
// ─────────────────────────────────────────────────────────────────────────────

// Unit represents a measurement unit (e.g., Roll, Meter, Piece, Box, Kg).
type Unit struct {
	ID        string    `db:"id"         json:"id"`
	Name      string    `db:"name"       json:"name"`       // e.g., "Roll", "Meter"
	ShortName string    `db:"short_name" json:"short_name"` // e.g., "Rl", "m"
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

// UnitConversion defines the ratio between two units for a specific product.
// Example: 1 Roll of wire = 50 Meters → FromUnitID=Roll, ToUnitID=Meter, Factor=50
type UnitConversion struct {
	ID           string          `db:"id"             json:"id"`
	ProductID    string          `db:"product_id"     json:"product_id"`
	FromUnitID   string          `db:"from_unit_id"   json:"from_unit_id"`
	ToUnitID     string          `db:"to_unit_id"     json:"to_unit_id"`
	Factor       decimal.Decimal `db:"factor"         json:"factor"` // FromUnit * Factor = ToUnit
	CreatedAt    time.Time       `db:"created_at"     json:"created_at"`
}

// ─────────────────────────────────────────────────────────────────────────────
// Product
// ─────────────────────────────────────────────────────────────────────────────

// ProductCategory represents a top-level category (Hardware, Electrical, Kirana).
type ProductCategory struct {
	ID        string    `db:"id"         json:"id"`
	Name      string    `db:"name"       json:"name"`
	ParentID  *string   `db:"parent_id"  json:"parent_id,omitempty"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

// Product is the core inventory entity.
// SECURITY NOTE: CostPrice must never be serialized to Cashier-role JWT responses.
type Product struct {
	ID             string          `db:"id"              json:"id"`
	SKU            string          `db:"sku"             json:"sku"`
	Barcode        *string         `db:"barcode"         json:"barcode,omitempty"`
	Name           string          `db:"name"            json:"name"`
	Description    *string         `db:"description"     json:"description,omitempty"`
	CategoryID     *string         `db:"category_id"     json:"category_id,omitempty"`
	BuyingUnitID   string          `db:"buying_unit_id"  json:"buying_unit_id"`  // Unit in which stock is purchased
	SellingUnitID  string          `db:"selling_unit_id" json:"selling_unit_id"` // Unit in which item is sold
	StockQty       decimal.Decimal `db:"stock_qty"       json:"stock_qty"`       // In selling unit

	// Cost Price — hidden from Cashier role in API responses
	CostPrice      decimal.Decimal `db:"cost_price"      json:"cost_price,omitempty"`
	SellingPrice   decimal.Decimal `db:"selling_price"   json:"selling_price"`
	WholesalePrice *decimal.Decimal `db:"wholesale_price" json:"wholesale_price,omitempty"`
	VATID          *string         `db:"vat_id"          json:"vat_id,omitempty"` // FK to VAT rate
	IsVATApplicable bool           `db:"is_vat_applicable" json:"is_vat_applicable"`
	ReorderLevel   decimal.Decimal `db:"reorder_level"   json:"reorder_level"`
	IsActive       bool            `db:"is_active"       json:"is_active"`

	// CDC fields
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	DeviceID  *string   `db:"device_id"  json:"device_id,omitempty"` // Last modified by
}

// NewProduct creates a product with generated UUID and timestamps.
func NewProduct(sku, name string) *Product {
	now := time.Now().UTC()
	return &Product{
		ID:        uuid.NewString(),
		SKU:       sku,
		Name:      name,
		IsActive:  true,
		CreatedAt: now,
		UpdatedAt: now,
	}
}

// StripCostPrice returns a copy safe to send to Cashier-role clients.
func (p *Product) StripCostPrice() *Product {
	clone := *p
	clone.CostPrice = decimal.Zero
	clone.WholesalePrice = nil
	return &clone
}
