import 'package:flutter/material.dart';

/// Shows a message in the app's floating snackbar style.
void showSnack(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? const Color(0xFFD93025) : const Color(0xFF34A853), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Turns an API error into a short, readable message.
String errorText(Object e) {
  final s = e.toString().replaceFirst(RegExp(r'^(Exception|ApiException)(\([^)]*\))?:\s*'), '');
  return s.isEmpty ? 'Something went wrong. Please try again.' : s;
}
