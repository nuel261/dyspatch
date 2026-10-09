import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

/// A delivery in the customer's list (GET /orders).
class DeliveryModel {
  final String route;
  final String status;
  final String statusKey;
  final Color statusColor;
  final String orderId;
  final String rider;
  final String eta;
  final String items;
  final String amount;
  final String trackId;

  const DeliveryModel({
    required this.route,
    required this.status,
    required this.statusColor,
    required this.orderId,
    required this.rider,
    required this.eta,
    required this.items,
    required this.amount,
    required this.trackId,
    this.statusKey = '',
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] ?? 'pending') as String;
    final n = (j['items_count'] as num?)?.toInt() ?? 1;
    final etaMin = (j['eta_minutes'] as num?)?.toInt();
    String eta;
    if (status == 'delivered') {
      eta = 'Delivered · ${clock(parseTime(j['delivered_at']))}';
    } else if (status == 'cancelled' || status == 'failed') {
      eta = dayGroup(parseTime(j['created_at']));
    } else if (status == 'arrived') {
      eta = 'Rider has arrived';
    } else if (etaMin != null && etaMin > 0) {
      eta = 'ETA · ${clock(DateTime.now().add(Duration(minutes: etaMin)))}';
    } else {
      eta = 'ETA · --';
    }
    return DeliveryModel(
      route: (j['route'] ?? '') as String,
      status: (j['status_label'] ?? status) as String,
      statusKey: status,
      statusColor: colorForStatus(status),
      orderId: 'Order ${j['order_no'] ?? ''}',
      rider: (j['rider_name'] as String?) ?? (status == 'pending' ? 'Finding rider…' : '—'),
      eta: eta,
      items: '$n Item${n == 1 ? '' : 's'}',
      amount: (j['fee'] as String?) ?? naira(j['fee_kobo']),
      trackId: (j['track_id'] ?? '') as String,
    );
  }
}
