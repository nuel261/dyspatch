import 'package:flutter/material.dart';

ThemeData lightmode = ThemeData(
  fontFamily: 'Montserrat',
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFF5F5F5),
    tertiary: Color(0xFFEEF1F4),
    onPrimary: Color(0xFFE0E0E0),
    onSecondary: Color(0xFFE0E0E0),
    surface: Color(0xFF298341),
    inversePrimary: Color(0xFF0E0F10),
    tertiaryContainer: Color(0xFFEEF1F4),
    onPrimaryContainer: Color(0xFFE3E7EB),
    onTertiaryContainer: Color(0xFF0E0F10),
    onSecondaryContainer: Color(0xFF34A853),
    onInverseSurface: Color(0xFFD6DADE),
    inverseSurface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFF2D6A3E)
    
  ),
  // Every text box's cursor. Without this Flutter uses colorScheme.primary,
  // which matches the field background — an invisible cursor.
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Color(0xFF0E0F10),
    selectionHandleColor: Color(0xFF0E0F10),
    selectionColor: Color(0x4D34A853), // #34A853 at 30%
  ),
  // Snackbars: card-coloured, floating, rounded — the style used across
  // the app. Text colour is set here because the default onInverseSurface
  // is too faint on the card colour.
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    contentTextStyle: TextStyle(
      fontFamily: 'Montserrat',
      color: Color(0xFF0E0F10),
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
);
