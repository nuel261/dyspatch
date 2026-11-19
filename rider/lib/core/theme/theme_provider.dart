import 'package:dyspatch_rider/core/theme/dark_mode.dart';
import 'package:dyspatch_rider/core/theme/light_mode.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark choice, saved on the device. [load] runs in main() before
/// runApp, so the very first frame already uses the saved theme.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'rider_theme_dark';

  ThemeProvider({bool dark = false}) : _themeData = dark ? darkmode : lightmode;

  /// Reads the saved choice (fast: SharedPreferences is a local file).
  static Future<ThemeProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeProvider(dark: prefs.getBool(_key) ?? false);
    } catch (_) {
      return ThemeProvider();
    }
  }

  ThemeData _themeData;

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == darkmode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
    _save(themeData == darkmode);
  }

  void toggleTheme() => themeData = isDarkMode ? lightmode : darkmode;

  Future<void> _save(bool dark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {}
  }
}
