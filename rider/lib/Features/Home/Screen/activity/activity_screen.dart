import 'package:dyspatch_rider/Features/Home/widget/ride_tabs.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:dyspatch_rider/Features/Home/widget/app_popup.dart';
import 'dart:async'; // needed for the countdown Timer

import 'package:dyspatch_rider/Features/Home/Screen/activity/activity_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/delivered_order_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/issue_order_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/delivery_card.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/Features/Home/model/order_phase.dart';
import 'package:dyspatch_rider/Features/Home/widget/cancelled_order_card.dart';
import 'package:dyspatch_rider/Features/Home/widget/countdown_text.dart';
import 'package:dyspatch_rider/Features/Home/widget/pulsating_dot.dart'; // reused for active-card pulsating pill
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'active_order_details_screen.dart';

class ActivityScreen extends StatefulWidget {
  /// Switches HomeScreen back to its Home tab ("Return to home").
  final VoidCallback? onGoHome;

  const ActivityScreen({super.key, this.onGoHome});

  /// Bumped whenever another screen changes the lists, so a mounted
  /// ActivityScreen redraws.
  static final ValueNotifier<int> _changes = ValueNotifier(0);

  /// Report sheet "reason": the order leaves Active and joins Issues with
  /// the usual auto-cancel countdown.
  static void reportIssue({
    required String orderId,
    required String route,
    required String pickupLocation,
    required String deliveryPhase,
    required String reason,
  }) {
    final order = _ActivityScreenState._takeActive(orderId);
    (_ActivityScreenState._ordersByFilter[ActivityFilter.issues] ??= []).insert(
      0,
      ActivityOrder(
        route: order?.route ?? route,
        pickupLocation: order?.pickupLocation ?? pickupLocation,
        amount: '',
        orderId: order?.orderId ?? '#$orderId',
        ride: order?.ride ?? 1,
        reportText: 'Report: $reason',
        deliveryPhase: deliveryPhase,
        autoCancelAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
    _changes.value++;
  }

  /// Report sheet "Cancel Ride": the order leaves Active for Cancelled.
  static void cancelByRider({
    required String orderId,
    required String route,
    required String pickupLocation,
    required String deliveryPhase,
  }) {
    final order = _ActivityScreenState._takeActive(orderId);
    (_ActivityScreenState._ordersByFilter[ActivityFilter.cancelled] ??= [])
        .insert(
          0,
          ActivityOrder(
            route: order?.route ?? route,
            pickupLocation: order?.pickupLocation ?? pickupLocation,
            amount: '',
            orderId: order?.orderId ?? '#$orderId',
            ride: order?.ride ?? 1,
            deliveryPhase: deliveryPhase,
            cancelledDate:
                'Today: ${_ActivityScreenState._formatTime(DateTime.now())}',
            note: 'You cancelled this order!',
          ),
        );
    _changes.value++;
  }

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityFilter _selected = ActivityFilter.newOrder;

  static const Map<ActivityFilter, String> _labels = {
    ActivityFilter.newOrder: 'New',
    ActivityFilter.active: 'Active',
    ActivityFilter.delivered: 'Delivered',
    ActivityFilter.issues: 'Issues',
    ActivityFilter.cancelled: 'Cancelled',
  };

  // static const -> static final. expiresAt uses DateTime.now(), which
  // isn't a compile-time constant, so this map (and the newOrder
  // entries inside it) can no longer be const.
  // Sample data — replace with your real data source per category
  static final Map<ActivityFilter, List<ActivityOrder>> _ordersByFilter = {
    ActivityFilter.newOrder: [
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 1,
        items: '3 items',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        distance: '4.2km',
        duration: '18 mins',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 2,
        items: '3 items',
        expiresAt: DateTime.now().add(const Duration(minutes: 4, seconds: 20)),
        distance: '4.2km',
        duration: '18 mins',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 3,
        items: '3 items',
        expiresAt: DateTime.now().add(const Duration(minutes: 3, seconds: 45)),
        distance: '4.2km',
        duration: '18 mins',
      ),
      ActivityOrder(
        route: 'Sapele Rd → New Benin Market',
        pickupLocation: 'New Benin Market',
        amount: '₦ 3,100',
        orderId: '#BN4903',
        ride: 4,
        items: '3 items',
        expiresAt: DateTime.now().add(const Duration(minutes: 6, seconds: 10)),
        distance: '3.5km',
        duration: '14 mins',
      ),
      ActivityOrder(
        route: 'Airport Rd → GRA',
        pickupLocation: 'GRA Pharmacy',
        amount: '₦ 2,900',
        orderId: '#BN4918',
        ride: 5,
        items: '3 items',
        expiresAt: DateTime.now().add(const Duration(minutes: 5, seconds: 30)),
        distance: '2.8km',
        duration: '11 mins',
      ),
    ],
    ActivityFilter.active: [
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 1,
        eta: 'ETA - 12:41pm',
        items: '3 items',
        statusLabel: 'At Pickup',
        trackId: 'BN-TRK-2402-8F7K3Q',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 2,
        eta: 'ETA - 12:41pm',
        items: '3 items',
        statusLabel: 'Arrived',
        trackId: 'BN-TRK-2402-8F7K3Q',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 3,
        eta: 'ETA - 12:41pm',
        items: '3 Items',
        statusLabel: 'Picked-up',
        trackId: 'BN-TRK-2402-8F7K3Q',
        progress: 0.50,
        progressLabel:
            "Congratulations! Now start your journey to customer's Drop-off",
        nextActionLabel: 'Mark as In Transit',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 4,
        eta: 'ETA - 12:41pm',
        items: '3 Items',
        statusLabel: 'In Transit',
        trackId: 'BN-TRK-2402-8F7K3Q',
        progress: 0.75,
        progressLabel: 'Almost there! Head to drop-off location',
        nextActionLabel: 'Mark as Delivered',
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 5,
        eta: 'ETA - 12:41pm',
        items: '3 Items',
        statusLabel: 'Heading to Pickup',
        trackId: 'BN-TRK-2402-8F7K3Q',
        progress: 0.75,
        progressLabel: 'Almost there! Head to drop-off location',
        nextActionLabel: 'Mark as Delivered',
      ),
    ],
    ActivityFilter.delivered: [
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '₦ 4,200',
        orderId: '#BN4821',
        ride: 1,
        eta: 'ETA - 12:41pm',
        items: '3 Items',
        statusLabel: 'Delivered',
        trackId: 'BN-TRK-2402-8F7K3Q',
        timeline: [
          TimelineEvent(label: 'Created', time: '11:50am'),
          TimelineEvent(label: 'Rider accepted', time: '11:55am'),
          TimelineEvent(label: 'At Pickup', time: '11:59am'),
          TimelineEvent(label: 'Picked-up', time: '12:04pm'),
          TimelineEvent(label: 'In-transit', time: '12:05pm'),
          TimelineEvent(label: 'Arrived', time: '12:41pm'),
          TimelineEvent(label: 'Delivered', time: '12:45pm'),
        ],
      ),
    ],

    ActivityFilter.issues: [
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 1,
        reportText: 'Report: Wrong pickup address',
        deliveryPhase: 'Heading to Pickup',
        autoCancelAt: DateTime.now().add(
          const Duration(minutes: 9, seconds: 50),
        ),
      ),
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 2,
        reportText: 'Report: Sender unavailable',
        deliveryPhase: 'At Pickup',
        autoCancelAt: DateTime.now().add(
          const Duration(minutes: 7, seconds: 20),
        ),
      ),
    ],
    // One sample per cancelled-card design.
    ActivityFilter.cancelled: [
      // Rider cancelled.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 1,
        deliveryPhase: 'Heading to Pickup',
        cancelledDate: 'Today: 12:50pm',
        reason: 'Reason: Vehicle issue',
        note: 'You cancelled this order!',
      ),
      // Sender cancelled before pickup: compensated, rider is free.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 2,
        deliveryPhase: 'Heading to Pickup',
        cancelledDate: 'Today: 12:50pm',
        compensation: '₦ 500',
        reason:
            'So sorry for the stress, order was cancelled by sender on your '
            'way to the pickup',
      ),
      // Sender cancelled mid-delivery: compensated, package goes back.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 3,
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 12:50pm',
        compensation: '₦ 1,000',
        reason:
            'So sorry for the stress, order was cancelled by sender during '
            'delivery. Return package back!',
        returnToSender: true,
      ),
      // Reassigned: not the rider's fault.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 4,
        deliveryPhase: 'Heading to Pickup',
        cancelledDate: 'Today: 12:50pm',
        note: "You didn't do anything wrong!",
        reason:
            'Order was cancelled enroute to pickup. This delivery was '
            'reassigned',
        affectsRating: false,
      ),
      // Late delivery.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 5,
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 12:50pm',
        note: 'You exceeded the delivery time',
        reason: 'Order was cancelled. Delivery is 90mins late',
      ),
      // Fraud detected mid-delivery: package goes back.
      ActivityOrder(
        route: 'Ring Rd → Textile Mill Rd',
        pickupLocation: 'Benin Agro Mart',
        amount: '',
        orderId: '#BN4821',
        ride: 1,
        deliveryPhase: 'In Transit',
        cancelledDate: 'Today: 12:50pm',
        note: 'System suspects fraud or malicious activity',
        reason:
            'Order was cancelled during delivery due to fraud detection. '
            'Return package back!',
        returnToSender: true,
      ),
    ],
  };

  // Fleet owners see one ride's orders at a time (1-based).
  int _selectedRide = 1;

  List<ActivityOrder> get _currentOrders {
    final orders = _ordersByFilter[_selected] ?? [];
    if (!RiderSession.isFleetOwner) return orders;
    return orders.where((o) => o.ride == _selectedRide).toList();
  }

  /// Removes and returns the first Active order with this ID ("#" optional).
  static ActivityOrder? _takeActive(String orderId) {
    final id = orderId.replaceAll('#', '');
    final active = _ordersByFilter[ActivityFilter.active] ?? [];
    final index = active.indexWhere((o) => o.orderId.replaceAll('#', '') == id);
    return index == -1 ? null : active.removeAt(index);
  }

  void _onExternalChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ActivityScreen._changes.addListener(_onExternalChange);
    // Normalise active sample data to the shared phase table (idempotent,
    // the map is static and survives tab switches).
    final active = _ordersByFilter[ActivityFilter.active];
    if (active != null) {
      for (var i = 0; i < active.length; i++) {
        active[i] = _applyPhase(active[i]);
      }
    }
  }

  @override
  void dispose() {
    ActivityScreen._changes.removeListener(_onExternalChange);
    super.dispose();
  }

  static ActivityOrder _applyPhase(ActivityOrder o, [OrderPhase? phase]) {
    final p = phase ?? OrderPhase.of(o.statusLabel);
    if (p == null) return o;
    return o.copyWith(
      statusLabel: p.status,
      progress: p.progress,
      progressLabel: p.progressLabel,
      nextActionLabel: p.actionLabel,
    );
  }

  // Called by ActiveOrderDetailsScreen's primary CTA. Returns the updated
  // order so the details screen can redraw itself. A Delivered order moves
  // from Active to Delivered.
  ActivityOrder? _advanceOrder(ActivityOrder order) {
    final active = _ordersByFilter[ActivityFilter.active] ?? [];
    final index = active.indexOf(order);
    final next = OrderPhase.nextAfter(order.statusLabel);
    if (next == null) return null;

    // TODO: tell the API about the status change once it exists.
    final updated = _applyPhase(order, next);
    if (next.isFinal) {
      AppPopup.delivered(
        context,
        route: order.route,
        merchant: order.pickupLocation,
        amount: order.amount,
      );
    }
    setState(() {
      if (next.isFinal) {
        if (index != -1) active.removeAt(index);
        (_ordersByFilter[ActivityFilter.delivered] ??= []).insert(
          0,
          updated.copyWith(
            eta: 'Delivered at ${_formatTime(DateTime.now())}',
            timeline: [
              TimelineEvent(
                label: 'Delivered',
                time: _formatTime(DateTime.now()),
              ),
            ],
          ),
        );
      } else if (index != -1) {
        active[index] = updated;
      }
    });
    return updated;
  }

  // Declined orders stay in the list just long enough for their card to
  // play the exit animation; _LeavingCard then calls _removeNewOrder.
  final Set<ActivityOrder> _declining = {};

  // Issues the rider marked resolved — their auto-cancel is off. Static so
  // it survives leaving and re-entering the Activity tab, like the lists.
  static final Set<ActivityOrder> _resolvedIssues = {};

  // Countdown ran out on an unresolved issue: move it to Cancelled.
  void _cancelIssue(ActivityOrder order) {
    if (!mounted) return;
    final issues = _ordersByFilter[ActivityFilter.issues] ?? [];
    if (!issues.contains(order)) return; // already handled
    final now = DateTime.now();
    setState(() {
      issues.remove(order);
      (_ordersByFilter[ActivityFilter.cancelled] ??= []).insert(
        0,
        ActivityOrder(
          route: order.route,
          pickupLocation: order.pickupLocation,
          amount: order.amount,
          orderId: order.orderId,
          ride: order.ride,
          deliveryPhase: order.deliveryPhase ?? 'Heading to Pickup',
          cancelledDate: 'Today: ${_formatTime(now)}',
          reason: order.reportText == null
              ? null
              : 'Reason: ${order.reportText!.replaceFirst('Report: ', '')}',
          note: "Auto-cancelled — the issue wasn't resolved in time",
        ),
      );
    });
  }

  // Accepting moves the order out of New and to the top of Active as
  // "Heading to Pickup", then switches to the Active tab so the rider sees
  // it. Orders are removed by identity (not orderId) because the sample
  // data reuses the same ID on several cards.
  void _acceptOrder(ActivityOrder order) {
    if (_isExpired(order)) {
      _removeNewOrder(order);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This order has expired',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // TODO: call the accept-order endpoint once the API exists.
    final eta = DateTime.now().add(
      Duration(minutes: _minutesFrom(order.duration) ?? 20),
    );
    setState(() {
      _ordersByFilter[ActivityFilter.newOrder]?.remove(order);
      (_ordersByFilter[ActivityFilter.active] ??= []).insert(
        0,
        ActivityOrder(
          route: order.route,
          pickupLocation: order.pickupLocation,
          amount: order.amount,
          orderId: order.orderId,
          ride: order.ride,
          eta: 'ETA - ${_formatTime(eta)}',
          items: order.items,
          statusLabel: OrderPhase.all.first.status,
          trackId: order.trackId,
          distance: order.distance,
          duration: order.duration,
          progress: OrderPhase.all.first.progress,
          progressLabel: OrderPhase.all.first.progressLabel,
          nextActionLabel: OrderPhase.all.first.actionLabel,
        ),
      );
      _selected = ActivityFilter.active;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order ${order.orderId} accepted — head to pickup',
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
    );
  }

  void _removeNewOrder(ActivityOrder order) {
    if (!mounted) return;
    setState(() {
      _ordersByFilter[ActivityFilter.newOrder]?.remove(order);
      _declining.remove(order);
    });
  }

  bool _isExpired(ActivityOrder order) =>
      order.expiresAt != null && !order.expiresAt!.isAfter(DateTime.now());

  void _declineOrder(ActivityOrder order) {
    // TODO: call the decline-order endpoint once the API exists.
    setState(() => _declining.add(order));
  }

  /// "18 mins" -> 18
  static int? _minutesFrom(String? duration) =>
      int.tryParse(duration?.split(' ').first ?? '');

  /// 13:05 -> "1:05pm", matching the existing ETA strings.
  static String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute${t.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Activity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // balances back button
                ],
              ),
            ),

            // ── Filter Chips ──
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ActivityFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final filter = ActivityFilter.values[index];
                  final isSelected = filter == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
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

            if (RiderSession.isFleetOwner) ...[
              const SizedBox(height: 12),
              RideTabs(
                selected: _selectedRide - 1,
                onSelected: (i) => setState(() => _selectedRide = i + 1),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],

            const SizedBox(height: 16),

            // ── Order List ──
            Expanded(
              child: _currentOrders.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        MediaQuery.of(context).padding.bottom + 140,
                      ),
                      itemCount: _currentOrders.length,
                      itemBuilder: (context, index) {
                        final order = _currentOrders[index];
                        final card = Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildOrderCard(order),
                        );
                        if (_selected == ActivityFilter.issues) {
                          return _LeavingCard(
                            key: ObjectKey(order),
                            expiresAt: _resolvedIssues.contains(order)
                                ? null
                                : order.autoCancelAt,
                            leave: false,
                            onGone: () => _cancelIssue(order),
                            child: card,
                          );
                        }
                        if (_selected != ActivityFilter.newOrder) return card;
                        // ObjectKey keeps each card's timer/animation tied
                        // to its own order as others are removed around it.
                        return _LeavingCard(
                          key: ObjectKey(order),
                          expiresAt: order.expiresAt,
                          leave: _declining.contains(order),
                          onGone: () => _removeNewOrder(order),
                          child: card,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Scrolls instead of overflowing on short screens / landscape.
  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/Content.svg',
                height: (constraints.maxHeight * 0.35).clamp(120.0, 220.0),
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              Text(
                'Nothing here yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 32 / 24,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Stay tuned! Updates about your orders activities will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 22 / 14,
                  color: Color(0xFF9AA0A6),
                ),
              ),
              // Lifts the block above the floating nav bar.
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(ActivityOrder order) {
    switch (_selected) {
      case ActivityFilter.newOrder:
        return _newOrderCard(order);
      case ActivityFilter.active:
        return _activeOrderCard(order);
      case ActivityFilter.delivered:
        return _deliveredOrderCard(order);
      case ActivityFilter.issues:
        return _issueOrderCard(order);
      case ActivityFilter.cancelled:
        return CancelledOrderCard(
          order: order,
          onFindNewOrders: () =>
              setState(() => _selected = ActivityFilter.newOrder),
          onGoHome: _goHome,
        );
      default:
        return _genericOrderCard(order);
    }
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.inverseSurface),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // CHANGED: _statusPill now takes an optional iconPath so it can render
  // your custom SVGs (newOrder.svg, mark.svg, cancle.svg, issue.svg)
  // instead of a plain Material Icon. Pass null to render icon-less,
  // same as before.
  Widget _statusPill(String label, Color bg, Color fg, {String? iconPath}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null) ...[
            SvgPicture.asset(
              iconPath,
              height: 13,
              width: 13,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                color: fg,
                height: 16 / 12,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Same pill, but with a PulsatingDot in front — used only for
  // active-order cards so the rider gets a clear "this is live" cue.
  // (Active orders don't have a dedicated SVG per your assets — they
  // use the live pulsing dot instead, which already signals "in
  // progress" better than a static icon would.)
  Widget _pulsatingStatusPill(
    String label,
    Color bg,
    Color fg, {
    Color? dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsatingDot(color: dotColor ?? fg, isActive: true),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColorFor(String label) =>
      OrderPhase.of(label)?.color ?? Colors.grey;

  Widget _activeOrderCard(ActivityOrder order) {
    final color = _statusColorFor(order.statusLabel ?? '');
    return GestureDetector(
      onTap: () async {
        final delivered = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => ActiveOrderDetailsScreen(
              order: order,
              onAdvance: _advanceOrder,
            ),
          ),
        );
        if (delivered == true && mounted) {
          setState(() => _selected = ActivityFilter.delivered);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${order.orderId} delivered',
                style: const TextStyle(fontFamily: 'Montserrat'),
              ),
            ),
          );
        }
      },
      child: _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _pulsatingStatusPill(
                    order.statusLabel ?? '',
                    OrderPhase.of(order.statusLabel)?.pillColor ??
                        color.withValues(alpha: 0.12),
                    OrderPhase.of(order.statusLabel)?.pillTextColor ?? color,
                    dotColor: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.orderId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.route,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                height: 24 / 16,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/images/ph_user.svg',
                        width: 14,
                        height: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          order.pickupLocation,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade600,
                            fontFamily: 'Montserrat',
                            height: 22 / 14,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    // CHANGED: swapped Icons.access_time for your SVG set.
                    SvgPicture.asset(
                      'assets/images/ph_clock.svg',
                      width: 14,
                      height: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.eta ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/ph_package.svg',
                      width: 14,
                      height: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.items ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
                if (order.amount.isNotEmpty)
                  Text(
                    order.amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Montserrat',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tap card to view more details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveredOrderCard(ActivityOrder order) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeliveredOrderDetailsScreen(order: order),
          ),
        );
      },
      child: _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // CHANGED: now uses mark.svg instead of a plain pill.
                _statusPill(
                  'Delivered',
                  const Color(0xFFE8F5E9),
                  const Color(0xFF298341),
                  iconPath: 'assets/images/mark.svg',
                ),
                Text(
                  order.orderId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.route,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                height: 24 / 16,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/images/ph_user.svg',
                        width: 14,
                        height: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          order.pickupLocation,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    // CHANGED: swapped Icons.access_time for your SVG set.
                    SvgPicture.asset(
                      'assets/images/ph_clock.svg',
                      width: 14,
                      height: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.eta ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (order.items != null || order.amount.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (order.items != null)
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/images/ph_package.svg',
                          width: 14,
                          height: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.items!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  if (order.amount.isNotEmpty)
                    Text(
                      order.amount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                ],
              ),
            ],
            if (order.trackId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Track-ID',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 6),
              // Tap to copy — shows "Copied successfully" for a moment.
              TrackIdRow(trackId: order.trackId!),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap card to view more details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newOrderCard(ActivityOrder order) {
    return GestureDetector(
      onTap: () async {
        final accepted = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => ActivityDetailsScreen(order: order),
          ),
        );
        if (!mounted || accepted == null) return;
        accepted ? _acceptOrder(order) : _declineOrder(order);
      },
      child: _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // CHANGED: was a stray SvgPicture.asset sitting in the
                // Row next to the pill (which is why it wasn't showing
                // up inside the pill like in your screenshot) — now the
                // icon lives inside the pill itself, matching the design.
                Flexible(
                  child: _statusPill(
                    'New Order',
                    const Color(0xFFE8F5E9),
                    const Color(0xFF298341),
                    iconPath: 'assets/images/newOrder.svg',
                  ),
                ),
                const SizedBox(width: 8),
                order.expiresAt != null
                    ? CountdownText(expiresAt: order.expiresAt!)
                    : Text(
                        order.timeLeft ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontFamily: 'Montserrat',
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.route,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                height: 24 / 16,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/images/ph_user.svg',
                        width: 14,
                        height: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          order.pickupLocation,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.amount,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _acceptOrder(order),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F5E9),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: const Color(0xFF298341),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Montserrat',
                        height: 20 / 14,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineOrder(order),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDECEA),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap card to view more details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueOrderCard(ActivityOrder order) {
    final onSurface = Theme.of(context).colorScheme.inversePrimary;
    return GestureDetector(
      onTap: () async {
        final cancelled = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => IssueOrderDetailsScreen(
              order: order,
              initiallyResolved: _resolvedIssues.contains(order),
              onResolvedChanged: (resolved) => setState(() {
                resolved
                    ? _resolvedIssues.add(order)
                    : _resolvedIssues.remove(order);
              }),
              onAutoCancel: () => _cancelIssue(order),
            ),
          ),
        );
        if (cancelled == true && mounted) {
          setState(() => _selected = ActivityFilter.cancelled);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${order.orderId} was cancelled — issue not resolved',
                style: const TextStyle(fontFamily: 'Montserrat'),
              ),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const IssuePill(),
                Text(
                  order.orderId,
                  style: TextStyle(
                    fontSize: 14,
                    color: onSurface,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            if (order.reportText != null) ...[
              const SizedBox(height: 16),
              Text(
                order.reportText!,
                style: TextStyle(
                  fontSize: 11,
                  color: onSurface,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              order.route,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                height: 24 / 16,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Tap card to view more details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goHome() {
    if (widget.onGoHome != null) {
      widget.onGoHome!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Widget _genericOrderCard(ActivityOrder order) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.route,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
              height: 24 / 16,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.pickupLocation,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}

// Wraps a New Order card and plays its exit: the card fades and drifts
// slightly right, then its space collapses, and [onGone] removes the order.
// The exit runs when [expiresAt] passes, or as soon as [leave] turns true
// (the rider declined). A card that's already expired when first built
// (e.g. the rider was on another tab) plays the same exit straight away.
class _LeavingCard extends StatefulWidget {
  final DateTime? expiresAt;
  final bool leave;
  final VoidCallback onGone;
  final Widget child;

  const _LeavingCard({
    super.key,
    required this.expiresAt,
    required this.leave,
    required this.onGone,
    required this.child,
  });

  @override
  State<_LeavingCard> createState() => _LeavingCardState();
}

class _LeavingCardState extends State<_LeavingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    ),
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: Offset.zero, end: const Offset(0.08, 0)).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
        ),
      );
  late final Animation<double> _size = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeInOut),
    ),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.expiresAt;
    if (widget.leave) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
      return;
    }
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      // Let the first frame paint before animating out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    } else {
      // Small grace so "Expired" is visible for a beat before it leaves.
      _timer = Timer(remaining + const Duration(milliseconds: 600), _leave);
    }
  }

  @override
  void didUpdateWidget(_LeavingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leave && !oldWidget.leave) _leave();
  }

  Future<void> _leave() async {
    // Guard against the timer and a decline both firing.
    if (!mounted || _controller.isAnimating || _controller.isCompleted) return;
    _timer?.cancel();
    await _controller.forward();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
