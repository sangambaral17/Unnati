// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

package domain

// CbmsInvoicePayload represents the exact JSON structure mandated by the Nepal IRD
// for real-time synchronization under Electronic Billing Procedure 2074 (Annexure 5).
type CbmsInvoicePayload struct {
	SellerPan    string  `json:"seller_pan"`
	BuyerPan     string  `json:"buyer_pan"`
	BuyerName    string  `json:"buyer_name"`
	InvoiceNo    string  `json:"invoice_number"`
	InvoiceDate  string  `json:"invoice_date"` // YYYY.MM.DD format required
	TotalSales   float64 `json:"total_sales"`
	TaxableSales float64 `json:"taxable_sales"`
	Vat          float64 `json:"vat"`
	ExemptSales  float64 `json:"exempt_sales"`
	ExportSales  float64 `json:"export_sales"`
	IsRealtime   bool    `json:"is_realtime"`
	Datetime     string  `json:"datetime"` // ISO 8601
}

// CbmsReturnPayload represents the cancellation/return structure for Annexure 5.
type CbmsReturnPayload struct {
	SellerPan      string  `json:"seller_pan"`
	BuyerPan       string  `json:"buyer_pan"`
	BuyerName      string  `json:"buyer_name"`
	ReturnNo       string  `json:"credit_note_number"`
	ReturnDate     string  `json:"credit_note_date"`
	RefInvoiceNo   string  `json:"ref_invoice_number"`
	Reason         string  `json:"reason_for_return"`
	TotalReturn    float64 `json:"total_amount"`
	TaxableReturn  float64 `json:"taxable_amount"`
	VatReturn      float64 `json:"vat"`
	ExemptReturn   float64 `json:"exempt_amount"`
	Datetime       string  `json:"datetime"` // ISO 8601
}

// IRD API Documentation Reference:
// Base URI: https://cbms.ird.gov.np/api/bill
// Auth: Basic Auth (Username/Password provided by IRD per taxpayer)
