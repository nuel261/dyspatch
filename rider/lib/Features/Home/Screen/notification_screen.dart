import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/ui/format.dart';
import 'package:dyspatch_rider/Features/Home/widget/ride_tabs.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dyspatch_rider/Features/Home/model/notification_category.dart';

enum _NotifFilter { all, orders, payments, system }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifFilter _selected = _NotifFilter.all;
  int _selectedRide = 0;

  static const Map<_NotifFilter, String> _labels = {
    _NotifFilter.all: 'All',
    _NotifFilter.orders: 'Orders',
    _NotifFilter.payments: 'Payments',
    _NotifFilter.system: 'System',
  };

  List<NotificationEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await RiderApi.notifications();
      if (!mounted) return;
      setState(() {
        _entries = list.map((n) {
          final at = parseTime(n['created_at']);
          final cat = switch (n['category']) {
            'order' || 'orders' || 'delivery' => NotificationCategory.orders,
            'payment' || 'payments' || 'wallet' => NotificationCategory.payments,
            _ => NotificationCategory.system,
          };
          return NotificationEntry(
            title: (n['title'] as String?) ?? 'Dyspatch',
            description: (n['body'] as String?) ?? '',
            time: timeAgo(at),
            dayGroup: dayGroup(at),
            category: cat,
            icon: switch (cat) {
              NotificationCategory.orders => Icons.local_shipping_outlined,
              NotificationCategory.payments => Icons.account_balance_wallet_outlined,
              NotificationCategory.system => Icons.info_outline,
            },
          );
        }).toList();
      });
      RiderApi.markAllRead().catchError((_) {});
    } catch (_) {}
  }

  List<NotificationEntry> get _filtered {
    switch (_selected) {
      case _NotifFilter.all:
        return _entries;
      case _NotifFilter.orders:
        return _entries
            .where((e) => e.category == NotificationCategory.orders)
            .toList();
      case _NotifFilter.payments:
        return _entries
            .where((e) => e.category == NotificationCategory.payments)
            .toList();
      case _NotifFilter.system:
        return _entries
            .where((e) => e.category == NotificationCategory.system)
            .toList();
    }
  }

  Map<String, List<NotificationEntry>> get _grouped {
    final map = <String, List<NotificationEntry>>{};
    for (final entry in _filtered) {
      map.putIfAbsent(entry.dayGroup, () => []).add(entry);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: cs.primary,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF298341),
        shape: const CircleBorder(),
        child: const Icon(Icons.map_outlined, color: Colors.white, size: 26),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.tertiaryContainer,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: cs.inversePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Category Filter chips ──
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _NotifFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final filter = _NotifFilter.values[index];
                  final isSelected = filter == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF298341)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _labels[filter]!,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF298341),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Ride Tabs (fleet owners, only under "System") ──
            if (RiderSession.isFleetOwner &&
                _selected == _NotifFilter.system) ...[
              const SizedBox(height: 14),
              RideTabs(
                selected: _selectedRide,
                onSelected: (i) => setState(() => _selectedRide = i),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],

            const SizedBox(height: 20),

            // ── List OR Empty State ──
            Expanded(
              child: grouped.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: grouped.entries.expand((groupEntry) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              groupEntry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          ...groupEntry.value.map(
                            (entry) => _notificationTile(entry),
                          ),
                          const SizedBox(height: 20),
                        ];
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(NotificationEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, size: 16, color: const Color(0xFF298341)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'Montserrat',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/rafiki.svg', height: 140),
          const SizedBox(height: 20),
          Text(
            'Nothing here yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay tuned! Updates about your\norders activities will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontFamily: 'Montserrat',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
