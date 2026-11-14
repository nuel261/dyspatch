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
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/order_view.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/api/session.dart';
import 'package:dyspatch_rider/core/services/order_actions.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
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

  // Drives the "Access to location required" banner at the top of the
  // screen. True when location services are off OR the app lacks
  // location permission.
  bool _locationUnavailable = false;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  final TextEditingController _searchController = TextEditingController();

  // Live data: the active job comes from RiderState (one at a time on the
  // backend), recent orders from GET /rider/orders?status=completed.
  final Map<String, Map<String, dynamic>> _ordersByTrack = {};
  List<_RecentOrder> _recentOrders = [];
  int? _lastActiveId;
  final ScrollController _scrollController = ScrollController();

  bool get _isOnline => RiderState.instance.online;

  List<DeliveryModel> get _activeOrders {
    final o = RiderState.instance.activeOrder;
    if (o == null) return const [];
    _ordersByTrack[(o['track_id'] ?? '').toString()] = o;
    return [OrderView.delivery(o)];
  }

  Future<void> _loadRecent() async {
    try {
      final list = await RiderApi.orders(status: 'completed');
      if (!mounted) return;
      setState(() {
        _recentOrders = list.map((o) {
          _ordersByTrack[(o['track_id'] ?? '').toString()] = o;
          return o['status'] == 'delivered'
              ? _RecentOrder.delivered(OrderView.delivery(o), raw: o)
              : _RecentOrder.cancelled(OrderView.activity(o), raw: o);
        }).toList();
      });
    } catch (_) {/* offline: keep what we have */}
  }

  void _onRiderState() {
    if (!mounted) return;
    final id = RiderState.instance.activeOrderId;
    // A job just finished (delivered/cancelled) → refresh Recent.
    if (_lastActiveId != null && id != _lastActiveId) _loadRecent();
    _lastActiveId = id;
    setState(() {});
  }

  // Fleet support isn't on the backend yet: everything belongs to ride 1.
  int _selectedRide = 1;

  static const int _collapsedActiveCount = 3;
  bool _showAllActive = false;

  static const int _collapsedRecentCount = 3;
  bool _showAllRecent = false;

  @override
  void initState() {
    super.initState();
    _lastActiveId = RiderState.instance.activeOrderId;
    RiderState.instance.addListener(_onRiderState);
    RiderState.instance.refresh();
    _loadRecent();
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
      _selectedRide == 1;

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

  // Primary CTA: move the order one step along on the server
  // (pickup code → in transit → arrived → delivery code).
  Future<void> _handleCardAction(DeliveryModel delivery) async {
    final order = _ordersByTrack[delivery.trackId] ?? RiderState.instance.activeOrder;
    if (order == null) return;
    final updated = await OrderActions.advance(context, order);
    if (updated != null && !OrderView.isActive(updated['status'] as String? ?? '')) _loadRecent();
  }

  Future<void> _toggleOnlineStatus() async {
    final rs = RiderState.instance;
    if (rs.busy) return;
    // Rider can't go offline while there are active (in-progress) orders —
    // going online is always allowed, only the offline switch is guarded.
    if (_isOnline && _activeOrders.isNotEmpty) {
      showSnack(context, "You can't go offline while you have an active order. Complete it first.", error: true);
      return;
    }
    final err = _isOnline ? await rs.goOffline() : await rs.goOnline();
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      _checkLocationAccess();
    }
  }

  @override
  void dispose() {
    RiderState.instance.removeListener(_onRiderState);
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
                                'Hello ${Session.instance.firstName} ',
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
              timeline: recent.raw == null ? const [] : OrderView.timeline(recent.raw!),
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
  final Map<String, dynamic>? raw;

  const _RecentOrder.delivered(DeliveryModel this.delivered, {this.raw})
    : cancelled = null;
  const _RecentOrder.cancelled(ActivityOrder this.cancelled, {this.raw})
    : delivered = null;

  String get orderId => delivered?.orderId ?? cancelled!.orderId;
  String get trackId => delivered?.trackId ?? cancelled!.trackId ?? '';
}
