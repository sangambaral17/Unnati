// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

package domain

import (
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

// ─────────────────────────────────────────────────────────────────────────────
// Hold Bill Status
// ─────────────────────────────────────────────────────────────────────────────

// SaleStatus represents the lifecycle state of a sale/bill.
type SaleStatus string

const (
	SaleStatusDraft     SaleStatus = "draft"      // Bill is being created
	SaleStatusHeld      SaleStatus = "held"        // Bill is on hold (customer stepped aside)
	SaleStatusCompleted SaleStatus = "completed"   // Bill is paid and closed
	SaleStatusCancelled SaleStatus = "cancelled"   // Bill was cancelled
	SaleStatusRefunded  SaleStatus = "refunded"    // Bill was refunded
)

// PaymentMethod represents the mode of payment.
type PaymentMethod string

const (
	PaymentCash     PaymentMethod = "cash"
	PaymentFonepay  PaymentMethod = "fonepay"    // Fonepay QR
	PaymentCredit   PaymentMethod = "credit"     // Udhari / credit
	PaymentTransfer PaymentMethod = "transfer"   // Bank transfer
)

// ─────────────────────────────────────────────────────────────────────────────
// Sale (Bill)
// ─────────────────────────────────────────────────────────────────────────────

// Sale represents a single transaction / bill.
// Supports Hold Bill: status="held" until customer returns.
type Sale struct {
	ID            string          `db:"id"              json:"id"`
	BillNumber    string          `db:"bill_number"     json:"bill_number"`   // e.g., "INV-2026-00001"
	StaffID       string          `db:"staff_id"        json:"staff_id"`
	CustomerID    *string         `db:"customer_id"     json:"customer_id,omitempty"`
	Status        SaleStatus      `db:"status"          json:"status"`
	PaymentMethod PaymentMethod   `db:"payment_method"  json:"payment_method"`

	// Amounts
	SubTotal      decimal.Decimal `db:"sub_total"       json:"sub_total"`
	DiscountAmt   decimal.Decimal `db:"discount_amt"    json:"discount_amt"`
	TaxableAmount decimal.Decimal `db:"taxable_amount"  json:"taxable_amount"`
	VATAmount     decimal.Decimal `db:"vat_amount"      json:"vat_amount"`    // 13% of taxable
	GrandTotal    decimal.Decimal `db:"grand_total"     json:"grand_total"`
	PaidAmount    decimal.Decimal `db:"paid_amount"     json:"paid_amount"`
	ChangeAmount  decimal.Decimal `db:"change_amount"   json:"change_amount"`

	// PAN / VAT compliance
	CustomerPAN   *string         `db:"customer_pan"    json:"customer_pan,omitempty"`
	FiscalYear    string          `db:"fiscal_year"     json:"fiscal_year"` // e.g., "2081/82"
	Notes         *string         `db:"notes"           json:"notes,omitempty"`

	// ESC/POS printing
	PrintedAt     *time.Time      `db:"printed_at"      json:"printed_at,omitempty"`
	PrintCount    int             `db:"print_count"     json:"print_count"`

	// Fonepay QR
	FonepayQRRef  *string         `db:"fonepay_qr_ref"  json:"fonepay_qr_ref,omitempty"`

	// Net Profit — hidden from Cashier role
	NetProfit     decimal.Decimal `db:"net_profit"      json:"net_profit,omitempty"`

	// CDC
	SoldAt    time.Time `db:"sold_at"    json:"sold_at"`    // TimescaleDB partition key
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	DeviceID  string    `db:"device_id"  json:"device_id"`

	// Populated by JOINs (not stored)
	Items []SaleItem `db:"-" json:"items,omitempty"`
}

// NewSale creates a draft sale.
func NewSale(staffID, deviceID, fiscalYear string) *Sale {
	now := time.Now().UTC()
	return &Sale{
		ID:         uuid.NewString(),
		StaffID:    staffID,
		Status:     SaleStatusDraft,
		FiscalYear: fiscalYear,
		SoldAt:     now,
		CreatedAt:  now,
		UpdatedAt:  now,
		DeviceID:   deviceID,
		PrintCount: 0,
	}
}

// Hold places the bill on hold for the current customer.
func (s *Sale) Hold() {
	s.Status = SaleStatusHeld
	s.UpdatedAt = time.Now().UTC()
}

// Complete finalises the bill after payment.
func (s *Sale) Complete(paid decimal.Decimal, method PaymentMethod) {
	s.PaidAmount = paid
	s.PaymentMethod = method
	s.ChangeAmount = paid.Sub(s.GrandTotal)
	s.Status = SaleStatusCompleted
	s.UpdatedAt = time.Now().UTC()
}

// StripProfitMargin returns a safe copy for Cashier-role API responses.
func (s *Sale) StripProfitMargin() *Sale {
	clone := *s
	clone.NetProfit = decimal.Zero
	return &clone
}

// ─────────────────────────────────────────────────────────────────────────────
// Sale Item (Line Items)
// ─────────────────────────────────────────────────────────────────────────────

// SaleItem represents one line item in a Sale.
type SaleItem struct {
	ID             string          `db:"id"               json:"id"`
	SaleID         string          `db:"sale_id"          json:"sale_id"`
	ProductID      string          `db:"product_id"       json:"product_id"`
	ProductName    string          `db:"product_name"     json:"product_name"` // Denormalized for receipt
	Qty            decimal.Decimal `db:"qty"              json:"qty"`
	UnitID         string          `db:"unit_id"          json:"unit_id"`      // Unit sold in
	UnitPrice      decimal.Decimal `db:"unit_price"       json:"unit_price"`
	DiscountPct    decimal.Decimal `db:"discount_pct"     json:"discount_pct"`
	IsVATApplicable bool           `db:"is_vat_applicable" json:"is_vat_applicable"`
	LineTotal      decimal.Decimal `db:"line_total"       json:"line_total"`   // After discount, before VAT

	// Cost price — hidden from Cashier role
	CostPrice      decimal.Decimal `db:"cost_price"       json:"cost_price,omitempty"`

	CreatedAt      time.Time       `db:"created_at"       json:"created_at"`
}

// NewSaleItem creates a populated sale line item.
func NewSaleItem(saleID, productID, productName, unitID string,
	qty, unitPrice, discountPct, costPrice decimal.Decimal,
	isVAT bool) *SaleItem {

	discounted := unitPrice.Mul(decimal.NewFromInt(1).Sub(discountPct.Div(decimal.NewFromInt(100))))
	lineTotal := qty.Mul(discounted)

	return &SaleItem{
		ID:              uuid.NewString(),
		SaleID:          saleID,
		ProductID:       productID,
		ProductName:     productName,
		UnitID:          unitID,
		Qty:             qty,
		UnitPrice:       unitPrice,
		DiscountPct:     discountPct,
		IsVATApplicable: isVAT,
		LineTotal:       lineTotal,
		CostPrice:       costPrice,
		CreatedAt:       time.Now().UTC(),
	}
}
