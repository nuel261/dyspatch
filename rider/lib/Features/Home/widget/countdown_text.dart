import 'dart:async';

import 'package:flutter/material.dart';

// Self-contained countdown widget. Runs its own Timer so only this
// small Text rebuilds every second — not the whole card list.
// [boxed] wraps it in the small outlined chip used on Activity details.
// [compact] shows just "09:50" in a filled grey chip (Issue details).
class CountdownText extends StatefulWidget {
  final DateTime expiresAt;
  final bool boxed;
  final bool compact;

  const CountdownText({
    super.key,
    required this.expiresAt,
    this.boxed = false,
    this.compact = false,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final diff = widget.expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final m = _remaining.inMinutes.toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE3E7EB),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$m:$s',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: expired ? const Color(0xFFD32F2F) : const Color(0xFF0E0F10),
            fontFamily: 'Montserrat',
          ),
        ),
      );
    }
    final text = Text(
      expired ? 'Expired' : '$m:$s mins left!',
      style: TextStyle(
        fontSize: widget.boxed ? 10 : 12,
        fontWeight: expired ? FontWeight.w600 : FontWeight.w400,
        color: expired ? const Color(0xFFD32F2F) : Colors.grey.shade500,
        fontFamily: 'Montserrat',
      ),
    );
    if (!widget.boxed) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E7EB)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: text,
    );
  }
}
