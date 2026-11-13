import 'package:flutter/material.dart';

import '../../core/api/rider_api.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await RiderApi.notifications();
      if (mounted) setState(() => _rows = r);
      RiderApi.markAllRead().catchError((_) {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  IconData _icon(String c) => switch (c) { 'delivery' => Icons.inventory_2_outlined, 'payment' => Icons.account_balance_wallet_outlined, _ => Icons.info_outline };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(context, 'Notifications'),
      body: RefreshIndicator(
        color: brandGreen,
        onRefresh: _load,
        child: _rows == null
            ? ListView(children: [
                if (_error != null) EmptyState(icon: Icons.wifi_off, title: "Couldn't load notifications", subtitle: _error, action: AppButton('Try again', onTap: _load))
                else const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
              ])
            : _rows!.isEmpty
                ? ListView(children: const [EmptyState(icon: Icons.notifications_none, title: 'No notifications yet', subtitle: 'Job requests, payouts and account updates will appear here.')])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _rows![i];
                      final unread = n['is_read'] != true;
                      return AppCard(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          CircleAvatar(backgroundColor: brandGreen.withValues(alpha: 0.1), child: Icon(_icon(n['category'] as String? ?? ''), color: brandGreen, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(n['title'] as String? ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600, color: context.ink))),
                                if (unread) const CircleAvatar(radius: 4, backgroundColor: brandGreen),
                              ]),
                              const SizedBox(height: 4),
                              Text(n['body'] as String? ?? '', style: const TextStyle(fontSize: 13, color: inkGrey, height: 1.4)),
                              const SizedBox(height: 6),
                              Text(timeAgo(parseTime(n['created_at'])), style: const TextStyle(fontSize: 11.5, color: inkGrey)),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
