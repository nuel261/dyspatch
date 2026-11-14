enum ActivityFilter { newOrder, active, delivered, issues, cancelled }

class TimelineEvent {
  final String label;
  final String time;

  const TimelineEvent({required this.label, required this.time});
}

class ActivityOrder {
  final String route;
  final String pickupLocation;
  final String amount;
  final String orderId;
  final String? timeLeft;
  final DateTime? expiresAt; // NEW — drives the live countdown
  final String? eta;
  final String? items;
  final String? statusLabel;
  final String? trackId;
  final String? note;
  final String? reason;
  final String? compensation;
  final String? reportText;
  final String? distance;
  final String? duration;
  final double? progress;
  final String? progressLabel;
  final String? nextActionLabel;
  final List<TimelineEvent>? timeline;
  final String? deliveryPhase;
  final String? cancelledDate;
  final String? autoCancelCountdown; // e.g. "09:50" (static fallback)

  /// When an unresolved issue auto-cancels the order; drives the live
  /// countdown on Issue details.
  final DateTime? autoCancelAt;

  /// Cancelled orders: whether the cancellation counts against the
  /// rider's ratings ("This may affect" vs "This will not affect").
  final bool affectsRating;

  /// Cancelled orders: the rider already has the package and must take it
  /// back to the sender, so the card offers "Navigate to sender".
  final bool returnToSender;

  /// Fleet owners: which ride (bike, 1-based) the order belongs to.
  final int ride;

  const ActivityOrder({
    required this.route,
    required this.pickupLocation,
    required this.amount,
    required this.orderId,
    this.timeLeft,
    this.expiresAt, // NEW
    this.eta,
    this.items,
    this.statusLabel,
    this.trackId,
    this.note,
    this.reason,
    this.compensation,
    this.reportText,
    this.distance,
    this.duration,
    this.progress,
    this.progressLabel,
    this.nextActionLabel,
    this.timeline,
    this.deliveryPhase,
    this.cancelledDate,
    this.autoCancelCountdown,
    this.autoCancelAt,
    this.affectsRating = true,
    this.returnToSender = false,
    this.ride = 1,
  });

  /// Copy with the phase-related fields replaced (used by the CTA flow).
  ActivityOrder copyWith({
    String? statusLabel,
    String? eta,
    double? progress,
    String? progressLabel,
    String? nextActionLabel,
    List<TimelineEvent>? timeline,
  }) {
    return ActivityOrder(
      route: route,
      pickupLocation: pickupLocation,
      amount: amount,
      orderId: orderId,
      timeLeft: timeLeft,
      expiresAt: expiresAt,
      eta: eta ?? this.eta,
      items: items,
      statusLabel: statusLabel ?? this.statusLabel,
      trackId: trackId,
      note: note,
      reason: reason,
      compensation: compensation,
      reportText: reportText,
      distance: distance,
      duration: duration,
      progress: progress ?? this.progress,
      progressLabel: progressLabel ?? this.progressLabel,
      nextActionLabel: nextActionLabel ?? this.nextActionLabel,
      timeline: timeline ?? this.timeline,
      deliveryPhase: deliveryPhase,
      cancelledDate: cancelledDate,
      autoCancelCountdown: autoCancelCountdown,
      autoCancelAt: autoCancelAt,
      affectsRating: affectsRating,
      returnToSender: returnToSender,
      ride: ride,
    );
  }

  String get fromLocation => route.split('→').first.trim();
  String get toLocation =>
      route.contains('→') ? route.split('→').last.trim() : '';
}
