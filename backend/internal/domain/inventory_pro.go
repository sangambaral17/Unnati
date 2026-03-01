// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

package domain

import (
	"time"
)

// Supplier represents a B2B vendor.
type Supplier struct {
	ID             string    `db:"id"               json:"id"`
	Name           string    `db:"name"             json:"name"`
	Phone          *string   `db:"phone"            json:"phone,omitempty"`
	PAN            *string   `db:"pan"              json:"pan,omitempty"`
	ContactPerson  *string   `db:"contact_person"   json:"contact_person,omitempty"`
	Address        *string   `db:"address"          json:"address,omitempty"`
	CurrentPayable float64   `db:"current_payable"  json:"current_payable"`
	IsActive       bool      `db:"is_active"        json:"is_active"`
	DeviceID       *string   `db:"device_id"        json:"device_id,omitempty"`
	UpdatedAt      time.Time `db:"updated_at"       json:"updated_at"`
	CreatedAt      time.Time `db:"created_at"       json:"created_at"`
}

// PurchaseOrder represents an inward stock delivery.
type PurchaseOrder struct {
	ID            string    `db:"id"               json:"id"`
	PONumber      string    `db:"po_number"        json:"po_number"`
	SupplierID    string    `db:"supplier_id"      json:"supplier_id"`
	StaffID       string    `db:"staff_id"         json:"staff_id"`
	Status        string    `db:"status"           json:"status"` // draft, completed, cancelled
	PaymentMethod string    `db:"payment_method"   json:"payment_method"` // cash, credit, bank
	TotalAmount   float64   `db:"total_amount"     json:"total_amount"`
	PaidAmount    float64   `db:"paid_amount"      json:"paid_amount"`
	DeviceID      string    `db:"device_id"        json:"device_id"`
	ReceivedAt    time.Time `db:"received_at"      json:"received_at"`
	UpdatedAt     time.Time `db:"updated_at"       json:"updated_at"`
	CreatedAt     time.Time `db:"created_at"       json:"created_at"`
}
