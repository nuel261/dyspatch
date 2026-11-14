import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/order_view.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/services/order_actions.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
import 'package:dyspatch_rider/core/ui/format.dart' show parseTime;
import 'package:dyspatch_rider/core/ui/map_tiles.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:dyspatch_rider/Features/Home/Screen/activity/activity_screen.dart';
import 'package:dyspatch_rider/Features/Home/model/order_phase.dart';
import 'package:dyspatch_rider/Features/Home/model/ride_model.dart';
import 'package:dyspatch_rider/Features/Home/model/rider_model.dart';
import 'package:dyspatch_rider/Features/Home/services/tracking_services.dart';
import 'package:dyspatch_rider/Features/Home/utils/polyline_decoder.dart';
import 'package:dyspatch_rider/Features/Home/widget/app_popup.dart';
import 'package:dyspatch_rider/Features/Home/widget/issue_followup_overlay.dart';
import 'package:dyspatch_rider/Features/Home/widget/report_issue_sheet.dart';
import 'package:dyspatch_rider/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

class TrackScreen extends StatefulWidget {
  final VoidCallback? onBack;

  /// When set (e.g. "#BN4821" from an active order's Navigate button), the
  /// screen opens already tracking that order instead of waiting for the
  /// rider to type an ID.
  final String? initialOrderId;

  const TrackScreen({super.key, this.onBack, this.initialOrderId});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────
  final MapController _mapController = MapController();
  final Location _location = Location();
  final TextEditingController _orderIdController = TextEditingController();
  StreamSubscription<LocationData>? _locationSub;

  // The live backend order shown on the map (raw JSON).
  Map<String, dynamic>? _order;

  // ── Location State ────────────────────────────────────
  bool _isLocating = true;
  LatLng? _currentLocation;

  // ── Ride State ────────────────────────────────────────
  bool _isSearching = false;
  String? _searchError;
  RideModel? _ride;
  String? _merchantName; // pickup-phase display name
  LatLng? _riderLocation;
  List<LatLng> _route = [];
  int _etaMinutes = 0;
  RideStatus _status = RideStatus.matched;
  DateTime? _arrivedAt;
  DateTime? _deliveredAt;

  // ── Card visibility ───────────────────────────────────
  bool _showDeliveryCard = false;

  // ── Polling / debounce ────────────────────────────────
  Timer? _pollingTimer;
  Timer? _debounceTimer;

  // ── Animation ─────────────────────────────────────────
  late AnimationController _cardAnimController;
  late Animation<Offset> _cardSlideAnimation;

  List<Map<String, String>> get _timelineSteps => _order == null
      ? const []
      : OrderView.timeline(_order!).map((e) => {'label': e.label, 'time': e.time}).toList();

  // ── Statuses that belong to the "pickup" phase (merchant side) ──
  @override
  void initState() {
    super.initState();
    _initLocation();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _cardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut),
        );

    final initialId = (widget.initialOrderId ?? RiderState.instance.activeOrder?['track_id']?.toString())
        ?.replaceAll('#', '')
        .trim();
    if (initialId != null && initialId.isNotEmpty) {
      _orderIdController.text = initialId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchOrder();
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _debounceTimer?.cancel();
    _followupTimer?.cancel();
    _locationSub?.cancel();
    _orderIdController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────

  Future<void> _initLocation() async {
    if (!await _checkLocationPermission()) {
      setState(() => _isLocating = false);
      return;
    }
    _locationSub = _location.onLocationChanged.listen((
      LocationData locationData,
    ) {
      if (locationData.latitude != null && locationData.longitude != null) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
            _isLocating = false;
          });
        }
      }
    });
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

  void _recenterMap() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17);
    } else {
      _showSnackbar('Location not available');
    }
  }

  // Fits the map to whatever points are on screen (rider, dropoff,
  // current location) instead of hard-jumping to a fixed zoom.
  void _fitMapToRide() {
    if (_ride == null) return;

    final points = <LatLng>[
      _ride!.dropoffLocation,
      if (_currentLocation != null) _currentLocation!,
      if (_riderLocation != null) _riderLocation!,
    ];

    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 16);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 220, 60, 260),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchError = null);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _searchOrder();
    });
  }

  Future<void> _searchOrder({bool unfocus = false}) async {
    // Normalized once, uppercase, reused everywhere below — avoids
    // case-mismatch causing false "Order not found".
    final orderId = _orderIdController.text.trim().toUpperCase();
    if (orderId.isEmpty) return;

    if (unfocus) {
      FocusScope.of(context).unfocus();
    }
    _pollingTimer?.cancel();

    setState(() {
      _isSearching = true;
      _searchError = null;
      _ride = null;
      _merchantName = null;
      _route = [];
      _riderLocation = null;
      _showDeliveryCard = false;
      _arrivedAt = null;
      _deliveredAt = null;
    });

    try {
      final order = await _findOrder(orderId);
      if (order == null) throw Exception('Not found');
      final ride = _rideFrom(order);
      _order = order;

      _arrivedAt = parseTime(order['arrived_at']);
      _deliveredAt = parseTime(order['delivered_at']);

      setState(() {
        _ride = ride;
        _merchantName = _contactName(order);
        _etaMinutes = ride.etaMinutes;
        _status = ride.status;
        _isSearching = false;
        _showDeliveryCard = true;
      });

      _cardAnimController.forward(from: 0);
      await _fetchRiderLocationAndRoute();
      _fitMapToRide();
      _startPolling();
    } catch (e) {
      setState(() {
        _searchError = 'Order not found. Check the ID and try again.';
        _isSearching = false;
      });
    }
  }

  /// Finds one of this rider's orders by track id, order number or id.
  Future<Map<String, dynamic>?> _findOrder(String q) async {
    bool match(Map<String, dynamic> o) {
      final keys = [o['track_id'], o['order_no'], o['id']].map((v) => (v ?? '').toString().toUpperCase().replaceAll('#', ''));
      return keys.contains(q.replaceAll('#', ''));
    }

    final active = RiderState.instance.activeOrder;
    if (active != null && match(active)) return RiderApi.order((active['id'] as num).toInt());
    final all = await RiderApi.orders();
    for (final o in all) {
      if (match(o)) return o;
    }
    return null;
  }

  /// Where the rider is heading now: pickup before collecting, then drop-off.
  bool get _toPickup => (_order?['status'] as String? ?? 'matched') == 'matched';

  RideModel _rideFrom(Map<String, dynamic> o) {
    final status = o['status'] as String? ?? 'matched';
    final target = Map<String, dynamic>.from((status == 'matched' ? o['pickup'] : o['dropoff']) as Map? ?? {});
    final km = (o['distance_km'] as num?)?.toDouble() ?? 5;
    return RideModel(
      orderId: OrderView.orderNo(o),
      status: RideStatus.fromString(status),
      dropoffLocation: LatLng((target['lat'] as num?)?.toDouble() ?? 0, (target['lng'] as num?)?.toDouble() ?? 0),
      dropoffAddress: (target['address'] as String?) ?? '',
      etaMinutes: (km * 3).round().clamp(1, 999),
      rider: RiderModel(
        name: _contactName(o),
        photoUrl: '',
        rating: 0,
        plate: '',
        phone: ((status == 'matched' ? o['sender_phone'] : o['recipient_phone']) as String?) ?? '',
      ),
    );
  }

  String _contactName(Map<String, dynamic> o) {
    final pickup = (o['status'] as String? ?? 'matched') == 'matched';
    final n = ((pickup ? o['sender_name'] : o['recipient_name']) as String?)?.trim() ?? '';
    return n.isEmpty ? (pickup ? 'Sender' : 'Recipient') : '${pickup ? 'Pickup' : 'Drop-off'} · $n';
  }

  /// Runs the next backend step and refreshes the map for the new phase.
  Future<void> _advance() async {
    if (_order == null) return;
    final updated = await OrderActions.advance(context, _order!);
    if (updated == null || !mounted) return;
    setState(() {
      _order = updated;
      _ride = _rideFrom(updated);
      _status = _ride!.status;
      _merchantName = _contactName(updated);
      _arrivedAt = parseTime(updated['arrived_at']);
      _deliveredAt = parseTime(updated['delivered_at']);
    });
    if (_status == RideStatus.delivered) {
      _pollingTimer?.cancel();
    } else {
      await _fetchRiderLocationAndRoute();
      _fitMapToRide();
    }
  }

  // ── Polling ───────────────────────────────────────────
  Future<void> _fetchRiderLocationAndRoute() async {
    if (_ride == null) return;
    if (_status == RideStatus.arrived || _status == RideStatus.delivered) {
      _pollingTimer?.cancel();
      return;
    }

    // In the rider app "the rider" is this phone: route from here to the
    // pickup (before collecting) or the drop-off.
    final here = _currentLocation;
    if (here == null) return;
    final mockRiderLocation = here;

    // Try OSRM, fall back to straight line
    List<LatLng> route = [mockRiderLocation, _ride!.dropoffLocation];
    try {
      final geometry = await TrackingService.fetchRouteGeometry(
        mockRiderLocation,
        _ride!.dropoffLocation,
      ).timeout(const Duration(seconds: 5));
      if (geometry != null) {
        final decoded = decodePolyline(geometry);
        if (decoded.isNotEmpty) route = decoded;
      }
    } catch (e) {
      debugPrint('Route fetch failed, using straight line: $e');
    }

    if (!mounted) return;
    setState(() {
      _riderLocation = mockRiderLocation;
      _etaMinutes = (const Distance().as(LengthUnit.Kilometer, here, _ride!.dropoffLocation) * 3).round().clamp(1, 999);
      _route = route;
    });
  }

  void _startPolling() {
    if (_status == RideStatus.arrived || _status == RideStatus.delivered) {
      return;
    }
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchRiderLocationAndRoute();
    });
  }

  // ── Status transition dialogs ─────────────────────────

  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          content,
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // ── Confirm Pickup (matched/otpVerified → pickedUp) ───
  Future<void> _handleConfirmPickup() => _advance();


  // ── Mark as In Transit (pickedUp → enRoute) ───────────
  Future<void> _handleMarkInTransit() async {
    final confirmed = await _confirmDialog(
      title: 'Mark as In Transit',
      content: 'Start the trip to the drop-off address?',
      confirmLabel: 'Confirm',
      confirmColor: _statusColor(RideStatus.pickedUp),
    );
    if (confirmed) await _advance();
  }


  // ── Mark as Arrived (enRoute → arrived) ───────────────
  Future<void> _handleMarkArrived() async {
    final confirmed = await _confirmDialog(
      title: 'Mark as Arrived',
      content: "Confirm you've reached the drop-off address?",
      confirmLabel: 'Confirm',
      confirmColor: _statusColor(RideStatus.enRoute),
    );
    if (confirmed) await _advance();
  }


  // ── Mark as Delivered (arrived → delivered) ───────────
  Future<void> _handleMarkDelivered() => _advance();


  // ── Timeline sheet ────────────────────────────────────

  void _showTimeline() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
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
                  Icon(
                    Icons.directions_bike,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery timeline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._timelineSteps.map((step) => _timelineRow(step, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineRow(Map<String, String> step, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade400 : Colors.black54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step['label']!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            step['time']!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.black54,
            ),
          ),
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
    final id = (_order?['track_id'] ?? '').toString();
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    _showSnackbar('Track ID copied');
  }

  // ⚠ on the delivery card: pick a reason, or cancel the ride outright.
  Future<void> _handleReportIssue() async {
    final result = await showReportIssueSheet(context);
    if (result == null || !mounted || _ride == null) return;
    if (result.cancelRide) return _handleCancelRide();

    final reason = result.reason!;
    if (reason == IssueReason.emergency) return _handleSOS();
    if (reason == IssueReason.contactSupport) {
      try {
        await RiderApi.sos('Rider needs support on order ${_order?['track_id']}');
        _showSnackbar('Support has been alerted and will reach you shortly.');
      } catch (e) {
        _showSnackbar(errorText(e));
      }
      return;
    }

    if (reason == IssueReason.recipientNotReachable ||
        reason == IssueReason.recipientUnavailable) {
      return _followUp(reason);
    }
    _reportIssue(reason);
  }

  // Set while the rider chose "Wait 5 mins"; asks again when it fires.
  Timer? _followupTimer;

  // Overlay/Issue/followup — give the rider a chance to retry before the
  // issue is reported and they leave the order.
  Future<void> _followUp(IssueReason reason) async {
    final action = await showIssueFollowup(context, title: '${reason.label}?');
    if (!mounted || _ride == null) return;
    switch (action) {
      case FollowupAction.call:
        _handleCall();
      case FollowupAction.wait:
        _followupTimer?.cancel();
        _followupTimer = Timer(const Duration(minutes: 5), () {
          if (mounted) _followUp(reason);
        });
        _showSnackbar("We'll check back with you in 5 mins.");
      case FollowupAction.report:
        _reportIssue(reason);
      case null:
        break;
    }
  }

  Future<void> _reportIssue(IssueReason reason) async {
    _followupTimer?.cancel();
    if (_order == null) return;
    try {
      await RiderApi.reportIssue((_order!['id'] as num).toInt(), reason.label);
      if (mounted) AppPopup.issue(context);
    } catch (e) {
      _showSnackbar(errorText(e));
    }
  }

  Future<void> _handleCancelRide() async {
    final confirmed = await _confirmDialog(
      title: 'Cancel Ride',
      content: 'Cancel this delivery? This may affect your ratings.',
      confirmLabel: 'Cancel Ride',
      confirmColor: Colors.red,
    );
    if (!confirmed || _ride == null) return;

    try {
      final updated = await RiderApi.fail((_order!['id'] as num).toInt(), 'Cancelled by rider');
      RiderState.instance.setActiveOrder(updated);
      _showSnackbar('Ride cancelled.');
      _leave();
    } catch (e) {
      _showSnackbar(errorText(e));
    }
  }

  // Same as the map's back button.
  void _leave() {
    if (!mounted) return;
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSOS() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Emergency SOS',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'This will flag a safety concern to our team immediately. Continue?',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
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
      await RiderApi.sos('Emergency on order ${_order?['track_id'] ?? '-'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS sent. Our team has been alerted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _showSnackbar(errorText(e));
    }
  }

  void _handleCall() => OrderActions.call(context, _order);

  void _handleChat() => OrderActions.message(context, _order);

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Status helpers ────────────────────────────────────

  // Same colours as the order cards (see OrderPhase).
  OrderPhase _phase(RideStatus status) => OrderPhase.of(_statusLabel(status))!;

  Color _statusColor(RideStatus status) => _phase(status).color;

  String _statusLabel(RideStatus status) {
    switch (status) {
      case RideStatus.matched:
      case RideStatus.otpVerified:
        return 'At Pickup';
      case RideStatus.pickedUp:
        return 'Picked-up';
      case RideStatus.enRoute:
        return 'In Transit';
      case RideStatus.arrived:
        return 'Arrived';
      case RideStatus.delivered:
        return 'Delivered';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$min$period';
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ── Theme-aware colors ───────────────────────────────
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final scaffoldBg = isDark
        ? const Color(0xFF0E120F)
        : const Color(0xFFEEF1F4);
    final surfaceBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.black54;
    final iconMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

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
                    initialCenter:
                        _currentLocation ?? const LatLng(6.5244, 3.3792),
                    initialZoom: 14,
                    minZoom: 5,
                    maxZoom: 18,
                  ),
                  children: [
                    tiles(context),
                    CurrentLocationLayer(
                      alignPositionOnUpdate: AlignOnUpdate.once,
                      style: LocationMarkerStyle(
                        marker: const DefaultLocationMarker(
                          child: Icon(Icons.location_pin, color: Colors.white),
                        ),
                        markerSize: const Size(35, 35),
                        markerDirection: MarkerDirection.heading,
                      ),
                    ),
                    if (_riderLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _riderLocation!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E88E5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_ride?.dropoffLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ride!.dropoffLocation,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    osmCredit(),
                    if (_route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 5,
                            color: const Color(0xFF1E88E5),
                            pattern: StrokePattern.dashed(
                              segments: const [12, 8],
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
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF5F6368),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _orderIdController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText:
                                'Input Track ID here to navigate Order easily',
                            hintStyle: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 16 / 12,
                              letterSpacing: 0.0,
                              color: textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _searchOrder(unfocus: true),
                        ),
                      ),
                      _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              onPressed: () => _searchOrder(unfocus: true),
                              icon: SvgPicture.asset(
                                'assets/images/ph_scan.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF5F6368),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
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
              onTap: _leave,
            ),
          ),

          // ── RIGHT FAB COLUMN ──────────────────────────
          Positioned(
            right: 16,
            bottom: bottomPadding + 132,
            child: Column(
              children: [
                // Location — always visible
                _mapIconButton(
                  icon: Icons.my_location_outlined,
                  color: surfaceBg,
                  iconColor: textPrimary,
                  onTap: _recenterMap,
                ),

                // Info — only after ride loaded
                if (_ride != null) ...[
                  const SizedBox(height: 12),
                  _mapIconButton(
                    icon: _showDeliveryCard ? Icons.info : Icons.info_outline,
                    color: surfaceBg,
                    iconColor: _showDeliveryCard
                        ? const Color(0xFF1E88E5)
                        : textPrimary,
                    onTap: _toggleDeliveryCard,
                  ),
                ],

                // + FAB — always visible
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {}, // TODO: wire up later
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF298341),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Icon(Icons.add, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── FLOATING DELIVERY CARD (centered) ─────────
          if (_ride != null && _showDeliveryCard)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).size.height * 0.35,
              child: SlideTransition(
                position: _cardSlideAnimation,
                child: FadeTransition(
                  opacity: _cardAnimController,
                  child: _buildDeliveryCard(
                    _ride!,
                    isDark: isDark,
                    surfaceBg: surfaceBg,
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
    required Color textPrimary,
    required Color textSecondary,
    required Color iconMuted,
  }) {
    final isArrived = _status == RideStatus.arrived;
    final isDelivered = _status == RideStatus.delivered;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status chip + dismiss ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusChip(_status),
              GestureDetector(
                onTap: _dismissCard,
                child: Icon(Icons.cancel_outlined, size: 20, color: iconMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Headline ──────────────────────────────────
          Text(
            isDelivered
                ? 'Parcel marked delivered by ${_formatTime(_deliveredAt!)}'
                : isArrived
                ? 'Arrived at ${_arrivedAt != null ? _formatTime(_arrivedAt!) : "--"}'
                : 'Arriving in $_etaMinutes mins',
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
              letterSpacing: 0.0,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // ── Route ─────────────────────────────────────
          Text(
            ride.dropoffAddress,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 22 / 14,
              letterSpacing: 0.0,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // ── Merchant row + call / chat / report ───────
          _merchantRow(textPrimary, iconMuted),

          // ── CTA button ────────────────────────────────
          if (_status == RideStatus.matched ||
              _status == RideStatus.otpVerified) ...[
            const SizedBox(height: 14),
            _ctaButton(
              label: 'Confirm Pickup',
              color: _statusColor(_status),
              onPressed: _handleConfirmPickup,
            ),
          ] else if (_status == RideStatus.pickedUp) ...[
            const SizedBox(height: 14),
            _ctaButton(
              label: 'Mark as In Transit',
              color: _statusColor(_status),
              onPressed: _handleMarkInTransit,
            ),
          ] else if (_status == RideStatus.enRoute) ...[
            const SizedBox(height: 14),
            _ctaButton(
              label: 'Mark as Arrived',
              color: _statusColor(_status),
              onPressed: _handleMarkArrived,
            ),
          ] else if (isArrived) ...[
            const SizedBox(height: 14),
            _ctaButton(
              label: 'Mark as Delivered',
              color: _statusColor(_status),
              onPressed: _handleMarkDelivered,
            ),
          ] else if (isDelivered) ...[
            const SizedBox(height: 14),
            _ctaButton(
              label: 'View delivery timeline',
              color: _statusColor(_status),
              onPressed: _showTimeline,
            ),
          ],
        ],
      ),
    );
  }

  // ── Merchant row (pickup phase) ────────────────────────
  Widget _merchantRow(Color textPrimary, Color iconMuted) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/ph_user.svg',
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(iconMuted, BlendMode.srcIn),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _merchantName ?? 'Pickup location',
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _cardActionIcon(
          SvgPicture.asset(
            'assets/images/ph_phone-call.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(iconMuted, BlendMode.srcIn),
          ),
          _handleCall,
        ),
        const SizedBox(width: 12),
        _cardActionIcon(
          SvgPicture.asset(
            'assets/images/ph_chat-circle-dots.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(iconMuted, BlendMode.srcIn),
          ),
          _handleChat,
        ),
        const SizedBox(width: 12),
        _cardActionIcon(
          SvgPicture.asset(
            'assets/images/ph_warning.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
          ),
          _handleReportIssue,
        ),
      ],
    );
  }

  // ── Solid CTA button (color/label change per status) ───
  Widget _ctaButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/images/ph_checks.svg',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(RideStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _phase(status).pillColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == RideStatus.delivered)
            Icon(Icons.check, size: 12, color: _phase(status).pillTextColor)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _statusColor(status),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _phase(status).pillTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardActionIcon(Widget icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: icon);
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
