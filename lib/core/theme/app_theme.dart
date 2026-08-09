import 'package:flutter/material.dart';

/// Professional Material 3 theme for TransMeet.
///
/// Uses a modern teal-cyan colour palette that conveys trust and
/// professionalism — fitting for a video-conferencing application.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Colour palette
  // ---------------------------------------------------------------------------

  static const Color _primaryColor = Color(0xFF00B4D8);
  static const Color _primaryDark = Color(0xFF0096C7);
  static const Color _surface = Color(0xFF121212);
  static const Color _surfaceContainer = Color(0xFF1E1E1E);
  static const Color _cardColor = Color(0xFF252525);
  static const Color _onSurface = Color(0xFFE0E0E0);
  static const Color _onSurfaceVariant = Color(0xFF9E9E9E);
  static const Color _error = Color(0xFFEF5350);

  // ---------------------------------------------------------------------------
  // Theme data
  // ---------------------------------------------------------------------------

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Colour scheme
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        onPrimary: Colors.white,
        secondary: _primaryDark,
        onSecondary: Colors.white,
        surface: _surface,
        onSurface: _onSurface,
        onSurfaceVariant: _onSurfaceVariant,
        surfaceContainerHighest: _surfaceContainer,
        error: _error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: _surface,
      cardColor: _cardColor,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryColor.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined buttons (social login)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          side: BorderSide(color: _onSurfaceVariant.withValues(alpha: 0.3)),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _onSurfaceVariant, fontSize: 14),
        labelStyle: const TextStyle(color: _onSurfaceVariant, fontSize: 14),
        prefixIconColor: _onSurfaceVariant,
        suffixIconColor: _onSurfaceVariant,
        errorStyle: const TextStyle(color: _error, fontSize: 12),
      ),

      // Text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: _onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: _onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: _onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardColor,
        contentTextStyle: const TextStyle(color: _onSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: _onSurfaceVariant.withValues(alpha: 0.2),
        thickness: 1,
      ),
    );
  }
}
