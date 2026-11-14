import 'package:dyspatch_rider/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What the rider picked on the follow-up card.
enum FollowupAction { call, wait, report }

/// Overlay/Issue/followup — asked before an issue like "Recipient not
/// reachable" is reported, so the rider can retry first. Returns null if
/// the card is dismissed by tapping outside it.
Future<FollowupAction?> showIssueFollowup(
  BuildContext context, {
  required String title,
  String subtitle = 'Try calling again...',
}) {
  return showDialog<FollowupAction>(
    context: context,
    builder: (_) => _IssueFollowup(title: title, subtitle: subtitle),
  );
}

class _IssueFollowup extends StatelessWidget {
  final String title;
  final String subtitle;

  const _IssueFollowup({required this.title, required this.subtitle});

  static const _green = Color(0xFF34A853);
  static const _red = Color(0xFFD92D20);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    // Light: tinted buttons. Dark: solid green, muted red (per design).
    final cardBg = isDark ? const Color(0xFF16181A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0E0F10);
    final retryBg = isDark ? _green : const Color(0xFFEAF6ED);
    final retryText = isDark ? Colors.white : _green;
    final reportBg = isDark ? const Color(0xFFE8A5AC) : const Color(0xFFFDE8EA);

    return Dialog(
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 18 / 12,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            _button(
              context,
              'Call recipient',
              retryBg,
              retryText,
              FollowupAction.call,
            ),
            const SizedBox(height: 10),
            _button(
              context,
              'Wait 5 mins',
              retryBg,
              retryText,
              FollowupAction.wait,
            ),
            const SizedBox(height: 10),
            _button(
              context,
              'Report & Continue',
              reportBg,
              _red,
              FollowupAction.report,
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    Color bg,
    Color fg,
    FollowupAction action,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: () => Navigator.pop(context, action),
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
