import 'package:flutter/material.dart';

/// Manages the app's theme mode (light / dark / system) and notifies listeners.
///
/// Persists the user's preference to [SharedPreferences] is not used to avoid
/// adding a dependency — instead uses a simple in-memory default that follows
/// the system. Users can toggle between light/dark from the Settings screen.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Set a specific theme mode and notify listeners.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Convenience toggle between light and dark.
  /// If currently system, resolves to the opposite of the actual brightness.
  void toggleTheme(BuildContext context) {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      // System mode → toggle to the opposite of current actual brightness.
      final brightness = MediaQuery.platformBrightnessOf(context);
      setThemeMode(
        brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );
    }
  }
}
