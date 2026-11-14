import 'package:flutter/material.dart';

ThemeData darkmode = ThemeData(
  fontFamily: 'Montserrat',
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF0E120F),
    secondary: Color(0xFF1A1A1A),
    tertiary: Color(0xFF2C2C2C),
    onPrimary: Color(0xFFE0E0E0),
    onSecondary: Color(0xFF34A853),
    surface: Color(0xFF0E120F),
    inversePrimary: Color(0xFFE0E0E0),
    tertiaryContainer: Color(0xFF2E3238),
    onPrimaryContainer: Color(0xFF23262B),
    onTertiaryContainer: Color(0xFFFFFFFF),
    onSecondaryContainer: Color(0xFF34A853),
    inverseSurface: Color(0xFF2E3238),
  ),
  // Every text box's cursor. Without this Flutter uses colorScheme.primary,
  // which matches the field background — an invisible cursor.
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Color(0xFFFFFFFF),
    selectionHandleColor: Color(0xFFFFFFFF),
    selectionColor: Color(0x4D34A853), // #34A853 at 30%
  ),
  // Snackbars: card-coloured, floating, rounded — the style used across
  // the app. Text colour is set here because the default onInverseSurface
  // is too faint on the card colour.
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Color(0xFF2E3238),
    contentTextStyle: TextStyle(
      fontFamily: 'Montserrat',
      color: Color(0xFFE0E0E0),
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
);
