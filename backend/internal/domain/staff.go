// Copyright (c) 2026 Walsong Group. All rights reserved.
// Proprietary and confidential.

package domain

import (
	"time"

	"github.com/google/uuid"
)

// ─────────────────────────────────────────────────────────────────────────────
// Staff & RBAC
// ─────────────────────────────────────────────────────────────────────────────

// Role defines access level in Unnati.
// Owner: Full access including cost prices, net profit, reports.
// Cashier: Can create bills, view sales. Cannot see cost prices or profit.
type Role string

const (
	RoleOwner   Role = "owner"
	RoleCashier Role = "cashier"
	RoleManager Role = "manager" // Can view reports but not cost prices
)

// Permission bitmask constants for fine-grained control.
const (
	PermViewCostPrice  = "view_cost_price"
	PermViewNetProfit  = "view_net_profit"
	PermDeleteSale     = "delete_sale"
	PermManageStaff    = "manage_staff"
	PermViewReports    = "view_reports"
	PermManageProducts = "manage_products"
	PermGiveDiscount   = "give_discount"
)

// RolePermissions maps each role to its allowed permissions.
var RolePermissions = map[Role][]string{
	RoleOwner: {
		PermViewCostPrice,
		PermViewNetProfit,
		PermDeleteSale,
		PermManageStaff,
		PermViewReports,
		PermManageProducts,
		PermGiveDiscount,
	},
	RoleManager: {
		PermViewReports,
		PermManageProducts,
		PermGiveDiscount,
	},
	RoleCashier: {
		PermGiveDiscount,
	},
}

// HasPermission checks if a role has a specific permission.
func (r Role) HasPermission(perm string) bool {
	perms, ok := RolePermissions[r]
	if !ok {
		return false
	}
	for _, p := range perms {
		if p == perm {
			return true
		}
	}
	return false
}

// Staff represents an employee / system user.
type Staff struct {
	ID           string    `db:"id"            json:"id"`
	Name         string    `db:"name"          json:"name"`
	Phone        string    `db:"phone"         json:"phone"`
	PIN          string    `db:"pin"           json:"-"`         // Hashed 4-digit PIN
	Role         Role      `db:"role"          json:"role"`
	IsActive     bool      `db:"is_active"     json:"is_active"`
	LastLoginAt  *time.Time `db:"last_login_at" json:"last_login_at,omitempty"`
	UpdatedAt    time.Time `db:"updated_at"    json:"updated_at"`
	CreatedAt    time.Time `db:"created_at"    json:"created_at"`
}

func NewStaff(name, phone, hashedPIN string, role Role) *Staff {
	now := time.Now().UTC()
	return &Staff{
		ID:        uuid.NewString(),
		Name:      name,
		Phone:     phone,
		PIN:       hashedPIN,
		Role:      role,
		IsActive:  true,
		CreatedAt: now,
		UpdatedAt: now,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// JWT Claims
// ─────────────────────────────────────────────────────────────────────────────

// UnnatiClaims embeds staff identity and role into JWT tokens.
type UnnatiClaims struct {
	StaffID  string `json:"staff_id"`
	Name     string `json:"name"`
	Role     Role   `json:"role"`
	DeviceID string `json:"device_id"`
}
