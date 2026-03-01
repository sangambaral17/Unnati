// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

package domain

import (
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

// ─────────────────────────────────────────────────────────────────────────────
// Customer
// ─────────────────────────────────────────────────────────────────────────────

// Customer represents a registered credit customer (Udhari system).
type Customer struct {
	ID           string    `db:"id"           json:"id"`
	Name         string    `db:"name"         json:"name"`
	Phone        *string   `db:"phone"        json:"phone,omitempty"`
	PAN          *string   `db:"pan"          json:"pan,omitempty"` // PAN for B2B invoices
	Address      *string   `db:"address"      json:"address,omitempty"`
	CreditLimit  decimal.Decimal `db:"credit_limit" json:"credit_limit"`
	CurrentDebt  decimal.Decimal `db:"current_debt" json:"current_debt"` // Running balance
	IsActive     bool      `db:"is_active"    json:"is_active"`
	UpdatedAt    time.Time `db:"updated_at"   json:"updated_at"`
	CreatedAt    time.Time `db:"created_at"   json:"created_at"`
	DeviceID     *string   `db:"device_id"    json:"device_id,omitempty"`
}

func NewCustomer(name string) *Customer {
	now := time.Now().UTC()
	return &Customer{
		ID:          uuid.NewString(),
		Name:        name,
		IsActive:    true,
		CreditLimit: decimal.NewFromInt(10000),
		CurrentDebt: decimal.Zero,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Ledger Entry (Udhari / Credit Aging)
// ─────────────────────────────────────────────────────────────────────────────

// LedgerType distinguishes between debit (customer owes) and credit (payment received).
type LedgerType string

const (
	LedgerDebit  LedgerType = "debit"  // Customer has taken goods on credit
	LedgerCredit LedgerType = "credit" // Customer made a payment
)

// LedgerEntry is an immutable record in the double-entry Udhari ledger.
type LedgerEntry struct {
	ID             string          `db:"id"              json:"id"`
	CustomerID     string          `db:"customer_id"     json:"customer_id"`
	SaleID         *string         `db:"sale_id"         json:"sale_id,omitempty"`     // Linked bill
	Type           LedgerType      `db:"type"            json:"type"`
	Amount         decimal.Decimal `db:"amount"          json:"amount"`
	RunningBalance decimal.Decimal `db:"running_balance" json:"running_balance"` // Balance after this entry
	Description    string          `db:"description"     json:"description"`
	StaffID        string          `db:"staff_id"        json:"staff_id"`

	// Payment specific fields
	PaymentMethod  *PaymentMethod  `db:"payment_method"  json:"payment_method,omitempty"`
	FonepayTxnID   *string         `db:"fonepay_txn_id"  json:"fonepay_txn_id,omitempty"` // For QR reconciliation

	// Credit Aging
	DueDate        *time.Time      `db:"due_date"        json:"due_date,omitempty"`
	IsOverdue      bool            `db:"is_overdue"      json:"is_overdue"`

	// CDC
	EntryDate  time.Time `db:"entry_date"  json:"entry_date"`
	CreatedAt  time.Time `db:"created_at"  json:"created_at"`
	DeviceID   string    `db:"device_id"   json:"device_id"`
}

// NewDebitEntry creates a ledger debit (credit sale to customer).
func NewDebitEntry(customerID, saleID, staffID, deviceID string, amount decimal.Decimal, runningBalance decimal.Decimal) *LedgerEntry {
	now := time.Now().UTC()
	due := now.Add(30 * 24 * time.Hour) // 30 days default credit period
	return &LedgerEntry{
		ID:             uuid.NewString(),
		CustomerID:     customerID,
		SaleID:         &saleID,
		Type:           LedgerDebit,
		Amount:         amount,
		RunningBalance: runningBalance,
		Description:    "Credit sale",
		StaffID:        staffID,
		DueDate:        &due,
		IsOverdue:      false,
		EntryDate:      now,
		CreatedAt:      now,
		DeviceID:       deviceID,
	}
}

// NewCreditEntry creates a ledger credit (payment from customer).
func NewCreditEntry(customerID, staffID, deviceID string, amount, runningBalance decimal.Decimal,
	method PaymentMethod, fonepayTxnID *string) *LedgerEntry {
	now := time.Now().UTC()
	return &LedgerEntry{
		ID:             uuid.NewString(),
		CustomerID:     customerID,
		Type:           LedgerCredit,
		Amount:         amount,
		RunningBalance: runningBalance,
		Description:    "Payment received",
		StaffID:        staffID,
		PaymentMethod:  &method,
		FonepayTxnID:   fonepayTxnID,
		EntryDate:      now,
		CreatedAt:      now,
		DeviceID:       deviceID,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Credit Aging Report
// ─────────────────────────────────────────────────────────────────────────────

// AgingBucket classifies how long a debt has been outstanding.
type AgingBucket struct {
	CustomerID   string          `json:"customer_id"`
	CustomerName string          `json:"customer_name"`
	Current      decimal.Decimal `json:"current"`       // 0-30 days
	Days31to60   decimal.Decimal `json:"days_31_60"`    // 31-60 days
	Days61to90   decimal.Decimal `json:"days_61_90"`    // 61-90 days
	Over90Days   decimal.Decimal `json:"over_90_days"`  // >90 days — critical
	Total        decimal.Decimal `json:"total"`
}
