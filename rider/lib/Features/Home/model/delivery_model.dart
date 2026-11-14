import 'package:flutter/material.dart';

class DeliveryModel {
  final String route;
  final String status;
  final Color statusColor;
  final String orderId;
  final String pickupLocation;
  final String eta;
  final String items;
  final String amount;
  final String trackId;
  final double progress; // 0.0 - 1.0
  final String progressLabel; // helper text under the progress bar
  final String actionLabel; // e.g. 'Confirm Pickup', 'Mark as Delivered'
  final Color actionColor;

  /// True once the order has reached a terminal state (Delivered /
  /// Cancelled). Drives whether the status pill's dot pulsates —
  /// terminal orders should always render a static dot, active ones
  /// should pulse. Defaults to false so existing active-order entries
  /// don't need to be touched.
  final bool isCompleted;

  const DeliveryModel({
    required this.route,
    required this.status,
    required this.statusColor,
    required this.orderId,
    required this.pickupLocation,
    required this.eta,
    required this.items,
    required this.amount,
    required this.trackId,
    required this.progress,
    required this.progressLabel,
    required this.actionLabel,
    required this.actionColor,
    this.isCompleted = false,
  });

  /// Returns a copy of this order with the given fields replaced.
  /// Used to drive status transitions (e.g. Picked-up -> In Transit ->
  /// Delivered) without rebuilding a whole DeliveryModel by hand.
  DeliveryModel copyWith({
    String? route,
    String? status,
    Color? statusColor,
    String? orderId,
    String? pickupLocation,
    String? eta,
    String? items,
    String? amount,
    String? trackId,
    double? progress,
    String? progressLabel,
    String? actionLabel,
    Color? actionColor,
    bool? isCompleted,
  }) {
    return DeliveryModel(
      route: route ?? this.route,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      orderId: orderId ?? this.orderId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      eta: eta ?? this.eta,
      items: items ?? this.items,
      amount: amount ?? this.amount,
      trackId: trackId ?? this.trackId,
      progress: progress ?? this.progress,
      progressLabel: progressLabel ?? this.progressLabel,
      actionLabel: actionLabel ?? this.actionLabel,
      actionColor: actionColor ?? this.actionColor,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
