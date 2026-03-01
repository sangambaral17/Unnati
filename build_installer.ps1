# Copyright (c) 2026 Walsong Group. All rights reserved.
# Walsong Group - Unnati Retail OS (Build Script)

Write-Host "=============================================" -ForegroundColor Green
Write-Host "   UNNATI RETAIL OS - MSIX INSTALLER BUILD   " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Ensure we are in the Flutter project directory
Set-Location -Path "d:\AntigravityProjects\Unnati\apps\unnati_pos"

# Check Prerequisites
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "❌ ERROR: 'flutter' command not found in your environment PATH." -ForegroundColor Red
    Write-Host "Please run this script from the 'Flutter Console' or add your Flutter SDK 'bin' folder to your Windows PATH." -ForegroundColor Yellow
    Write-Host "Example PATH: C:\src\flutter\bin" -ForegroundColor Cyan
    exit 1
}

if (!(Get-Command dart -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "❌ ERROR: 'dart' command not found in your environment PATH." -ForegroundColor Red
    Write-Host "Please ensure the Dart SDK is added to your Windows PATH." -ForegroundColor Yellow
    exit 1
}

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
Write-Host "SUCCESS! Installer creation complete." -ForegroundColor Green
Write-Host "Your installer (.msix) is located at:" -ForegroundColor Yellow
Write-Host "d:\AntigravityProjects\Unnati\apps\unnati_pos\build\windows\x64\runner\Release\unnati_pos.msix" -ForegroundColor White
Write-Host "Double-click the .msix file to install Unnati Retail OS natively on this PC." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
