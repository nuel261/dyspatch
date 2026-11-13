import 'package:flutter/material.dart';

/// Same palette as the customer app (core/theme/light_mode.dart / dark_mode.dart).
const Color brandGreen = Color(0xFF298341);
const Color brandGreenBright = Color(0xFF34A853);
const Color inkGrey = Color(0xFF5F6368);
const Color dangerRed = Color(0xFFD33426);
const Color warnAmber = Color(0xFFB88704);

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Montserrat',
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFF5F5F5),
    tertiary: Color(0xFFEEF1F4),
    onPrimary: Color(0xFFE0E0E0),
    onSecondary: Color(0xFFE0E0E0),
    // White (not brand green as in the customer app) so dialogs, menus, chips and
    // the map credit use readable surfaces; green is applied explicitly via brandGreen.
    surface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF0E0F10),
    tertiaryContainer: Color(0xFFEEF1F4),
    onPrimaryContainer: Color(0xFFE3E7EB),
    onTertiaryContainer: Color(0xFF0E0F10),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandGreen),
  dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Montserrat',
  scaffoldBackgroundColor: const Color(0xFF0B0E0C),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF0E120F),
    secondary: Color(0xFF1A1A1A),
    tertiary: Color(0xFF2C2C2C),
    onPrimary: Color(0xFFE0E0E0),
    onSecondary: Color(0xFF34A853),
    surface: Color(0xFF1A1D1B),
    inversePrimary: Color(0xFFE0E0E0),
    tertiaryContainer: Color(0xFF2E3238),
    onPrimaryContainer: Color(0xFF23262B),
    onTertiaryContainer: Color(0xFFFFFFFF),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandGreenBright),
  dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1D1B), surfaceTintColor: Colors.transparent),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);

class ThemeProvider extends ChangeNotifier {
  ThemeData _theme = lightMode;
  ThemeData get themeData => _theme;
  bool get isDarkMode => _theme == darkMode;
  void toggleTheme() {
    _theme = isDarkMode ? lightMode : darkMode;
    notifyListeners();
  }
}

extension ThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  /// Card / sheet background (white in light mode).
  Color get card => cs.primary;
  /// Main text colour.
  Color get ink => cs.inversePrimary;
  Color get line => cs.tertiary;
}
