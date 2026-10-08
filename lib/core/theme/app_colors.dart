import 'package:flutter/material.dart';

/// Tukkito Customer App visual identity.
class AppColors {
  AppColors._();

  // ===========================================================
  // BRAND COLORS
  // ===========================================================

  /// Tukkito Red — CTAs, pin, search, See All, selected nav
  /// Zomato-style food-delivery red.
  static const Color primary = Color(0xFFE23744);

  /// Fresh Green — ratings, open/veg/status
  static const Color freshGreen = Color(0xFF16A34A);

  /// Deep navy/charcoal — headings, names, primary text
  static const Color charcoal = Color(0xFF172033);

  /// Primary Gradient
  static const Color primaryGradientStart = Color(0xFFF25563);
  static const Color primaryGradientEnd = Color(0xFFC92A38);

  /// Brand text (maps to navy/charcoal)
  static const Color secondary = charcoal;

  /// Heart Red
  static const Color accent = Color(0xFFE53935);

  // ===========================================================
  // BACKGROUND
  // ===========================================================

  /// Warm cream Home background
  static const Color background = Color(0xFFFFF7F0);
  static const Color surface = Color(0xFFFFFFFF);

  /// Very light red wash for selected navigation pill
  static const Color selectedNavFill = Color(0xFFFDE8EA);

  // ===========================================================
  // TEXT COLORS
  // ===========================================================

  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFFFFFFFF);

  // ===========================================================
  // BORDER
  // ===========================================================

  static const Color border = Color(0xFFF0E5DC);
  static const Color divider = Color(0xFFF3EAE3);

  // ===========================================================
  // STATUS COLORS
  // ===========================================================

  static const Color success = freshGreen;
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1976D2);

  // ===========================================================
  // ICON COLORS
  // ===========================================================

  static const Color iconPrimary = primary;
  static const Color iconSecondary = charcoal;
  static const Color iconLight = Colors.white;
  static const Color iconMuted = textSecondary;

  // ===========================================================
  // BUTTON COLORS
  // ===========================================================

  static const Color buttonPrimary = primary;
  static const Color buttonDisabled = Color(0xFFBDBDBD);

  // ===========================================================
  // SHADOW
  // ===========================================================

  static const Color shadow = Color(0x1A172033);
}
