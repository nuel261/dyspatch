import 'package:flutter/material.dart';

/// "₦4,200" from kobo. Pass decimals=true for "₦4,200.00".
String naira(num? kobo, {bool decimals = false}) {
  final v = (kobo ?? 0) / 100;
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals ? 2 : 0);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${neg ? '-' : ''}₦$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Naira text the user typed ("2,500.50") → kobo int.
int toKobo(String input) {
  final s = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return 0;
  final parts = s.split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
  final frac = parts.length > 1 ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0 : 0;
  return whole * 100 + frac;
}

DateTime? parseTime(dynamic iso) => iso is String && iso.isNotEmpty ? DateTime.tryParse(iso)?.toLocal() : null;

String clock(DateTime? d) {
  if (d == null) return '--';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')}${d.hour >= 12 ? 'pm' : 'am'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today", "Yesterday" or "24 Jun".
String dayGroup(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${d.day} ${_months[d.month - 1]}${d.year != now.year ? ' ${d.year}' : ''}';
}

String dayTime(DateTime? d) => d == null ? '' : '${dayGroup(d)}, ${clock(d)}';

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 1) return 'Just now';
  if (s.inMinutes < 60) return '${s.inMinutes} min${s.inMinutes == 1 ? '' : 's'} ago';
  if (s.inHours < 24) return '${s.inHours} hr${s.inHours == 1 ? '' : 's'} ago';
  return dayGroup(d);
}

const Color brandGreen = Color(0xFF298341);

Color statusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFB88704);
    case 'matched':
      return const Color(0xFFE53935);
    case 'picked_up':
    case 'en_route':
      return const Color(0xFFF59E0B);
    case 'arrived':
    case 'delivered':
      return brandGreen;
    default:
      return const Color(0xFF5F6368);
  }
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Montserrat')),
      backgroundColor: error ? const Color(0xFFD33426) : null,
      behavior: SnackBarBehavior.floating,
    ));
}
