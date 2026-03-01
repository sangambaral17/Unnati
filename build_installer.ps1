# Copyright (c) 2026 Walsong Group. All rights reserved.
# Walsong Group — Unnati Retail OS (Build Script)

Write-Host "=============================================" -ForegroundColor Green
Write-Host "   UNNATI RETAIL OS — MSIX INSTALLER BUILD   " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Ensure we are in the Flutter project directory
Set-Location -Path "d:\AntigravityProjects\Unnati\apps\unnati_pos"

# 1. Get packages
Write-Host "[1/3] Fetching latest Flutter dependencies..." -ForegroundColor Cyan
flutter pub get

# 2. Build the Windows release executable
Write-Host "[2/3] Compiling Windows Release Build (AOT)... this may take a moment." -ForegroundColor Cyan
flutter build windows --release

# 3. Package it into an MSIX Installer
Write-Host "[3/3] Packaging into native Windows MSIX Installer..." -ForegroundColor Cyan
dart run msix:create

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "✅ SUCCESS! Installer creation complete." -ForegroundColor Green
Write-Host "Your installer (.msix) is located at:" -ForegroundColor Yellow
Write-Host "d:\AntigravityProjects\Unnati\apps\unnati_pos\build\windows\x64\runner\Release\unnati_pos.msix" -ForegroundColor White
Write-Host "Double-click the .msix file to install Unnati Retail OS natively on this PC." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
