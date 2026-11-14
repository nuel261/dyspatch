import 'package:flutter/material.dart';

import '../../Features/Home/model/activity_filter.dart';
import '../../Features/Home/model/delivery_model.dart';
import '../../Features/Home/model/order_phase.dart';
import '../services/rider_state.dart';
import '../ui/format.dart';

/// Maps backend orders and offers onto the design's view models
/// (DeliveryModel cards, ActivityOrder rows), so the screens keep their
/// look while showing live data.
class OrderView {
  /// Backend status → the design's phase name.
  static String phaseName(String status) => switch (status) {
        'matched' => 'Heading to Pickup',
        'picked_up' => 'Picked-up',
        'en_route' => 'In Transit',
        'arrived' => 'Arrived',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        'failed' => 'Issue',
        _ => 'Heading to Pickup',
      };

  static bool isActive(String status) => const ['matched', 'picked_up', 'en_route', 'arrived'].contains(status);

  /// "#DSP-1024" style id shown on cards.
  static String orderNo(Map<String, dynamic> o) {
    final n = (o['order_no'] ?? o['id'] ?? '').toString();
    return n.startsWith('#') ? n : '#$n';
  }

  static String _place(String? address) {
    final a = (address ?? '').trim();
    if (a.isEmpty) return '—';
    final first = a.split(',').first.trim();
    return first.length > 32 ? '${first.substring(0, 31)}…' : first;
  }

  static String route(Map<String, dynamic> o) =>
      '${_place(o['pickup']?['address'] as String?)} → ${_place(o['dropoff']?['address'] as String?)}';

  static String itemsText(Map<String, dynamic> o) {
    final items = (o['items'] as List?) ?? const [];
    final n = items.isEmpty ? 1 : items.length;
    return '$n Item${n == 1 ? '' : 's'}';
  }

  static String _eta(Map<String, dynamic> o) {
    // ~3 min per km at city speed, from when the job was accepted.
    final start = parseTime(o['matched_at']) ?? parseTime(o['created_at']) ?? DateTime.now();
    final kmTrip = (o['distance_km'] as num?)?.toDouble() ?? 5;
    return 'ETA - ${clock(start.add(Duration(minutes: (10 + kmTrip * 3).round())))}';
  }

  static DeliveryModel delivery(Map<String, dynamic> o) {
    final status = (o['status'] as String?) ?? 'matched';
    final phase = OrderPhase.of(phaseName(status)) ?? OrderPhase.all.first;
    final done = !isActive(status);
    return DeliveryModel(
      route: route(o),
      status: phase.status,
      statusColor: phase.color,
      orderId: orderNo(o),
      pickupLocation: _place(o['pickup']?['address'] as String?),
      eta: status == 'delivered' ? 'Delivered ${dayTime(parseTime(o['delivered_at']))}' : _eta(o),
      items: itemsText(o),
      amount: naira(o['earning_kobo'] as num?),
      trackId: (o['track_id'] ?? '').toString(),
      progress: phase.progress,
      progressLabel: phase.progressLabel,
      actionLabel: done ? '' : phase.actionLabel,
      actionColor: phase.color,
      isCompleted: done,
    );
  }

  static List<TimelineEvent> timeline(Map<String, dynamic> o) {
    final ev = <TimelineEvent>[];
    void add(String label, dynamic iso) {
      final t = parseTime(iso);
      if (t != null) ev.add(TimelineEvent(label: label, time: clock(t)));
    }

    add('Created', o['created_at']);
    add('Rider accepted', o['matched_at']);
    add('Picked-up', o['picked_up_at']);
    add('Arrived', o['arrived_at']);
    add('Delivered', o['delivered_at']);
    add('Cancelled', o['cancelled_at']);
    return ev;
  }

  /// An order as an Activity row (active, delivered, cancelled or issue).
  static ActivityOrder activity(Map<String, dynamic> o) {
    final status = (o['status'] as String?) ?? 'matched';
    final phase = OrderPhase.of(phaseName(status));
    final cancelled = status == 'cancelled';
    final reason = (o['cancel_reason'] as String?)?.trim();
    return ActivityOrder(
      route: route(o),
      pickupLocation: _place(o['pickup']?['address'] as String?),
      amount: naira(o['earning_kobo'] as num?),
      orderId: orderNo(o),
      eta: isActive(status) ? _eta(o) : dayTime(parseTime(o['delivered_at'] ?? o['updated_at'])),
      items: itemsText(o),
      statusLabel: phaseName(status),
      trackId: (o['track_id'] ?? '').toString(),
      distance: km(o['distance_km'] as num?),
      duration: '${(10 + ((o['distance_km'] as num?)?.toDouble() ?? 5) * 3).round()} mins',
      progress: phase?.progress,
      progressLabel: phase?.progressLabel,
      nextActionLabel: isActive(status) ? phase?.actionLabel : null,
      timeline: timeline(o),
      deliveryPhase: cancelled ? (o['picked_up_at'] != null ? 'In Transit' : 'Heading to Pickup') : null,
      cancelledDate: cancelled ? dayTime(parseTime(o['cancelled_at'])) : null,
      reason: cancelled || status == 'failed' ? (reason?.isNotEmpty == true ? 'Reason: $reason' : null) : null,
      note: cancelled ? 'This order was cancelled' : null,
      reportText: status == 'failed' ? reason : null,
      affectsRating: false,
      returnToSender: cancelled && o['picked_up_at'] != null,
    );
  }

  /// A live job offer as a "New" Activity row with its countdown.
  static ActivityOrder offer(Offer of) => ActivityOrder(
        route: '${_place(of.pickup)} → ${_place(of.dropoff)}',
        pickupLocation: _place(of.pickup),
        amount: naira(of.earningKobo),
        orderId: '#${of.orderId}',
        expiresAt: of.expiresAt,
        timeLeft: '${of.secondsLeft}s',
        distance: km(of.tripKm),
        duration: '${(of.toPickupKm * 3).round().clamp(1, 999)} mins away',
        statusLabel: 'New',
        trackId: 'offer-${of.id}',
        items: of.isCash ? 'Cash ${naira(of.feeKobo)}' : '1 Item',
      );

  static Color phaseColor(String status) => (OrderPhase.of(phaseName(status)) ?? OrderPhase.all.first).color;
}
