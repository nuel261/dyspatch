import 'package:dyspatch_app/Features/Home/Screen/create_delivery.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

enum NotifCategory { deliveries, payments, system }

class AppNotification {
  final NotifCategory category;
  final String title;
  final String? subtitle;
  final String timeAgo;
  final String dateGroup;
  final bool isRead;
  final String? trackId;

  const AppNotification({
    required this.category,
    required this.title,
    this.subtitle,
    required this.timeAgo,
    required this.dateGroup,
    this.isRead = true,
    this.trackId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final when = parseTime(j['created_at']);
    final data = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : const <String, dynamic>{};
    return AppNotification(
      category: switch (j['category']) { 'delivery' => NotifCategory.deliveries, 'payment' => NotifCategory.payments, _ => NotifCategory.system },
      title: (j['title'] ?? '') as String,
      subtitle: j['body'] as String?,
      timeAgo: formatTimeAgo(when),
      dateGroup: dayGroup(when),
      isRead: j['is_read'] == true,
      trackId: data['track_id'] as String?,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = "All";

  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DyspatchApi.notifications();
      if (!mounted) return;
      setState(() {
        _notifications = rows.map(AppNotification.fromJson).toList();
        _loading = false;
        _error = null;
      });
      if (_notifications.any((n) => !n.isRead)) DyspatchApi.markNotificationsRead().catchError((_) {});
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<AppNotification> get _filtered {
    if (_filter == "All") return _notifications;
    if (_filter == "Deliveries") {
      return _notifications
          .where((n) => n.category == NotifCategory.deliveries)
          .toList();
    }
    if (_filter == "Payments") {
      return _notifications
          .where((n) => n.category == NotifCategory.payments)
          .toList();
    }
    return _notifications
        .where((n) => n.category == NotifCategory.system)
        .toList();
  }

  Map<String, List<AppNotification>> get _grouped {
    final map = <String, List<AppNotification>>{};
    for (final n in _filtered) {
      map.putIfAbsent(n.dateGroup, () => []).add(n);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Notifications",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Chip(
                    label: "All",
                    selected: _filter == "All",
                    onTap: () => setState(() => _filter = "All"),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: "Deliveries",
                    selected: _filter == "Deliveries",
                    onTap: () => setState(() => _filter = "Deliveries"),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: "Payments",
                    selected: _filter == "Payments",
                    onTap: () => setState(() => _filter = "Payments"),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: "System",
                    selected: _filter == "System",
                    onTap: () => setState(() => _filter = "System"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF298341)))
                  : grouped.isEmpty
                  ? Center(
                      child: Text(
                        _error ?? "No notifications",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final group in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              group.key,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          for (final n in group.value)
                            GestureDetector(
                              onTap: n.trackId == null
                                  ? null
                                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(initialTrackId: n.trackId))),
                              child: _NotifTile(notif: n),
                            ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDelivery())),
        backgroundColor: const Color(0xFF298341),
        shape: const CircleBorder(),
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF298341)
              : const Color(0xFF298341).withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF298341),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Notification tile
// ─────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification notif;

  const _NotifTile({required this.notif});

  IconData get _icon {
    switch (notif.category) {
      case NotifCategory.payments:
        return Icons.account_balance_wallet_outlined;
      case NotifCategory.system:
        return Icons.info_outline_rounded;
      case NotifCategory.deliveries:
        return Icons.directions_bike_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF298341).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 17, color: const Color(0xFF298341)),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          fontWeight: notif.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF298341),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notif.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    notif.subtitle!,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  notif.timeAgo,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}