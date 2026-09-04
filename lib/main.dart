import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:transmeet/core/theme/app_theme.dart';
import 'package:transmeet/core/theme/theme_provider.dart';
import 'package:transmeet/features/splash/splash_screen.dart';

import 'firebase_options.dart';

/// Global theme provider — accessible from anywhere via [TransMeetApp.themeProvider].
final ThemeProvider _themeProvider = ThemeProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TransMeetApp());
}

class TransMeetApp extends StatelessWidget {
  const TransMeetApp({super.key});

  /// Access the global theme provider from anywhere.
  static ThemeProvider get themeProvider => _themeProvider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'TransMeet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}