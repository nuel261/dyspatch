import 'package:dyspatch_rider/Features/Home/widget/ride_tabs.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Track/track_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/delivery_card.dart';
import 'package:dyspatch_rider/Features/Home/Screen/notification_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/view/scan_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/delivered_order_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/Features/Home/model/delivery_model.dart';
import 'package:dyspatch_rider/Features/Home/widget/cancelled_order_card.dart';
import 'package:dyspatch_rider/Features/Home/model/order_phase.dart';
import 'dart:async';

import 'package:dyspatch_rider/Features/Home/widget/pulsating_dot.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

class HomeContent extends StatefulWidget {
  /// "Find New Orders" on a cancelled Recent card: open Activity's New tab.
  final VoidCallback? onFindNewOrders;

  const HomeContent({super.key, this.onFindNewOrders});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with WidgetsBindingObserver {
  bool _isOnline = true;

  // Drives the "Access to location required" banner at the top of the
  // screen. True when location services are off OR the app lacks
  // location permission.
  bool _locationUnavailable = false;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  final TextEditingController _searchController = TextEditingController();

  // CHANGED: no longer `static const`. These now need to mutate at
  // runtime (Picked-up -> In Transit -> Delivered moves an order out of
  // _activeOrders and into _recentOrders), so they're plain mutable
  // instance fields seeded once in initState.
  late List<DeliveryModel> _activeOrders;
  late List<_RecentOrder> _recentOrders;
  final ScrollController _scrollController = ScrollController();

  static const List<DeliveryModel> _initialActiveOrders = [
    DeliveryModel(
      route: 'Ring Rd → Textile Mill Rd',
      status: 'Heading to Pickup',
      statusColor: Color(0xFFFFCC00), // amber/yellow
      orderId: '#BN4821',
      pickupLocation: 'Benin Agro Mart',
      eta: 'ETA - 12:41pm',
      items: '3 Items',
      amount: '₦ 4,200',
      trackId: 'BN-TRK-2402-8F7K3Q',
      progress: 0.10,
      progressLabel: "You're on your way to pickup",
      actionLabel: 'Confirm Pickup',
      actionColor: Color(0xFFFFCC00),
    ),
    DeliveryModel(
      route: 'Sapele Rd → New Benin Market',
      status: 'At Pickup',
      statusColor: Color(0xFFF2800A), // orange
      orderId: '#BN4835',
      pickupLocation: 'New Benin Market',
      eta: 'ETA - 1:05pm',
      items: '5 Items',
      amount: '₦ 6,750',
      trackId: 'BN-TRK-2402-3P9L2R',
      progress: 0.30,
      progressLabel: 'Verify package before confirming',
      actionLabel: 'Confirm Pickup',
      actionColor: Color(0xFFF2800A),
    ),
    DeliveryModel(
      route: 'Airport Rd → GRA',
      status: 'Picked-up',
      statusColor: Color(0xFF9C27B0), // purple
      orderId: '#BN4849',
      pickupLocation: 'GRA Pharmacy',
      eta: 'ETA - 1:30pm',
      items: '1 Item',
      amount: '₦ 2,100',
      trackId: 'BN-TRK-2402-6D4M8T',
      progress: 0.50,
      progressLabel:
          "Congratulations! Now start your journey to customer's Drop-off",
      // CHANGED: Picked-up now surfaces the "Mark as In Transit" action
      // immediately, matching the design — it no longer sits empty.
      actionLabel: 'Mark as In Transit',
      actionColor: Color(0xFF9C27B0), // violet
    ),
    DeliveryModel(
      route: 'Upper Sakponba → Uselu Market',
      status: 'In Transit',
      statusColor: Color(0xFFFFCC00),
      orderId: '#BN4862',
      pickupLocation: 'Uselu Market',
      eta: 'ETA - 1:50pm',
      items: '4 Items',
      amount: '₦ 3,900',
      trackId: 'BN-TRK-2402-9K2W7H',
      progress: 0.15,
      progressLabel: "You're on your way to pickup",
      actionLabel: 'Confirm Pickup',
      actionColor: Color(0xFFFFCC00),
    ),
    DeliveryModel(
      route: 'Ekiosa St → Oliha Market',
      status: 'Arrived',
      statusColor: Color(0xFFF2800A),
      orderId: '#BN4877',
      pickupLocation: 'Oliha Market',
      eta: 'ETA - 2:10pm',
      items: '2 Items',
      amount: '₦ 5,300',
      trackId: 'BN-TRK-2402-4L8X1B',
      progress: 0.35,
      progressLabel: 'Verify package before confirming',
      actionLabel: 'Confirm Pickup',
      actionColor: Color(0xFFF2800A),
    ),
    DeliveryModel(
      route: 'Siluko Rd → Ugbowo',
      status: 'Picked-up',
      statusColor: Color(0xFF9C27B0),
      orderId: '#BN4891',
      pickupLocation: 'Ugbowo Shopping Complex',
      eta: 'ETA - 2:25pm',
      items: '6 Items',
      amount: '₦ 8,150',
      trackId: 'BN-TRK-2402-1R5N9Z',
      progress: 0.55,
      progressLabel:
          "Congratulations! Now start your journey to customer's Drop-off",
      actionLabel: 'Mark as In Transit',
      actionColor: Color(0xFFB4043),
    ),
    DeliveryModel(
      route: 'Lagos St → Ikpoba Hill',
      status: 'Heading to Pickup',
      statusColor: Color(0xFFFFCC00),
      orderId: '#BN4904',
      pickupLocation: 'Ikpoba Hill Store',
      eta: 'ETA - 2:45pm',
      items: '1 Item',
      amount: '₦ 1,600',
      trackId: 'BN-TRK-2402-7T3Y4C',
      progress: 0.05,
      progressLabel: "You're on your way to pickup",
      actionLabel: 'Confirm Pickup',
      actionColor: Color(0xFFFFCC00),
    ),
  ];

  static DeliveryModel _delivered(String orderId, String trackId) =>
      DeliveryModel(
        route: 'Ring Rd → Textile Mill Rd',
        status: 'Delivered',
        statusColor: const Color(0xFF298341),
        orderId: orderId,
        pickupLocation: 'Benin Agro Mart',
        eta: 'ETA - 12:41pm',
        items: '3 items',
        amount: '₦ 4,200',
        trackId: trackId,
        progress: 1.0,
        progressLabel: 'Delivered successfully!',
        actionLabel: '',
        actionColor: const Color(0xFF298341),
        isCompleted: true,
      );

  // Sample Recent Orders, one per Recent-card design: delivered cards and
  // each cancelled variant (rider cancelled, sender cancelled with
  // compensation, late, fraud).
  static final List<_RecentOrder> _initialRecentOrders = [
    _RecentOrder.delivered(_delivered('#BN4802', 'BN-TRK-2401-7A2K1M')),
    _RecentOrder.delivered(_delivered('#BN4798', 'BN-TRK-2401-5C9H2D')),
    const _RecentOrder.cancelled(
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4795',
        trackId: 'BN-TRK-2401-2F6Q8V',
        deliveryPhase: 'Heading to Pickup',
        cancelledDate: 'Today: 11:20am',
        note: 'You cancelled this order!',
        reason: 'Reason: Vehicle issue',
      ),
    ),
    const _RecentOrder.cancelled(
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4791',
        trackId: 'BN-TRK-2401-8M3T5K',
        deliveryPhase: 'Heading to Pickup',
        cancelledDate: 'Today: 10:58am',
        compensation: '₦ 500',
        reason:
            'So sorry for the stress, order was cancelled by sender on your '
            'way to the pickup',
      ),
    ),
    const _RecentOrder.cancelled(
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4787',
        trackId: 'BN-TRK-2401-4W7N1P',
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 10:31am',
        compensation: '₦ 1,000',
        reason:
            'So sorry for the stress, order was cancelled by sender during '
            'delivery. Return package back!',
        returnToSender: true,
      ),
    ),
    _RecentOrder.delivered(_delivered('#BN4783', 'BN-TRK-2401-9B4E6J')),
    const _RecentOrder.cancelled(
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4779',
        trackId: 'BN-TRK-2401-6R2Y9L',
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 9:47am',
        note: 'System suspects fraud or malicious activity',
        reason:
            'Order was cancelled during delivery due to fraud detection. '
            'Return package back!',
        returnToSender: true,
      ),
    ),
    const _RecentOrder.cancelled(
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4775',
        trackId: 'BN-TRK-2401-3H8U4S',
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 9:15am',
        note: 'You exceeded the delivery time',
        reason: 'Order was cancelled. Delivery is 90mins late',
      ),
    ),
    _RecentOrder.delivered(_delivered('#BN4771', 'BN-TRK-2401-1K5Z7G')),
    _RecentOrder.delivered(_delivered('#BN4766', 'BN-TRK-2401-7P3A2X')),
    _RecentOrder.delivered(_delivered('#BN4760', 'BN-TRK-2401-5D1F8M')),
  ];

  // TODO: the API should return each delivered order's real timeline.
  static const List<TimelineEvent> _sampleTimeline = [
    TimelineEvent(label: 'Created', time: '11:50am'),
    TimelineEvent(label: 'Rider accepted', time: '11:55am'),
    TimelineEvent(label: 'At Pickup', time: '11:59am'),
    TimelineEvent(label: 'Picked-up', time: '12:04pm'),
    TimelineEvent(label: 'In-transit', time: '12:05pm'),
    TimelineEvent(label: 'Arrived', time: '12:41pm'),
    TimelineEvent(label: 'Delivered', time: '12:45pm'),
  ];

  // Fleet owners see their active orders per ride (bike). Dummy
  // assignment by trackId until the backend sends each order's ride.
  static const Map<String, int> _fleetRideOf = {
    'BN-TRK-2402-6D4M8T': 1, // Picked-up
    'BN-TRK-2402-4L8X1B': 1, // Arrived
    'BN-TRK-2402-8F7K3Q': 2, // Heading to Pickup
    'BN-TRK-2402-1R5N9Z': 2, // Picked-up
    'BN-TRK-2402-9K2W7H': 3, // In Transit
    'BN-TRK-2402-3P9L2R': 4, // At Pickup
    'BN-TRK-2402-7T3Y4C': 5, // Heading to Pickup
    // Recent orders.
    'BN-TRK-2401-7A2K1M': 1,
    'BN-TRK-2401-5C9H2D': 1,
    'BN-TRK-2401-2F6Q8V': 1,
    'BN-TRK-2401-8M3T5K': 2,
    'BN-TRK-2401-4W7N1P': 2,
    'BN-TRK-2401-9B4E6J': 2,
    'BN-TRK-2401-6R2Y9L': 3,
    'BN-TRK-2401-3H8U4S': 3,
    'BN-TRK-2401-1K5Z7G': 3,
    'BN-TRK-2401-7P3A2X': 4,
    'BN-TRK-2401-5D1F8M': 5,
  };
  int _selectedRide = 1;

  static const int _collapsedActiveCount = 3;
  bool _showAllActive = false;

  static const int _collapsedRecentCount = 3;
  bool _showAllRecent = false;

  @override
  void initState() {
    super.initState();
    // Normalise the sample data to the shared phase table so labels,
    // colours and progress match what the CTAs move between.
    _activeOrders = _initialActiveOrders.map(_applyPhase).toList();
    _recentOrders = List<_RecentOrder>.from(_initialRecentOrders);
    // Rebuild on every keystroke so the clear (x) button shows/hides and
    // the lists re-filter live, matching the app-side search treatment.
    _searchController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addObserver(this);
    _checkLocationAccess();
    // React live when the rider toggles location from the quick settings
    // panel without leaving the app.
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
      (_) => _checkLocationAccess(),
      onError: (_) {},
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the rider comes back from system settings.
    if (state == AppLifecycleState.resumed) _checkLocationAccess();
  }

  Future<void> _checkLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final hasPermission =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!mounted) return;
    setState(() => _locationUnavailable = !serviceEnabled || !hasPermission);
  }

  Future<void> _requestLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return; // re-checked on resume / via the service status stream
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    await _checkLocationAccess();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  bool _matchesQuery(DeliveryModel d) {
    if (_query.isEmpty) return true;
    return d.orderId.toLowerCase().contains(_query) ||
        d.trackId.toLowerCase().contains(_query);
  }

  // Search looks across every ride; otherwise a fleet owner sees only the
  // selected ride's orders.
  bool _inSelectedRide(String trackId) =>
      !RiderSession.isFleetOwner ||
      _isSearching ||
      _fleetRideOf[trackId] == _selectedRide;

  List<DeliveryModel> get _filteredActiveOrders => _activeOrders
      .where((d) => _matchesQuery(d) && _inSelectedRide(d.trackId))
      .toList();

  bool _matchesRecent(_RecentOrder r) =>
      _query.isEmpty ||
      r.orderId.toLowerCase().contains(_query) ||
      r.trackId.toLowerCase().contains(_query);

  List<_RecentOrder> get _filteredRecentOrders => _recentOrders
      .where((r) => _matchesRecent(r) && _inSelectedRide(r.trackId))
      .toList();

  bool get _isSearching => _query.isNotEmpty;

  bool get _noSearchResults =>
      _isSearching &&
      _filteredActiveOrders.isEmpty &&
      _filteredRecentOrders.isEmpty;

  // NEW: while searching, active and recent matches are shown together
  // as one flat "Results" list instead of two separate sections —
  // active orders first, then recent/delivered ones.
  int get _searchResultCount =>
      _filteredActiveOrders.length + _filteredRecentOrders.length;

  // Recent Orders is its own independent section outside of search —
  // always shown (with a placeholder if empty) regardless of
  // active-order count or online status. During a search it's folded
  // into _searchResults instead, so this section is hidden entirely.
  bool get _showRecentSection => !_isSearching;

  bool get _hasMoreActiveToShow =>
      !_isSearching && _filteredActiveOrders.length > _collapsedActiveCount;

  List<DeliveryModel> get _visibleActiveOrders {
    final filtered = _filteredActiveOrders;
    if (_isSearching || _showAllActive) return filtered;
    return filtered.take(_collapsedActiveCount).toList();
  }

  bool get _hasMoreRecentToShow =>
      !_isSearching && _filteredRecentOrders.length > _collapsedRecentCount;

  List<_RecentOrder> get _visibleRecentOrders {
    final filtered = _filteredRecentOrders;
    if (_isSearching || _showAllRecent) return filtered;
    return filtered.take(_collapsedRecentCount).toList();
  }

  // NEW: drives the Picked-up -> In Transit -> Delivered flow.
  // Confirm Pickup (Heading to Pickup / At Pickup) is left as-is for now
  // since that flow wasn't specified — only the In-Transit/Delivered
  // transition is wired up here.
  //
  // NOTE: this calls `delivery.copyWith(...)`. If DeliveryModel doesn't
  // already have a copyWith method, add one — see the snippet in my
  // reply below.
  static DeliveryModel _applyPhase(DeliveryModel d, [OrderPhase? phase]) {
    final p = phase ?? OrderPhase.of(d.status);
    if (p == null) return d;
    return d.copyWith(
      status: p.status,
      statusColor: p.color,
      progress: p.progress,
      progressLabel: p.progressLabel,
      actionLabel: p.actionLabel,
      actionColor: p.color,
      isCompleted: p.isFinal,
    );
  }

  // Primary CTA: move the order one phase along
  // (Heading to Pickup → At Pickup → Picked-up → In Transit → Delivered).
  // Delivered orders leave Active and go to the top of Recent.
  void _handleCardAction(DeliveryModel delivery) {
    final index = _activeOrders.indexWhere(
      (d) => d.trackId == delivery.trackId,
    );
    if (index == -1) return;
    final current = _activeOrders[index];
    final next = OrderPhase.nextAfter(current.status);
    if (next == null) return;

    // TODO: tell the API about the status change once it exists.
    setState(() {
      final updated = _applyPhase(current, next);
      if (next.isFinal) {
        _activeOrders.removeAt(index);
        _recentOrders.insert(
          0,
          _RecentOrder.delivered(updated.copyWith(eta: 'Delivered just now')),
        );
      } else {
        _activeOrders[index] = updated;
      }
    });
  }

  void _toggleOnlineStatus() {
    // Rider can't go offline while there are active (in-progress) orders —
    // going online is always allowed, only the offline switch is guarded.
    if (_isOnline && _activeOrders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You can't go offline while you have active orders. "
            "Complete or hand them off first.",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }
    setState(() {
      _isOnline = !_isOnline;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold here — HomeContent is used as a tab body inside
    // HomeScreen's own Scaffold/Stack. Nesting a second Scaffold inside
    // an unbounded Stack starves it of proper height, which is why
    // everything used to collapse toward the top of the screen. We use
    // a plain Stack instead so the map FAB can still float in a fixed
    // position over the scrollable content, without owning its own
    // Scaffold/FAB slot.
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location access banner ──
                  if (_locationUnavailable)
                    _buildLocationBanner(context)
                  else
                    const SizedBox(height: 16),

                  // ── Top Bar ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Hello Dayo ',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  height: 28 / 20,
                                  letterSpacing: 0.0,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.inversePrimary,
                                ),
                              ),
                              Text(
                                '👋',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 28 / 20,
                                  letterSpacing: 0.0,
                                  fontFamily: 'Montserrat',
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.inversePrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _toggleOnlineStatus,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isOnline
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFDECEA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PulsatingDot(
                                    color: _isOnline
                                        ? const Color(0xFF298341)
                                        : const Color(0xFFD32F2F),
                                    isActive: _isOnline,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 20 / 13,
                                      letterSpacing: 0.0,
                                      color: _isOnline
                                          ? const Color(0xFF298341)
                                          : const Color(0xFFD32F2F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_isOnline) ...[
                            const SizedBox(height: 6),
                            Text(
                              '↑ Tap on the offline status pill to come back online',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Search / Track ID Bar ──
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        SvgPicture.asset(
                          'assets/images/ph_magnifying-glass.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF5f6368),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat',
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search by Order ID or Track ID',

                              hintStyle: TextStyle(
                                color: Color(0xFF8A8F98),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Montserrat',
                                height: 16 / 12,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                        if (_searchController.text.trim().isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF8A8F98),
                                size: 18,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () async {
                              final scannedValue = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ScanScreen(),
                                ),
                              );
                              if (scannedValue != null &&
                                  scannedValue.isNotEmpty) {
                                _searchController.text = scannedValue;
                                // Move cursor to the end so it doesn't sit at position 0
                                _searchController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _searchController.text.length,
                                      ),
                                    );
                              }
                            },
                            child: Icon(
                              Icons.qr_code_scanner,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Search results: nothing matched ──
                  if (_noSearchResults)
                    _buildNoResultsState(context)
                  else if (_isSearching) ...[
                    // ── Search results — active + recent merged into a
                    // single flat list while searching. ──
                    Text(
                      'Results ($_searchResultCount)',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 26 / 18,
                        letterSpacing: 0.0,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResultCount,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        // Active matches first, then recent ones.
                        final active = _filteredActiveOrders;
                        if (index < active.length) {
                          final order = active[index];
                          return DeliveryCard(
                            key: ValueKey('search-${order.trackId}'),
                            delivery: order,
                            onAction: () => _handleCardAction(order),
                          );
                        }
                        return _buildRecentCard(
                          _filteredRecentOrders[index - active.length],
                        );
                      },
                    ),
                  ] else ...[
                    // ── Active Orders ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Orders',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 26 / 18,
                            letterSpacing: 0.0,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        if (_hasMoreActiveToShow)
                          GestureDetector(
                            onTap: () => setState(
                              () => _showAllActive = !_showAllActive,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF298341).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _showAllActive ? 'Show less' : 'See all',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 20 / 14,
                                  letterSpacing: 0.0,
                                  color: Color(0xFF298341),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (RiderSession.isFleetOwner) ...[
                      RideTabs(
                        selected: _selectedRide - 1,
                        onSelected: (i) => setState(() {
                          _selectedRide = i + 1;
                          _showAllActive = false;
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_filteredActiveOrders.isEmpty)
                      _buildEmptyState(context)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _visibleActiveOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _visibleActiveOrders[index];
                          return DeliveryCard(
                            key: ValueKey(order.trackId),
                            delivery: order,
                            initiallyExpanded: index == 0,
                            onAction: () => _handleCardAction(order),
                          );
                        },
                      ),

                    // ── Recent Orders — always-present, independent
                    // section, regardless of active-order count or
                    // online status outside of search. ──
                    if (_showRecentSection) ...[
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Orders',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 26 / 18,
                              letterSpacing: 0.0,
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                            ),
                          ),
                          if (_hasMoreRecentToShow)
                            GestureDetector(
                              onTap: () => setState(
                                () => _showAllRecent = !_showAllRecent,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF298341,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _showAllRecent ? 'Show less' : 'See all',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 20 / 14,
                                    letterSpacing: 0.0,
                                    color: Color(0xFF298341),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_filteredRecentOrders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Your recent orders will appear here',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleRecentOrders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildRecentCard(
                              _visibleRecentOrders[index],
                            );
                          },
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // ── Map FAB — positioned within HomeContent's own Stack instead
          // of a nested Scaffold's floatingActionButton slot. Sits above
          // HomeScreen's floating nav bar, offset further up than the
          // create-delivery FAB in HomeScreen so they don't collide.
        ],
      ),
    );
  }

  Widget _buildRecentCard(_RecentOrder recent) {
    final cancelled = recent.cancelled;
    if (cancelled != null) {
      return CancelledOrderCard(
        key: ValueKey('recent-${recent.trackId}'),
        order: cancelled,
        onFindNewOrders: widget.onFindNewOrders ?? () {},
        // Already on Home: just scroll back to the top.
        onGoHome: () => _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
    final delivered = recent.delivered!;
    return DeliveryCard(
      key: ValueKey('recent-${recent.trackId}'),
      delivery: delivered,
      onViewTimeline: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveredOrderDetailsScreen(
            order: ActivityOrder(
              route: delivered.route,
              pickupLocation: delivered.pickupLocation,
              amount: delivered.amount,
              orderId: delivered.orderId,
              eta: delivered.eta,
              items: delivered.items,
              statusLabel: 'Delivered',
              trackId: delivered.trackId,
              timeline: _sampleTimeline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner(BuildContext context) {
    final color = Theme.of(context).colorScheme.inversePrimary;
    return GestureDetector(
      onTap: _requestLocationAccess,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        child: Center(
          child: Text(
            'Access to location required',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 20 / 13,
              color: color,
              decoration: TextDecoration.underline,
              decorationColor: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'No matching orders',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "We couldn't find an order matching that Order ID or Track ID.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Theme.of(context).colorScheme.inversePrimary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: SvgPicture.asset('assets/images/Characters.svg', height: 200),
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            _isOnline ? 'No active orders yet' : 'No orders yet',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _isOnline
                ? 'Go to your activity page and start accepting\norders nearby.'
                : "You're currently offline. Come back online\nand start receiving orders nearby.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Theme.of(context).colorScheme.inversePrimary,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!_isOnline)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleOnlineStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF298341),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go online',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF3F1),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'View earnings',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF298341),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A Recent Orders entry: a delivered order or a cancelled one.
class _RecentOrder {
  final DeliveryModel? delivered;
  final ActivityOrder? cancelled;

  const _RecentOrder.delivered(DeliveryModel this.delivered)
    : cancelled = null;
  const _RecentOrder.cancelled(ActivityOrder this.cancelled)
    : delivered = null;

  String get orderId => delivered?.orderId ?? cancelled!.orderId;
  String get trackId => delivered?.trackId ?? cancelled!.trackId ?? '';
}
