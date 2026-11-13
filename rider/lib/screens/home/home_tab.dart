import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api/session.dart';
import '../../core/services/location_service.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/map_tiles.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../account/notifications_screen.dart';
import '../job/job_screen.dart';
import '../onboarding/verification_screen.dart';

class HomeTab extends StatelessWidget {
  final void Function(int tab) onOpenTab;
  const HomeTab({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RiderState>();
    final s = context.watch<Session>();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: brandGreen,
          onRefresh: st.refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
            // ── Top bar ──
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello ${s.firstName} 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.ink)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B400)),
                    const SizedBox(width: 3),
                    Text(st.rating > 0 ? st.rating.toStringAsFixed(1) : 'New rider', style: const TextStyle(fontSize: 13, color: inkGrey, fontWeight: FontWeight.w600)),
                    if ((s.rider?['plate'] as String? ?? '').isNotEmpty) ...[
                      const Text('  ·  ', style: TextStyle(color: inkGrey)),
                      Text(s.rider!['plate'] as String, style: const TextStyle(fontSize: 13, color: inkGrey)),
                    ],
                  ]),
                ]),
              ),
              CircleIconButton(Icons.notifications_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ]),
            const SizedBox(height: 18),

            if (!s.canWork) _VerifyBanner(status: s.kycStatus, accountStatus: s.status),
            if (s.canWork) _OnlineCard(st: st),

            if (st.activeOrder != null) ...[
              const SectionLabel('Current delivery'),
              _ActiveJobCard(order: st.activeOrder!),
            ],

            const SectionLabel('Today'),
            Row(children: [
              Expanded(child: _Stat(label: 'Earned', value: naira(st.todayEarningsKobo), icon: Icons.payments_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Deliveries', value: '${st.todayDeliveries}', icon: Icons.inventory_2_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Wallet', value: naira(st.walletKobo), icon: Icons.account_balance_wallet_outlined, onTap: () => onOpenTab(2))),
            ]),

            const SectionLabel('Your area'),
            const _AreaMap(),
            const SizedBox(height: 14),
            const _Tips(),
          ]),
        ),
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  final RiderState st;
  const _OnlineCard({required this.st});

  Future<void> _toggle(BuildContext context) async {
    final err = st.online ? await st.goOffline() : await st.goOnline();
    if (err != null && context.mounted) toast(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final on = st.online;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: on ? const LinearGradient(colors: [Color(0xFF298341), Color(0xFF1D5E2E)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: on ? null : context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: on ? const Color(0xFF7CF29A) : const Color(0xFFBDBDBD), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(on ? "You're online" : "You're offline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: on ? Colors.white : context.ink)),
          const Spacer(),
          Transform.scale(
            scale: 1.15,
            child: Switch(
              value: on,
              onChanged: st.busy ? null : (_) => _toggle(context),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF7CF29A),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          on
              ? (st.activeOrderId != null ? 'Finish your current delivery to get new requests.' : 'Waiting for delivery requests nearby. Keep the app open or in the background.')
              : 'Go online to start receiving delivery requests near you.',
          style: TextStyle(fontSize: 13, height: 1.45, color: on ? Colors.white.withValues(alpha: 0.9) : inkGrey),
        ),
        if (st.busy) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(minHeight: 3, color: on ? Colors.white : brandGreen, backgroundColor: Colors.transparent),
        ],
      ]),
    );
  }
}

class _VerifyBanner extends StatelessWidget {
  final String status;
  final String accountStatus;
  const _VerifyBanner({required this.status, required this.accountStatus});
  @override
  Widget build(BuildContext context) {
    final suspended = accountStatus == 'suspended';
    final review = status == 'submitted';
    final (title, body, color) = suspended
        ? ('Account suspended', 'Contact rider support to reactivate your account.', dangerRed)
        : review
            ? ('Verification in review', "We're checking your ID — usually under 48 hours. You can go online once approved.", warnAmber)
            : status == 'verified'
                ? ('Almost ready', 'Your account is being activated by our team.', warnAmber)
                : ('Verify your identity', 'Add your ID to start receiving delivery requests.', brandGreen);
    return AppCard(
      onTap: (review || suspended || status == 'verified')
          ? null
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen(fromAccount: true))),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(review ? Icons.hourglass_top_rounded : (suspended ? Icons.block : Icons.badge_outlined), color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(fontSize: 13, color: inkGrey, height: 1.4)),
          ]),
        ),
        if (!review && !suspended && status != 'verified') const Icon(Icons.chevron_right, color: inkGrey),
      ]),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActiveJobCard({required this.order});
  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'matched';
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(orderId: (order['id'] as num).toInt()))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(order['track_id'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
          const Spacer(),
          StatusPill(statusLabel(status), color: statusColor(status)),
        ]),
        const SizedBox(height: 14),
        RouteLines(pickup: order['pickup']?['address'] as String? ?? '', dropoff: order['dropoff']?['address'] as String? ?? ''),
        const SizedBox(height: 14),
        Row(children: [
          Text('You earn ${naira(order['earning_kobo'] as num?)}', style: const TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('Continue', style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right, color: brandGreen),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  const _Stat({required this.label, required this.value, required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: brandGreen),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: inkGrey)),
        ]),
      );
}

class _AreaMap extends StatefulWidget {
  const _AreaMap();
  @override
  State<_AreaMap> createState() => _AreaMapState();
}

class _AreaMapState extends State<_AreaMap> {
  final _map = MapController();
  LatLng? _me;

  @override
  void initState() {
    super.initState();
    final l = LocationService.instance.last;
    if (l != null) _me = LatLng(l.latitude, l.longitude);
    LocationService.instance.positions.listen((p) {
      if (!mounted) return;
      final first = _me == null;
      setState(() => _me = LatLng(p.latitude, p.longitude));
      if (first) _map.move(_me!, 15);
    });
    if (_me == null) {
      LocationService.instance.current().then((p) {
        if (p != null && mounted) {
          setState(() => _me = LatLng(p.latitude, p.longitude));
          _map.move(_me!, 15);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 210,
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _me ?? const LatLng(6.335, 5.6037),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
            ),
            children: [tiles(context), if (_me != null) MarkerLayer(markers: [meMarker(_me!)]), osmCredit()],
          ),
          if (_me == null)
            Positioned.fill(
              child: Container(
                color: context.card.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: const Text('Turn on location to see your area', style: TextStyle(color: inkGrey, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_outline, color: brandGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Requests go to the nearest riders first. Stay close to markets, campuses and business districts at busy times to get more jobs.',
              style: TextStyle(fontSize: 13, height: 1.5, color: context.ink),
            ),
          ),
        ]),
      );
}
