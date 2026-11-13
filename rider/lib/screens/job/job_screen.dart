import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/rider_api.dart';
import '../../core/services/location_service.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/map_tiles.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'offer_screen.dart' show packageSizes;

/// The active delivery: map + one clear next action per step.
///   matched   → go to pickup, enter the sender's pickup code
///   picked_up → start the trip
///   en_route  → tell us you've arrived (the recipient gets their delivery code by SMS)
///   arrived   → enter the recipient's delivery code (+ optional proof photo)
class JobScreen extends StatefulWidget {
  final int orderId;
  const JobScreen({super.key, required this.orderId});
  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  Map<String, dynamic>? _o;
  String? _error;
  bool _acting = false;
  LatLng? _me;
  final _map = MapController();
  Timer? _poll;
  StreamSubscription? _locSub;
  bool _fitted = false;

  String get _status => _o?['status'] as String? ?? 'matched';
  bool get _toPickup => _status == 'matched';
  LatLng _pt(String k) => LatLng((_o![k]['lat'] as num).toDouble(), (_o![k]['lng'] as num).toDouble());

  @override
  void initState() {
    super.initState();
    final cached = RiderState.instance.activeOrder;
    if (cached != null && (cached['id'] as num).toInt() == widget.orderId) _o = cached;
    final l = LocationService.instance.last;
    if (l != null) _me = LatLng(l.latitude, l.longitude);
    _locSub = LocationService.instance.positions.listen((p) {
      if (mounted) setState(() => _me = LatLng(p.latitude, p.longitude));
    });
    LocationService.instance.startTracking();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final o = await RiderApi.order(widget.orderId);
      if (!mounted) return;
      final wasActive = _o != null && !['cancelled', 'failed', 'delivered'].contains(_status);
      setState(() {
        _o = o;
        _error = null;
      });
      RiderState.instance.setActiveOrder(o);
      _fit();
      if (wasActive && o['status'] == 'cancelled') _cancelledDialog();
    } catch (e) {
      if (!silent && mounted) setState(() => _error = e.toString());
    }
  }

  void _fit() {
    if (_fitted || _o == null) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final pts = [_pt('pickup'), _pt('dropoff'), if (_me != null) _me!];
        _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(40, 60, 40, 40)));
      } catch (_) {}
    });
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() call, {String? done}) async {
    setState(() => _acting = true);
    try {
      final o = await call();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _o = o);
      RiderState.instance.setActiveOrder(o);
      if (done != null) toast(context, done);
      if (o['status'] == 'delivered') _deliveredDialog();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  ({double? lat, double? lng}) get _here => (lat: LocationService.instance.last?.latitude, lng: LocationService.instance.last?.longitude);

  Future<void> _primary() async {
    final id = widget.orderId;
    switch (_status) {
      case 'matched':
        final code = await _codeSheet(title: 'Pickup code', body: 'Ask the sender for the 4-digit pickup code shown in their Dyspatch app.');
        if (code != null) await _act(() => RiderApi.pickup(id, code, lat: _here.lat, lng: _here.lng), done: 'Package picked up');
        break;
      case 'picked_up':
        await _act(() => RiderApi.enRoute(id, lat: _here.lat, lng: _here.lng), done: 'Trip started — drive safe');
        break;
      case 'en_route':
        await _act(() => RiderApi.arrived(id, lat: _here.lat, lng: _here.lng), done: 'The recipient has been sent their delivery code');
        break;
      case 'arrived':
        final res = await _codeSheet(
          title: 'Delivery code',
          body: 'Ask ${_o?['recipient_name'] ?? 'the recipient'} for the 4-digit code we sent them by SMS.',
          withPhoto: true,
        );
        if (res != null) {
          await _act(() => RiderApi.deliver(id, res, photoDataUri: _proof, lat: _here.lat, lng: _here.lng));
        }
        break;
    }
  }

  String? _proof;

  Future<String?> _codeSheet({required String title, required String body, bool withPhoto = false}) {
    _proof = null;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CodeSheet(title: title, body: body, withPhoto: withPhoto, onPhoto: (p) => _proof = p),
    );
  }

  Future<void> _report() async {
    const reasons = ['Sender unavailable at pickup', 'Recipient unavailable', 'Wrong address', 'Package damaged', 'Package not as described', 'Vehicle problem'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text("Can't complete this delivery?", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 6, 24, 8),
            child: Text('Choose the reason. Our team is alerted and will contact you and the customer.', textAlign: TextAlign.center, style: TextStyle(color: inkGrey, fontSize: 13)),
          ),
          ...reasons.map((r) => ListTile(title: Text(r), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(context, r))),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (reason == null || !mounted) return;
    final ok = await _confirm('Report and end this delivery?', 'Reason: $reason');
    if (ok) await _act(() => RiderApi.fail(widget.orderId, reason), done: 'Reported. Our team will be in touch.');
  }

  Future<void> _sos() async {
    final ok = await _confirm('Send SOS?', 'Dyspatch safety team will be alerted with your location right away.', danger: true, action: 'Send SOS');
    if (!ok) return;
    try {
      await RiderApi.sos('Rider SOS during ${_o?['track_id'] ?? 'delivery'}');
      if (mounted) toast(context, 'SOS sent. Our team has been alerted.');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<bool> _confirm(String title, String body, {bool danger = false, String action = 'Confirm'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action, style: TextStyle(color: danger ? dangerRed : brandGreen, fontWeight: FontWeight.w700))),
          ],
        ),
      ) ??
      false;

  void _cancelledDialog() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delivery cancelled'),
          content: const Text("The customer or our team cancelled this delivery. Don't go to the pickup."),
          actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('OK'))],
        ),
      );

  void _deliveredDialog() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: brandGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: brandGreen, size: 46),
            ),
            const SizedBox(height: 16),
            const Text('Delivered!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              _o?['payment_method'] == 'cash'
                  ? 'Great job. You collected ${naira(_o?['collect_cash_kobo'] as num?)} cash; our commission was taken from your wallet.'
                  : '${naira(_o?['earning_kobo'] as num?)} has been added to your wallet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: inkGrey, height: 1.5),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('Back to home', style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Future<void> _navigate() async {
    final t = _pt(_toPickup ? 'pickup' : 'dropoff');
    final app = Uri.parse('google.navigation:q=${t.latitude},${t.longitude}&mode=d');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}&travelmode=driving');
    if (!await launchUrl(app)) await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  void _call(String? phone) {
    if (phone == null || phone.isEmpty) return toast(context, 'No phone number on this delivery', error: true);
    launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: appBar(context, o?['track_id'] as String? ?? 'Delivery', actions: [
        TextButton.icon(
          onPressed: _sos,
          icon: const Icon(Icons.warning_amber_rounded, color: dangerRed),
          label: const Text('SOS', style: TextStyle(color: dangerRed, fontWeight: FontWeight.w700)),
        ),
      ]),
      body: o == null
          ? Center(child: _error != null ? EmptyState(icon: Icons.wifi_off, title: "Couldn't load this delivery", subtitle: _error, action: AppButton('Try again', onTap: _load)) : const CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: Stack(children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(initialCenter: _pt('pickup'), initialZoom: 14),
                    children: [
                      tiles(context),
                      PolylineLayer(polylines: [
                        Polyline(points: [_pt('pickup'), _pt('dropoff')], color: routeColor.withValues(alpha: 0.35), strokeWidth: 4),
                        if (_me != null && !_done)
                          Polyline(points: [_me!, _pt(_toPickup ? 'pickup' : 'dropoff')], color: routeColor, strokeWidth: 4, pattern: StrokePattern.dashed(segments: const [10, 8])),
                      ]),
                      MarkerLayer(markers: [
                        pinMarker(_pt('pickup'), brandGreen, icon: Icons.inventory_2),
                        pinMarker(_pt('dropoff'), dangerRed, icon: Icons.flag),
                        if (_me != null) meMarker(_me!),
                      ]),
                      osmCredit(),
                    ],
                  ),
                  if (!_done)
                    Positioned(
                      right: 14, bottom: 14,
                      child: FloatingActionButton.extended(
                        heroTag: 'nav',
                        onPressed: _navigate,
                        backgroundColor: brandGreen,
                        icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                        label: Text(_toPickup ? 'To pickup' : 'To drop-off', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
              _panel(o),
            ]),
    );
  }

  bool get _done => ['delivered', 'cancelled', 'failed'].contains(_status);

  Widget _panel(Map<String, dynamic> o) {
    final steps = ['Pickup', 'On the way', 'Deliver'];
    final stepIndex = switch (_status) { 'matched' => 0, 'picked_up' || 'en_route' => 1, _ => 2 };
    final (label, icon) = switch (_status) {
      'matched' => ('I have the package', Icons.qr_code_2_rounded),
      'picked_up' => ('Start delivery', Icons.play_arrow_rounded),
      'en_route' => ("I've arrived", Icons.place_rounded),
      'arrived' => ('Complete delivery', Icons.check_circle_outline),
      _ => ('', Icons.check),
    };
    final contactName = _toPickup ? (o['sender_name'] as String? ?? 'Sender') : (o['recipient_name'] as String? ?? 'Recipient');
    final contactPhone = _toPickup ? o['sender_phone'] as String? : o['recipient_phone'] as String?;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!_done)
              Row(children: List.generate(steps.length, (i) {
                final on = i <= stepIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 4, decoration: BoxDecoration(color: on ? brandGreen : context.line, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Text(steps[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: on ? brandGreen : inkGrey)),
                    ]),
                  ),
                );
              })),
            if (_done) Row(children: [StatusPill(statusLabel(_status), color: statusColor(_status)), const Spacer(), Text(naira(o['earning_kobo'] as num?), style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))]),
            const SizedBox(height: 14),
            Text(_toPickup ? 'PICK UP FROM' : 'DELIVER TO', style: const TextStyle(fontSize: 11, color: inkGrey, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text((_toPickup ? o['pickup'] : o['dropoff'])['address'] as String? ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink, height: 1.3)),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: brandGreen.withValues(alpha: 0.12), child: Text(contactName.isNotEmpty ? contactName[0].toUpperCase() : '?', style: const TextStyle(color: brandGreen, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(contactName, style: TextStyle(fontWeight: FontWeight.w600, color: context.ink)),
                  Text('${_toPickup ? 'Sender' : 'Recipient'} · ${packageSizes[o['package_type']] ?? ''}', style: const TextStyle(fontSize: 12, color: inkGrey)),
                ]),
              ),
              if (!_done) ...[
                CircleIconButton(Icons.call_outlined, color: brandGreen, onTap: () => _call(contactPhone)),
                const SizedBox(width: 8),
                CircleIconButton(Icons.sms_outlined, color: brandGreen, onTap: () => contactPhone == null ? null : launchUrl(Uri.parse('sms:$contactPhone'))),
              ],
            ]),
            if ((o['package_description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Package: ${o['package_description']}', style: const TextStyle(fontSize: 13, color: inkGrey)),
            ],
            if (o['payment_method'] == 'cash' && !_done) ...[
              const SizedBox(height: 12),
              AppCard(
                color: warnAmber.withValues(alpha: 0.12),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.payments_outlined, color: warnAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Collect ${naira(o['collect_cash_kobo'] as num?)} cash from the sender at pickup', style: const TextStyle(color: warnAmber, fontWeight: FontWeight.w700, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            if (!_done) ...[
              AppButton(label, icon: icon, loading: _acting, onTap: _primary),
              const SizedBox(height: 6),
              Center(child: TextButton(onPressed: _acting ? null : _report, child: const Text('Report a problem', style: TextStyle(color: inkGrey)))),
            ] else
              AppButton('Done', outline: true, onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  final String title, body;
  final bool withPhoto;
  final ValueChanged<String?> onPhoto;
  const _CodeSheet({required this.title, required this.body, required this.withPhoto, required this.onPhoto});
  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _c = TextEditingController();
  String? _photo;

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 75);
    if (x == null) return;
    final data = RiderApi.dataUri(await x.readAsBytes());
    setState(() => _photo = data);
    widget.onPhoto(data);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.ink)),
        const SizedBox(height: 6),
        Text(widget.body, style: const TextStyle(fontSize: 14, color: inkGrey, height: 1.5)),
        const SizedBox(height: 18),
        TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 30, letterSpacing: 18, fontWeight: FontWeight.w700, color: context.ink),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            filled: true,
            fillColor: context.cs.secondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        if (widget.withPhoto) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _takePhoto,
            icon: Icon(_photo == null ? Icons.photo_camera_outlined : Icons.check_circle, color: brandGreen),
            label: Text(_photo == null ? 'Add proof-of-delivery photo (optional)' : 'Photo added — tap to retake', style: const TextStyle(color: brandGreen)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: brandGreen), minimumSize: const Size.fromHeight(46)),
          ),
        ],
        const SizedBox(height: 16),
        AppButton('Confirm', onTap: _c.text.length == 4 ? () => Navigator.pop(context, _c.text) : null),
      ]),
    );
  }
}
