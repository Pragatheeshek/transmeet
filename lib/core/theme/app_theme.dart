import 'package:flutter/material.dart';

/// Professional Material 3 themes for TransMeet.
///
/// Provides both light and dark themes using the user-specified colour palette:
///
/// ☀️ Light Mode
///   Background: #FFFFFF  |  Primary: #2563EB  |  Text: #0F172A
///
/// 🌙 Dark Mode
///   Background: #0F172A  |  Primary: #3B82F6  |  Text: #F8FAFC
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Shared palette
  // ---------------------------------------------------------------------------
  static const Color _error = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // ☀️ Light Mode colours
  // ---------------------------------------------------------------------------
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightPrimary = Color(0xFF2563EB);
  static const Color _lightText = Color(0xFF0F172A);
  static const Color _lightSubtext = Color(0xFF64748B);
  static const Color _lightSurface = Color(0xFFF8FAFC);
  static const Color _lightSurfaceContainer = Color(0xFFF1F5F9);
  static const Color _lightCard = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // 🌙 Dark Mode colours
  // ---------------------------------------------------------------------------
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkPrimary = Color(0xFF3B82F6);
  static const Color _darkText = Color(0xFFF8FAFC);
  static const Color _darkSubtext = Color(0xFF94A3B8);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _darkSurfaceContainer = Color(0xFF1E293B);
  static const Color _darkCard = Color(0xFF1E293B);

  // ---------------------------------------------------------------------------
  // ☀️ Light Theme
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        onPrimary: Colors.white,
        secondary: Color(0xFF1D4ED8),
        onSecondary: Colors.white,
        surface: _lightSurface,
        onSurface: _lightText,
        onSurfaceVariant: _lightSubtext,
        surfaceContainerHighest: _lightSurfaceContainer,
        error: _error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: _lightBg,
      cardColor: _lightCard,

      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: _lightText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _lightText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _lightPrimary.withValues(alpha: 0.4),
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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightText,
          side: BorderSide(color: _lightSubtext.withValues(alpha: 0.3)),
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

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceContainer,
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
            color: _lightSubtext.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _lightSubtext, fontSize: 14),
        labelStyle: const TextStyle(color: _lightSubtext, fontSize: 14),
        prefixIconColor: _lightSubtext,
        suffixIconColor: _lightSubtext,
        errorStyle: const TextStyle(color: _error, fontSize: 12),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _lightText,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _lightText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _lightText,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: _lightText),
        bodyMedium: TextStyle(fontSize: 14, color: _lightText),
        bodySmall: TextStyle(fontSize: 12, color: _lightSubtext),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _lightText,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightText,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: DividerThemeData(
        color: _lightSubtext.withValues(alpha: 0.15),
        thickness: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightBg,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: _lightSubtext,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌙 Dark Theme
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: Colors.white,
        secondary: Color(0xFF2563EB),
        onSecondary: Colors.white,
        surface: _darkSurface,
        onSurface: _darkText,
        onSurfaceVariant: _darkSubtext,
        surfaceContainerHighest: _darkSurfaceContainer,
        error: _error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: _darkBg,
      cardColor: _darkCard,

      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _darkPrimary.withValues(alpha: 0.4),
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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkText,
          side: BorderSide(color: _darkSubtext.withValues(alpha: 0.3)),
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

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceContainer,
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
            color: _darkSubtext.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _darkSubtext, fontSize: 14),
        labelStyle: const TextStyle(color: _darkSubtext, fontSize: 14),
        prefixIconColor: _darkSubtext,
        suffixIconColor: _darkSubtext,
        errorStyle: const TextStyle(color: _error, fontSize: 12),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _darkText,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: _darkText),
        bodyMedium: TextStyle(fontSize: 14, color: _darkText),
        bodySmall: TextStyle(fontSize: 12, color: _darkSubtext),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _darkText,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: const TextStyle(color: _darkText, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: DividerThemeData(
        color: _darkSubtext.withValues(alpha: 0.2),
        thickness: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkBg,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: _darkSubtext,
      ),
    );
  }
}
