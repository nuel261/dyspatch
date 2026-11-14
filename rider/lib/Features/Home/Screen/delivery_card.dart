import 'package:dyspatch_rider/core/services/order_actions.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Track/track_screen.dart';
import 'package:dyspatch_rider/Features/Home/model/delivery_model.dart';
import 'package:dyspatch_rider/Features/Home/model/order_phase.dart';
import 'package:dyspatch_rider/Features/Home/widget/delivery_progress.dart';
import 'package:dyspatch_rider/Features/Home/widget/pulsating_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home order card, laid out per the order-card designs: status pill +
/// order ID, route, pickup/ETA, items/amount, Track-ID and the bike progress
/// bar. Tapping the card expands it to show the phase hint and the primary
/// CTA ("Confirm Pickup", "Mark as In Transit", ...); tapping again
/// collapses it.
class DeliveryCard extends StatefulWidget {
  final DeliveryModel delivery;

  // Fired when the primary CTA is tapped. HomeContent uses it to move the
  // order to its next phase.
  final VoidCallback? onAction;

  /// Whether the card starts expanded (CTA visible).
  final bool initiallyExpanded;

  /// Delivered cards: "View delivery timeline".
  final VoidCallback? onViewTimeline;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onAction,
    this.initiallyExpanded = false,
    this.onViewTimeline,
  });

  @override
  State<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<DeliveryCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final onSurface = Theme.of(context).colorScheme.inversePrimary;
    final phase = OrderPhase.of(delivery.status);
    final color = phase?.color ?? delivery.statusColor;

    // Delivered/Cancelled (isCompleted == true) always render a static
    // dot. Everything else — including "Issue" — pulses only while the
    // order is still active, per shouldPulse()'s rules.
    final bool pulsing = shouldPulse(
      delivery.status,
      isOrderActive: !delivery.isCompleted,
    );
    final hasAction =
        delivery.actionLabel.isNotEmpty && widget.onAction != null;
    // Recent Orders design: ✓ pill, no progress bar, timeline when expanded.
    final isDelivered = delivery.status == 'Delivered';

    TextStyle body([double size = 14]) => TextStyle(
      fontFamily: 'Montserrat',
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 22 / 14,
      color: onSurface,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.tertiaryContainer,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status pill + Order ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: phase?.pillColor ?? color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDelivered)
                          SvgPicture.asset(
                            'assets/images/mark.svg',
                            height: 13,
                            width: 13,
                            colorFilter: ColorFilter.mode(
                              phase?.pillTextColor ?? color,
                              BlendMode.srcIn,
                            ),
                          )
                        else
                          PulsatingDot(color: color, isActive: pulsing),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            delivery.status,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 16 / 12,
                              color: phase?.pillTextColor ?? color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(delivery.orderId, style: body()),
              ],
            ),
            const SizedBox(height: 16),

            // Route
            Text(
              delivery.route,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 24 / 16,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 14),

            // Pickup location + ETA
            Row(
              children: [
                SvgPicture.asset(
                  "assets/images/ph_user.svg",
                  height: 14,
                  width: 14,
                  colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delivery.pickupLocation,
                    overflow: TextOverflow.ellipsis,
                    style: body(),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 15, color: onSurface),
                const SizedBox(width: 4),
                Text(delivery.eta, style: body()),
              ],
            ),
            const SizedBox(height: 4),

            // Items + Amount
            Row(
              children: [
                SvgPicture.asset(
                  "assets/images/ph_package.svg",
                  height: 14,
                  width: 14,
                  colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(delivery.items, style: body())),
                Text(delivery.amount, style: body()),
              ],
            ),
            const SizedBox(height: 14),

            // Track ID
            Text(
              'Track-ID',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            TrackIdRow(trackId: delivery.trackId),

            if (!isDelivered) ...[
              const SizedBox(height: 18),
              DeliveryProgress(
                progress: delivery.progress,
                label: delivery.status,
                color: color,
                trackColor: phase?.trackColor,
              ),
            ],

            // Expanded: phase hint + primary CTA.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            delivery.progressLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        if (isDelivered) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Material(
                              color: const Color(0xFF1E5B31),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.onViewTimeline,
                                child: const Center(
                                  child: Text(
                                    'View delivery timeline',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 20 / 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ActionRow(
                            orderId: delivery.orderId,
                            trackId: delivery.trackId,
                            label: 'View Route',
                            color: color,
                            tint:
                                phase?.pillColor ??
                                color.withValues(alpha: 0.12),
                          ),
                        ],
                        if (hasAction) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Material(
                              color: color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.onAction,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          delivery.actionLabel,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            height: 20 / 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SvgPicture.asset(
                                        "assets/images/ph_checks.svg",
                                        height: 14,
                                        width: 14,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ActionRow(
                            orderId: delivery.orderId,
                            trackId: delivery.trackId,
                            label: phase?.mapActionLabel ?? 'Navigate',
                            color: color,
                            tint:
                                phase?.pillColor ??
                                color.withValues(alpha: 0.12),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _expanded
                    ? 'Tap card to view less details'
                    : 'Tap card to view more details',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 16 / 11,
                  letterSpacing: -0.22,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tinted map button (Navigate / View Route) followed by the call, chat and
// report icons, shown under the CTA when the card is expanded.
class _ActionRow extends StatelessWidget {
  final String orderId;
  final String trackId;
  final String label;
  final Color color;
  final Color tint;

  const _ActionRow({
    required this.orderId,
    required this.trackId,
    required this.label,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.inversePrimary;

    final order = OrderActions.byTrack(trackId);
    Widget svgIcon(String path, VoidCallback onTap) => InkResponse(
      onTap: onTap,
      radius: 22,
      child: SvgPicture.asset(
        path,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );

    return Row(
      children: [
        Flexible(
          child: Material(
            color: tint,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              // Opens the map already tracking this order.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrackScreen(initialOrderId: trackId),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.map_outlined, size: 16, color: color),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        svgIcon('assets/images/ph_phone-call.svg', () => OrderActions.call(context, order)),
        const SizedBox(width: 16),
        svgIcon('assets/images/ph_chat-circle-dots.svg', () => OrderActions.message(context, order)),
        const SizedBox(width: 16),
        InkResponse(
          onTap: () => OrderActions.reportIssue(context, order),
          radius: 22,
          child: SvgPicture.asset(
            'assets/images/ph_warning.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(Color(0xFFD32F2F), BlendMode.srcIn),
          ),
        ),
      ],
    );
  }
}

// Self-contained Track-ID row. Handles its own "just copied" state so
// tapping it swaps the text + icon in place instead of showing a
// snackbar, then reverts back after a couple seconds.
class TrackIdRow extends StatefulWidget {
  final String trackId;
  const TrackIdRow({super.key, required this.trackId});

  @override
  State<TrackIdRow> createState() => TrackIdRowState();
}

class TrackIdRowState extends State<TrackIdRow> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    if (_copied) return; // ignore taps while already showing "copied"
    await Clipboard.setData(ClipboardData(text: widget.trackId));
    setState(() => _copied = true);
    // Revert back to the track ID after a beat.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _handleCopy,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE3E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _copied ? 'Copied successfully' : widget.trackId,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 22 / 14,
                    letterSpacing: 0.0,
                    color: _copied
                        ? Theme.of(context).colorScheme.inversePrimary
                        : Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _copied
                  ? SvgPicture.asset(
                      "assets/images/ph_checks.svg",
                      height: 18,
                      width: 18,
                      color: const Color(0xFF298341),
                    )
                  : Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
