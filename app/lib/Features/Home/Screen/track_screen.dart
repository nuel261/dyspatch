import 'dart:async';

import 'package:dyspatch_app/Features/Home/Screen/create_delivery.dart';
import 'package:dyspatch_app/core/api/api_client.dart';
import 'package:dyspatch_app/core/api/api_config.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/theme/theme_provider.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/ride_model.dart';
import '../services/tracking_service.dart';
import '../utils/polyline_decoder.dart';

class TrackScreen extends StatefulWidget {
  final VoidCallback? onBack;

  /// Opens straight onto this Track ID (from a delivery card, push notification, etc).
  final String? initialTrackId;
  const TrackScreen({super.key, this.onBack, this.initialTrackId});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────
  final MapController _mapController = MapController();
  final Location _location = Location();
  final TextEditingController _orderIdController = TextEditingController();
  StreamSubscription<LocationData>? _locationSub;

  // ── Location State ────────────────────────────────────
  bool _isLocating = true;
  LatLng? _currentLocation;

  // ── Ride State ────────────────────────────────────────
  bool _isSearching = false;
  String? _searchError;
  RideModel? _ride;
  LatLng? _riderLocation;
  List<LatLng> _route = [];
  int _etaMinutes = 0;
  RideStatus _status = RideStatus.pending;
  DateTime? _lastRouteFetch;
  bool _mapReady = false;

  // ── Card visibility ───────────────────────────────────
  bool _showDeliveryCard = false;

  // ── Polling ───────────────────────────────────────────
  Timer? _pollingTimer;
  int _pollTick = 0;

  // ── Animation ─────────────────────────────────────────
  late AnimationController _cardAnimController;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _cardSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut));
    if (widget.initialTrackId != null && widget.initialTrackId!.isNotEmpty) {
      _orderIdController.text = widget.initialTrackId!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchOrder());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _locationSub?.cancel();
    _orderIdController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      if (!await _checkLocationPermission()) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }
      _locationSub = _location.onLocationChanged.listen((LocationData d) {
        if (d.latitude != null && d.longitude != null && mounted) {
          setState(() {
            _currentLocation = LatLng(d.latitude!, d.longitude!);
            _isLocating = false;
          });
        }
      });
      // Don't block the map forever if the first fix is slow.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isLocating) setState(() => _isLocating = false);
      });
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }
    return true;
  }

  void _moveMap(LatLng center, double zoom) {
    if (_mapReady) {
      try {
        _mapController.move(center, zoom);
      } catch (_) {}
    }
  }

  void _recenterMap() {
    final center = _riderLocation ?? _ride?.dropoffLocation ?? _currentLocation;
    if (center != null) {
      _moveMap(center, 14);
    } else {
      _showSnackbar('Location not available');
    }
  }

  // ── Search ────────────────────────────────────────────

  Future<void> _searchOrder() async {
    final trackId = _orderIdController.text.trim().toUpperCase();
    if (trackId.isEmpty) return;

    FocusScope.of(context).unfocus();
    _pollingTimer?.cancel();

    setState(() {
      _isSearching = true;
      _searchError = null;
      _ride = null;
      _route = [];
      _riderLocation = null;
      _showDeliveryCard = false;
      _lastRouteFetch = null;
    });

    try {
      final ride = await TrackingService.fetchRideDetails(trackId);
      if (!mounted) return;
      _applyRide(ride);
      setState(() {
        _isSearching = false;
        _showDeliveryCard = true;
      });
      _cardAnimController.forward(from: 0);
      _fitToRide();
      await _refreshRoute(force: true);
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.status == 404 ? 'Order not found. Check the ID and try again.' : e.message;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Could not load this delivery. Check your connection.';
        _isSearching = false;
      });
    }
  }

  void _applyRide(RideModel ride) {
    setState(() {
      _ride = ride;
      _status = ride.status;
      _etaMinutes = ride.etaMinutes;
      final r = ride.rider;
      if (r != null && r.lat != null && r.lng != null && ride.status.isActive) {
        _riderLocation = LatLng(r.lat!, r.lng!);
      }
    });
  }

  void _fitToRide() {
    final ride = _ride;
    if (ride == null) return;
    final pts = <LatLng>[ride.pickupLocation, ride.dropoffLocation, if (_riderLocation != null) _riderLocation!]
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    if (pts.isEmpty || !_mapReady) return;
    try {
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.fromLTRB(60, 160, 60, 320),
        maxZoom: 15,
      ));
    } catch (_) {}
  }

  // ── Polling ───────────────────────────────────────────

  /// Where the rider is heading now: pickup until the parcel is collected, then drop-off.
  LatLng? get _target {
    final ride = _ride;
    if (ride == null) return null;
    return _status == RideStatus.matched ? ride.pickupLocation : ride.dropoffLocation;
  }

  Future<void> _refreshRoute({bool force = false}) async {
    final from = _riderLocation;
    final to = _target;
    if (from == null || to == null || !_status.isActive || _status == RideStatus.arrived) {
      if (mounted) setState(() => _route = []);
      return;
    }
    // OSRM is a shared public service — refresh the road route at most every 30s.
    if (!force && _lastRouteFetch != null && DateTime.now().difference(_lastRouteFetch!).inSeconds < 30) {
      if (_route.isNotEmpty && mounted) setState(() => _route = [from, ..._route.skip(1)]);
      return;
    }
    _lastRouteFetch = DateTime.now();
    List<LatLng> route = [from, to];
    try {
      final geometry = await TrackingService.fetchRouteGeometry(from, to).timeout(const Duration(seconds: 6));
      if (geometry != null) {
        final decoded = decodePolyline(geometry);
        if (decoded.isNotEmpty) route = decoded;
      }
    } catch (e) {
      debugPrint('Route fetch failed, using straight line: $e');
    }
    if (mounted) setState(() => _route = route);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_status.isFinished) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    final ride = _ride;
    if (ride == null || !mounted) return;
    _pollTick++;
    try {
      if (ride.isOwner && _status.isActive && _pollTick % 3 != 0) {
        // Lightweight: rider GPS + ETA every 5s.
        final loc = await TrackingService.fetchRiderLocation(ride.orderId);
        if (!mounted) return;
        final newStatus = RideStatus.fromString((loc['status'] ?? 'pending') as String);
        setState(() {
          if (loc['lat'] != null && loc['lng'] != null) {
            _riderLocation = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          }
          _etaMinutes = (loc['eta_minutes'] as num?)?.toInt() ?? _etaMinutes;
        });
        if (newStatus != _status) {
          _applyRide(await TrackingService.fetchRideDetails(ride.orderId));
        }
      } else {
        // Full refresh every 15s (or always while waiting for a rider / for public tracking).
        _applyRide(await TrackingService.fetchRideDetails(ride.orderId));
      }
      await _refreshRoute();
      if (_status.isFinished) _pollingTimer?.cancel();
    } catch (e) {
      debugPrint('Tracking poll failed: $e');
    }
  }

  // ── Delivery code (replaces "Mark as Delivered") ─────
  // The rider completes the delivery by entering the recipient's 4-digit code,
  // so the customer never marks it delivered themselves.

  Future<void> _regenerateCode() async {
    final ride = _ride;
    if (ride == null) return;
    try {
      final code = await DyspatchApi.regenerateCode(ride.orderId);
      _showSnackbar('New code $code sent to the recipient');
      _applyRide(await TrackingService.fetchRideDetails(ride.orderId));
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _cancelOrder() async {
    final ride = _ride;
    if (ride == null) return;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Cancel delivery?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Wallet payments are refunded to your wallet immediately.',
            style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      _applyRide(RideModel.fromJson(await DyspatchApi.cancelOrder(ride.orderId, 'Cancelled by customer')));
      _pollingTimer?.cancel();
      _showSnackbar('Delivery cancelled');
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  // ── Timeline sheet ────────────────────────────────────

  void _showTimeline() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final ride = _ride;
    if (ride == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.directions_bike, size: 18, color: isDark ? Colors.white : Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery timeline',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...ride.timeline.map((step) => _timelineRow(step, isDark)),
                if (ride.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Parcels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  ...ride.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(
                            child: Text('${it.code} · ${it.description}${it.quantity > 1 ? ' × ${it.quantity}' : ''}',
                                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                          ),
                          Text(it.statusLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF298341), fontWeight: FontWeight.w600)),
                        ]),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timelineRow(TimelineStep step, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: step.isItem ? const Color(0xFF2F6F73) : const Color(0xFF298341),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
              if (step.note != null && step.note!.isNotEmpty)
                Text(step.note!, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.black45)),
            ]),
          ),
          Text(clock(step.time), style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.black54)),
        ],
      ),
    );
  }

  // ── Card toggle ───────────────────────────────────────

  void _toggleDeliveryCard() {
    setState(() => _showDeliveryCard = !_showDeliveryCard);
    if (_showDeliveryCard) {
      _cardAnimController.forward(from: 0);
    } else {
      _cardAnimController.reverse();
    }
  }

  void _dismissCard() {
    _cardAnimController.reverse().then((_) {
      if (mounted) setState(() => _showDeliveryCard = false);
    });
  }

  // ── Actions ───────────────────────────────────────────

  Future<void> _handleShare() async {
    final ride = _ride;
    if (ride == null) return;
    try {
      final url = ride.isOwner
          ? await TrackingService.fetchShareLink(ride.orderId)
          : '${ApiConfig.host}/track?id=${Uri.encodeComponent(ride.orderId)}';
      await Clipboard.setData(ClipboardData(text: 'Track my Dyspatch package ${ride.orderId}: $url'));
      _showSnackbar('Tracking link copied — paste it to the recipient');
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _handleSOS() async {
    final ride = _ride;
    if (ride == null) return;
    if (!ride.isOwner) {
      _showSnackbar('Only the sender can raise an SOS for this delivery');
      return;
    }
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Emergency SOS', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          'This will flag a safety concern to our team immediately. Continue?',
          style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await TrackingService.sendSOS(ride.orderId, _currentLocation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS sent. Our team has been alerted.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _handleCall() async {
    final phone = _ride?.rider?.phone ?? '';
    if (phone.isEmpty) {
      _showSnackbar('The rider’s number is shared with the sender only');
      return;
    }
    if (!await launchUrl(Uri(scheme: 'tel', path: phone))) _showSnackbar('Could not start a call to $phone');
  }

  Future<void> _handleChat() async {
    final phone = _ride?.rider?.phone ?? '';
    if (phone.isEmpty) {
      _showSnackbar('The rider’s number is shared with the sender only');
      return;
    }
    if (!await launchUrl(Uri(scheme: 'sms', path: phone))) _showSnackbar('Could not open messages');
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Status helpers ────────────────────────────────────

  Color _statusColor(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return const Color(0xFFB88704);
      case RideStatus.matched:
        return const Color(0xFFE53935);
      case RideStatus.otpVerified:
        return const Color(0xFF1E88E5);
      case RideStatus.pickedUp:
      case RideStatus.enRoute:
        return const Color(0xFFF59E0B);
      case RideStatus.arrived:
      case RideStatus.delivered:
        return const Color(0xFF298341);
      case RideStatus.cancelled:
      case RideStatus.failed:
        return const Color(0xFF5F6368);
    }
  }

  String _headline(RideModel ride) {
    switch (_status) {
      case RideStatus.pending:
        return 'Finding a nearby rider…';
      case RideStatus.matched:
        return 'Rider arriving for pickup in $_etaMinutes mins';
      case RideStatus.arrived:
        return 'Arrived at ${clock(ride.arrivedAt)}';
      case RideStatus.delivered:
        return 'Parcel delivered at ${clock(ride.deliveredAt)}';
      case RideStatus.cancelled:
        return 'This delivery was cancelled';
      case RideStatus.failed:
        return 'Delivery could not be completed';
      default:
        return 'Arriving in $_etaMinutes mins';
    }
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ── Theme-aware colors ───────────────────────────────
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final scaffoldBg = isDark ? const Color(0xFF0E120F) : const Color(0xFFEEF1F4);
    final surfaceBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final chipBg = isDark ? const Color(0xFF2E3238) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.black54;
    final iconMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    final ride = _ride;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── MAP ───────────────────────────────────────
          _isLocating
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(6.3350, 5.6037), // Benin City
                    initialZoom: 14,
                    minZoom: 5,
                    maxZoom: 18,
                    onMapReady: () {
                      _mapReady = true;
                      _fitToRide();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.dyspatch.delivery',
                    ),
                    if (_currentLocation != null)
                      CurrentLocationLayer(
                        alignPositionOnUpdate: ride == null ? AlignOnUpdate.once : AlignOnUpdate.never,
                        style: LocationMarkerStyle(
                          marker: const DefaultLocationMarker(child: Icon(Icons.location_pin, color: Colors.white)),
                          markerSize: const Size(35, 35),
                          markerDirection: MarkerDirection.heading,
                        ),
                      ),
                    if (_route.isNotEmpty)
                      PolylineLayer(
                        polylines: [Polyline(points: _route, strokeWidth: 5, color: const Color(0xFF1E88E5))],
                      ),
                    if (ride != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ride.pickupLocation,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E0F10),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                          Marker(
                            point: ride.dropoffLocation,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin, size: 40, color: Color(0xFF34A853)),
                          ),
                        ],
                      ),
                    if (_riderLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _riderLocation!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
                              child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

          // ── TOP SEARCH BAR ────────────────────────────
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: iconMuted, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _orderIdController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: "Where's your package? Input track ID",
                            hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _searchOrder(),
                        ),
                      ),
                      _isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(onPressed: _searchOrder, icon: Icon(Icons.arrow_forward, color: iconMuted)),
                    ],
                  ),
                ),
                if (_searchError != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),

          // ── BACK BUTTON ───────────────────────────────
          Positioned(
            top: topPadding + 100,
            left: 16,
            child: _mapIconButton(
              icon: Icons.arrow_back,
              color: surfaceBg,
              iconColor: textPrimary,
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.maybePop(context);
                }
              },
            ),
          ),

          // ── SOS (sender, active delivery) ─────────────
          if (ride != null && ride.isOwner && _status.isActive)
            Positioned(
              top: topPadding + 100,
              right: 16,
              child: GestureDetector(
                onTap: _handleSOS,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(30)),
                  child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ),

          // ── RIGHT FAB COLUMN ──────────────────────────
          Positioned(
            right: 16,
            bottom: bottomPadding + 132,
            child: Column(
              children: [
                _mapIconButton(icon: Icons.my_location_outlined, color: surfaceBg, iconColor: textPrimary, onTap: _recenterMap),
                if (ride != null) ...[
                  const SizedBox(height: 12),
                  _mapIconButton(
                    icon: _showDeliveryCard ? Icons.info : Icons.info_outline,
                    color: surfaceBg,
                    iconColor: _showDeliveryCard ? const Color(0xFF1E88E5) : textPrimary,
                    onTap: _toggleDeliveryCard,
                  ),
                ],
                if (Session.instance.isLoggedIn) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDelivery())),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF298341),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── FLOATING DELIVERY CARD ────────────────────
          if (ride != null && _showDeliveryCard)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).size.height * 0.30,
              child: SlideTransition(
                position: _cardSlideAnimation,
                child: FadeTransition(
                  opacity: _cardAnimController,
                  child: _buildDeliveryCard(
                    ride,
                    isDark: isDark,
                    surfaceBg: surfaceBg,
                    chipBg: chipBg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    iconMuted: iconMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Delivery Card ─────────────────────────────────────

  Widget _buildDeliveryCard(
    RideModel ride, {
    required bool isDark,
    required Color surfaceBg,
    required Color chipBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color iconMuted,
  }) {
    final rider = ride.rider;
    final showCode = ride.isOwner && ride.deliveryCode != null && _status.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.5 : 0.15), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status chip + track id + dismiss ───────────
          Row(
            children: [
              _statusChip(_status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ride.orderId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: .5)),
              ),
              GestureDetector(onTap: _dismissCard, child: Icon(Icons.close, size: 18, color: iconMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_headline(ride), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text(ride.route.isNotEmpty ? ride.route : ride.dropoffAddress, style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : null),
          const SizedBox(height: 14),

          // ── Rider row ─────────────────────────────────
          if (rider == null)
            Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF298341))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _status.isFinished ? 'No rider assigned' : 'Matching you with the nearest rider…',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
              _cardActionIcon(Icons.share_outlined, iconMuted, _handleShare),
            ])
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: rider.photoUrl.isNotEmpty ? NetworkImage(rider.photoUrl) : null,
                  backgroundColor: const Color(0xFF298341).withOpacity(0.15),
                  child: rider.photoUrl.isEmpty
                      ? Text(rider.name.isNotEmpty ? rider.name[0] : '?', style: const TextStyle(color: Color(0xFF298341), fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            rider.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: TextDecoration.underline, color: textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: Colors.amber, size: 13),
                        const SizedBox(width: 2),
                        Text(rider.rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: textSecondary)),
                      ]),
                      if (rider.plate.isNotEmpty) Text(rider.plate, style: TextStyle(fontSize: 11, color: textSecondary, letterSpacing: .5)),
                    ],
                  ),
                ),
                if (ride.isOwner) ...[
                  _cardActionIcon(Icons.call_outlined, iconMuted, _handleCall),
                  const SizedBox(width: 12),
                  _cardActionIcon(Icons.chat_bubble_outline, iconMuted, _handleChat),
                  const SizedBox(width: 12),
                ],
                _cardActionIcon(Icons.share_outlined, iconMuted, _handleShare),
              ],
            ),

          // ── Handover codes (sender only) ──────────────
          if (ride.isOwner && ride.pickupCode != null && (_status == RideStatus.pending || _status == RideStatus.matched)) ...[
            const SizedBox(height: 14),
            _codeRow('Pickup code — give to rider', ride.pickupCode!, textPrimary, textSecondary, isDark),
          ],
          if (showCode) ...[
            const SizedBox(height: 10),
            _codeRow('Recipient’s delivery code', ride.deliveryCode!, textPrimary, textSecondary, isDark,
                action: TextButton(onPressed: _regenerateCode, child: const Text('Resend', style: TextStyle(color: Color(0xFF298341))))),
          ],

          // ── CTA buttons ───────────────────────────────
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _showTimeline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF298341),
                  side: const BorderSide(color: Color(0xFF298341)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View delivery timeline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
            if (ride.isOwner && ride.canCancel && (_status == RideStatus.pending || _status == RideStatus.matched)) ...[
              const SizedBox(width: 10),
              TextButton(onPressed: _cancelOrder, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Cancel')),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _codeRow(String label, String code, Color textPrimary, Color textSecondary, bool isDark, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E3238) : const Color(0xFFEEF1F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary))),
        Text(code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4, color: textPrimary)),
        if (action != null) action,
      ]),
    );
  }

  Widget _statusChip(RideStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status.label, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cardActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Icon(icon, color: color, size: 20));
  }

  Widget _mapIconButton({
    required IconData icon,
    Color color = Colors.white,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
