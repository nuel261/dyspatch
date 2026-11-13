import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/map_tiles.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'job_screen.dart';

const packageSizes = {'small': 'Small package', 'medium': 'Medium package', 'large': 'Large package'};

/// Full-screen job request with a countdown. Pops `true` when accepted.
class OfferScreen extends StatefulWidget {
  final Offer offer;
  const OfferScreen({super.key, required this.offer});
  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  Timer? _timer;
  bool _accepting = false;
  bool _closed = false;
  Offer get o => widget.offer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (o.secondsLeft <= 0 && !_accepting) {
        _close(false, 'Request expired');
      } else {
        setState(() {});
      }
    });
    RiderState.instance.addListener(_watch);
  }

  /// Another rider accepted, or the customer cancelled → close.
  void _watch() {
    if (_accepting || _closed) return;
    final still = RiderState.instance.offers.any((x) => x.id == o.id);
    if (!still) _close(false, 'This request is no longer available');
  }

  void _close(bool accepted, [String? msg]) {
    if (_closed || !mounted) return;
    _closed = true;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    nav.pop(accepted);
    if (msg != null && messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    RiderState.instance.removeListener(_watch);
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    HapticFeedback.mediumImpact();
    try {
      final order = await RiderState.instance.accept(o);
      if (!mounted) return;
      _closed = true;
      final nav = Navigator.of(context);
      nav.pop(true);
      nav.push(MaterialPageRoute(builder: (_) => JobScreen(orderId: (order['id'] as num).toInt())));
    } catch (e) {
      if (!mounted) return;
      _accepting = false;
      _close(false, e.toString());
    }
  }

  Future<void> _decline() async {
    _closed = true;
    RiderState.instance.decline(o);
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final left = o.secondsLeft;
    final frac = o.expiresIn <= 0 ? 0.0 : (o.expiresAt.difference(DateTime.now()).inMilliseconds / (o.expiresIn * 1000)).clamp(0.0, 1.0);
    final pickup = LatLng(o.pickupLat, o.pickupLng);
    final drop = LatLng(o.dropoffLat, o.dropoffLng);
    return PopScope(
      canPop: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 170,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(bounds: LatLngBounds(pickup, drop), padding: const EdgeInsets.all(40)),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    tiles(context),
                    PolylineLayer(polylines: [Polyline(points: [pickup, drop], color: routeColor, strokeWidth: 4, pattern: StrokePattern.dashed(segments: const [10, 8]))]),
                    MarkerLayer(markers: [pinMarker(pickup, brandGreen, icon: Icons.inventory_2), pinMarker(drop, dangerRed, icon: Icons.flag)]),
                    osmCredit(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('NEW DELIVERY REQUEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: brandGreen, letterSpacing: 0.6)),
                        const SizedBox(height: 6),
                        Text(naira(o.earningKobo), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: context.ink)),
                        const Text('you earn', style: TextStyle(fontSize: 13, color: inkGrey)),
                      ]),
                    ),
                    SizedBox(
                      width: 64, height: 64,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 64, height: 64,
                          child: CircularProgressIndicator(
                            value: frac, strokeWidth: 5, backgroundColor: context.line,
                            color: left <= 10 ? dangerRed : brandGreen,
                          ),
                        ),
                        Text('$left', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: left <= 10 ? dangerRed : context.ink)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip(context, Icons.near_me_outlined, '${km(o.toPickupKm)} to pickup'),
                    _chip(context, Icons.route_outlined, '${km(o.tripKm)} trip'),
                    _chip(context, Icons.inventory_2_outlined, packageSizes[o.packageType] ?? o.packageType),
                  ]),
                  if (o.isCash) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      color: warnAmber.withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.payments_outlined, color: warnAmber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Cash job · collect ${naira(o.feeKobo)} from the sender', style: const TextStyle(color: warnAmber, fontWeight: FontWeight.w700, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  RouteLines(pickup: o.pickup, dropoff: o.dropoff),
                  const SizedBox(height: 20),
                  AppButton('Accept delivery', loading: _accepting, icon: Icons.check_circle_outline, onTap: _accept),
                  const SizedBox(height: 10),
                  AppButton('Decline', outline: true, color: inkGrey, onTap: _accepting ? null : _decline),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: context.cs.secondary, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: inkGrey),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.ink)),
        ]),
      );
}
