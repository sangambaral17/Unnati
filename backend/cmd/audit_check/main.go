// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"regexp"
	"sort"
	"strconv"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

// This script scans the PostgreSQL 'sales' table to ensure there are no
// missing or broken sequence numbers in the IRD-formatted bill numbers.
// Run via: go run backend/cmd/audit_check/main.go
func main() {
	if err := godotenv.Load(".env"); err != nil {
		log.Println("No .env file found; using environment variables.")
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:unnati_pass@localhost:5432/unnati?sslmode=disable"
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	rows, err := db.QueryContext(ctx, "SELECT bill_number FROM sales WHERE status != 'draft' ORDER BY sold_at ASC")
	if err != nil {
		log.Fatalf("Query failed: %v", err)
	}
	defer rows.Close()

	// IRD Format usually: UROS-2081-B1-00001
	// We extract the sequence (last part) per prefix
	seqMap := make(map[string][]int)

	re := regexp.MustCompile(`^(.*)-(\d+)$`)

	var totalChecked int
	for rows.Next() {
		var billNum string
		if err := rows.Scan(&billNum); err != nil {
			log.Printf("Row scan err: %v\n", err)
			continue
		}

		matches := re.FindStringSubmatch(billNum)
		if len(matches) == 3 {
			prefix := matches[1]
			seqStr := matches[2]
			seq, err := strconv.Atoi(seqStr)
			if err == nil {
				seqMap[prefix] = append(seqMap[prefix], seq)
				totalChecked++
			}
		}
	}

	fmt.Printf("\n--- UNNATI IRD DATA INTEGRITY SCAN ---\n")
	fmt.Printf("Total finalized invoices scanned: %d\n\n", totalChecked)

	brokenSequencesFound := 0

	for prefix, sequences := range seqMap {
		sort.Ints(sequences)

		if len(sequences) == 0 {
			continue
		}

		expected := sequences[0]
		for _, actual := range sequences {
			if actual != expected {
				fmt.Printf("[ALARM] Sequence Break in prefix '%s': Expected %d, but found %d\n", prefix, expected, actual)
				brokenSequencesFound++
				expected = actual // Reset to continue checking
			}
			expected++
		}
	}

	if brokenSequencesFound == 0 {
		fmt.Printf("✅ STATUS: PERFECT. Zero broken sequences found. IRD Compliance Intact.\n")
	} else {
		fmt.Printf("❌ STATUS: FAILED. Found %d broken sequence jumps. Immediate audit required.\n", brokenSequencesFound)
		os.Exit(1)
	}
}
