import 'package:flutter/material.dart';

/// Design tokens and semantic color definitions for Lujayn.
///
/// Designed to evoke a calm, personal, and dependable atmosphere.
/// Avoids aggressive contrasts, harsh neon tones, or cold sterile dashboards.
class AppColors {
  AppColors._();

  // Primary brand palette (Slate Teal & Warm Amber)
  static const Color slateTeal = Color(0xFF233D4D);
  static const Color slateTealLight = Color(0xFF355264);
  static const Color slateTealDark = Color(0xFF162732);

  static const Color warmAmber = Color(0xFFD97043);
  static const Color warmAmberLight = Color(0xFFECA078);
  static const Color warmAmberSubtle = Color(0xFFFDF2EB);

  static const Color calmSage = Color(0xFF386641);
  static const Color calmSageSubtle = Color(0xFFEFF5F0);

  // Light Mode Surfaces
  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF3F4F6);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightDivider = Color(0xFFEEEEF0);

  // Light Mode Text
  static const Color lightTextPrimary = Color(0xFF181F26);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);

  // Dark Mode Surfaces
  static const Color darkBackground = Color(0xFF0F1318);
  static const Color darkSurface = Color(0xFF171C23);
  static const Color darkSurfaceSubtle = Color(0xFF202630);
  static const Color darkBorder = Color(0xFF2C3440);
  static const Color darkDivider = Color(0xFF222832);

  // Dark Mode Text
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

  // Semantic Status Colors
  static const Color statusActive = Color(0xFF2E7D32);
  static const Color statusActiveSubtle = Color(0xFFE8F5E9);
  static const Color statusCompleted = Color(0xFF6B7280);
  static const Color statusCompletedSubtle = Color(0xFFF3F4F6);
  static const Color statusWarning = Color(0xFFB45309);
  static const Color statusWarningSubtle = Color(0xFFFEF3C7);
  static const Color statusDanger = Color(0xFFDC2626);
}
