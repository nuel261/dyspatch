import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/rider_api.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'job_screen.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  String _filter = 'completed';
  List<Map<String, dynamic>>? _rows;
  String? _error;
  int? _seenActive;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await RiderApi.orders(status: _filter);
      if (mounted) setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = context.watch<RiderState>().activeOrderId;
    if (active != _seenActive) {
      _seenActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final rs = context.watch<RiderState>();
    return Scaffold(
      appBar: appBar(context, 'My deliveries'),
      body: RefreshIndicator(
        color: brandGreen,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          if (rs.activeOrder != null) ...[
            const SectionLabel('In progress'),
            _JobCard(order: rs.activeOrder!, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(orderId: rs.activeOrderId!))).then((_) => _load())),
          ],
          SectionLabel('History', trailing: SegmentedButton<String>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [ButtonSegment(value: 'completed', label: Text('Completed')), ButtonSegment(value: 'all', label: Text('All'))],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() {
                _filter = s.first;
                _rows = null;
              });
              _load();
            },
          )),
          if (_rows == null && _error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_error != null) EmptyState(icon: Icons.wifi_off, title: "Couldn't load deliveries", subtitle: _error, action: AppButton('Try again', onTap: _load)),
          if (_rows != null && _rows!.isEmpty)
            const EmptyState(icon: Icons.inventory_2_outlined, title: 'No deliveries yet', subtitle: 'Go online from Home. Your completed deliveries and earnings will show here.'),
          ...?_rows?.where((o) => o['id'] != rs.activeOrderId).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _JobCard(order: o, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(orderId: (o['id'] as num).toInt())))),
              )),
        ]),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _JobCard({required this.order, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final st = order['status'] as String? ?? '';
    final when = parseTime(order['delivered_at']) ?? parseTime(order['created_at']);
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(order['track_id'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
          const SizedBox(width: 8),
          Text(dayTime(when), style: const TextStyle(fontSize: 12, color: inkGrey)),
          const Spacer(),
          StatusPill(statusLabel(st), color: statusColor(st)),
        ]),
        const SizedBox(height: 12),
        RouteLines(pickup: order['pickup']?['address'] as String? ?? '', dropoff: order['dropoff']?['address'] as String? ?? ''),
        const SizedBox(height: 10),
        Row(children: [
          Text(km(order['distance_km'] as num?), style: const TextStyle(fontSize: 12.5, color: inkGrey)),
          if (order['payment_method'] == 'cash') const Text('  ·  Cash', style: TextStyle(fontSize: 12.5, color: inkGrey)),
          const Spacer(),
          Text(naira(order['earning_kobo'] as num?), style: TextStyle(fontWeight: FontWeight.w700, color: st == 'delivered' ? brandGreen : context.ink)),
        ]),
      ]),
    );
  }
}
