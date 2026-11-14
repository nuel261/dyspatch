import 'package:flutter/material.dart';

/// One step of an active delivery. The primary CTA on an order card always
/// moves the order to the next phase:
///
///   Heading to Pickup → At Pickup → Picked-up → In Transit → Arrived
///   → Delivered
///
/// Colours, wording and progress come from the order-card designs. Home
/// cards, Activity cards and Activity details all read from this table so a
/// status looks and behaves the same everywhere.
class OrderPhase {
  final String status;

  /// Dot, progress fill and CTA button colour.
  final Color color;

  /// Unfilled part of the progress bar.
  final Color trackColor;

  /// Status pill background and text.
  final Color pillColor;
  final Color pillTextColor;

  final double progress;

  /// Helper line under the progress bar.
  final String progressLabel;

  /// Label of the CTA that advances out of this phase ('' when final).
  final String actionLabel;

  const OrderPhase({
    required this.status,
    required this.color,
    required this.trackColor,
    required this.pillColor,
    required this.pillTextColor,
    required this.progress,
    required this.progressLabel,
    required this.actionLabel,
  });

  bool get isFinal => actionLabel.isEmpty;

  /// Label of the tinted map button beside the call/chat/alert icons.
  /// Once arrived, the rider reviews the route rather than navigating.
  String get mapActionLabel => status == 'Arrived' ? 'View Route' : 'Navigate';

  static const List<OrderPhase> all = [
    OrderPhase(
      status: 'Heading to Pickup',
      color: Color(0xFFFFCC00), // yellow
      trackColor: Color(0xFFFFF0C2),
      pillColor: Color(0xFFFFF4CC),
      pillTextColor: Color(0xFF8A6A00),
      progress: 0.10,
      progressLabel: "You're on your way to pickup",
      actionLabel: 'Confirm Pickup',
    ),
    OrderPhase(
      status: 'At Pickup',
      color: Color(0xFFF2800A), // orange
      trackColor: Color(0xFFFDE2C6),
      pillColor: Color(0xFFFFF0E1),
      pillTextColor: Color(0xFFF2800A),
      progress: 0.30,
      progressLabel: 'Verify package before confirming',
      actionLabel: 'Confirm Pickup',
    ),
    OrderPhase(
      status: 'Picked-up',
      color: Color(0xFFA100FF), // violet
      trackColor: Color(0xFFF0D9FF),
      pillColor: Color(0xFFF5E6FF),
      pillTextColor: Color(0xFFA100FF),
      progress: 0.50,
      progressLabel:
          "Congratulations! Now start your journey to customer's Drop-off",
      actionLabel: 'Mark as In Transit',
    ),
    OrderPhase(
      status: 'In Transit',
      color: Color(0xFF1D3B3B), // dark teal
      trackColor: Color(0xFF8ED0D2),
      pillColor: Color(0xFFE5EDED),
      pillTextColor: Color(0xFF1D3B3B),
      progress: 0.75,
      progressLabel: 'You are almost there!',
      actionLabel: 'Mark as Arrived',
    ),
    OrderPhase(
      status: 'Arrived',
      color: Color(0xFF34A853), // green
      trackColor: Color(0xFFCDEBD6),
      pillColor: Color(0xFFE8F5E9),
      pillTextColor: Color(0xFF34A853),
      progress: 1.0,
      progressLabel: 'Confirm delivery with recipient by receiving the OTP',
      actionLabel: 'Mark as Delivered',
    ),
    OrderPhase(
      status: 'Delivered',
      color: Color(0xFF298341), // green
      trackColor: Color(0xFFCDEBD6),
      pillColor: Color(0xFFE8F5E9),
      pillTextColor: Color(0xFF298341),
      progress: 1.0,
      progressLabel: 'Delivered successfully!',
      actionLabel: '',
    ),
  ];

  /// The phase for [status], or null for statuses outside the flow
  /// (Issue, Cancelled, ...).
  static OrderPhase? of(String? status) {
    for (final phase in all) {
      if (phase.status == status) return phase;
    }
    return null;
  }

  /// The phase the CTA moves to from [status], or null if there is none.
  static OrderPhase? nextAfter(String? status) {
    final i = all.indexWhere((p) => p.status == status);
    if (i == -1 || i == all.length - 1) return null;
    return all[i + 1];
  }
}
