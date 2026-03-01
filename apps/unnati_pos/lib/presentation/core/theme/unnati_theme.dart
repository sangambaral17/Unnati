// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Unnati Retail OS — Universal Design System
/// 
/// Core Palette:
/// - Prosperity Green: #2E7D32 (Trust, Money, Growth)
/// - Deep Charcoal: #263238 (Professionalism, High-glare contrast)
/// 
/// Typography:
/// - Inter: Clean, sans-serif, optimized for readability on POS screens.
class UnnatiTheme {
  // Brand Colors
  static const Color prosperityGreen = Color(0xFF2E7D32); // Primary
  static const Color prosperityGreenLight = Color(0xFF60AD5E);
  static const Color prosperityGreenDark = Color(0xFF005005);
  
  static const Color deepCharcoal = Color(0xFF263238); // Secondary / Backgrounds
  static const Color deepCharcoalLight = Color(0xFF4F5B62);
  static const Color deepCharcoalDark = Color(0xFF000A12);

  // Accent Colors
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color warningOrange = Color(0xFFF57C00);
  static const Color infoBlue = Color(0xFF1976D2);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F7FA);

  /// Generates the global ThemeData for the application.
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: prosperityGreen,
        primary: prosperityGreen,
        secondary: deepCharcoal,
        error: alertRed,
        background: backgroundLight,
        surface: surfaceWhite,
      ),
      scaffoldBackgroundColor: backgroundLight,
      
      // Typography
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: deepCharcoalDark),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: deepCharcoal),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: deepCharcoal),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: deepCharcoalLight),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: deepCharcoal,
        foregroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: surfaceWhite,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: deepCharcoal.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: prosperityGreen,
          foregroundColor: surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepCharcoal,
          side: const BorderSide(color: deepCharcoalLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: prosperityGreen, width: 2),
        ),
      ),
    );
  }
}
