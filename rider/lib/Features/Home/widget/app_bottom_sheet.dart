import 'package:flutter/material.dart';

/// Shared shell for every bottom sheet / drawer in the app — matches
/// the phone number drawer's plain style (white bg, 16px top radius,
/// Montserrat text, no drag handle, no accent color on the chrome).
class AppBottomSheetStyle {
  static const Color background = Colors.white;
  static const Color titleColor = Color(0xFF1A1A1A);
  static const Color subtitleColor = Color(0xFF5F6368);

  static const double topRadius = 16;
  static const String fontFamily = "Montserrat";

  static const BorderRadius borderRadius = BorderRadius.vertical(
    top: Radius.circular(topRadius),
  );

  static const TextStyle titleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: titleColor,
  );

  static const TextStyle optionStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: titleColor,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: subtitleColor,
  );
}

/// Use this for every bottom sheet we build ourselves (photo picker,
/// action sheets, etc.) so they all share the same shell as the
/// phone drawer — bg color, radius, font. Only `child` changes.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppBottomSheetStyle.background,
    shape: const RoundedRectangleBorder(
      borderRadius: AppBottomSheetStyle.borderRadius,
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(title, style: AppBottomSheetStyle.titleStyle),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}
