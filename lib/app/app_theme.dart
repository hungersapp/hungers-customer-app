import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.poppins().fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.search),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.search),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.search),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 72,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.selectedNavFill,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.navIndicator),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primary : AppColors.iconMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
      ),
      dividerColor: AppColors.divider,
      iconTheme: const IconThemeData(
        color: AppColors.iconSecondary,
      ),
    );
  }
}
