import 'package:dyspatch_rider/core/api/order_view.dart';
import 'package:dyspatch_rider/core/services/order_actions.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Track/track_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/delivery_card.dart';
import 'package:flutter/material.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/Features/Home/model/order_phase.dart';
import 'package:dyspatch_rider/Features/Home/widget/delivery_progress.dart';
import 'package:dyspatch_rider/Features/Home/widget/pulsating_dot.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ActiveOrderDetailsScreen extends StatefulWidget {
  final ActivityOrder order;

  /// Moves the order to its next phase in the owning list and returns the
  /// updated order (null if it can't advance). Without it the CTA only
  /// updates this screen.
  final ActivityOrder? Function(ActivityOrder order)? onAdvance;

  const ActiveOrderDetailsScreen({
    super.key,
    required this.order,
    this.onAdvance,
  });

  @override
  State<ActiveOrderDetailsScreen> createState() =>
      _ActiveOrderDetailsScreenState();
}

class _ActiveOrderDetailsScreenState extends State<ActiveOrderDetailsScreen> {
  late ActivityOrder order = widget.order;

  Color get _statusColor =>
      OrderPhase.of(order.statusLabel)?.color ?? Colors.grey;

  // Primary CTA: swap this screen to the next phase. Reaching Delivered
  // returns to the list (popping `true`) so it can show the order there.
  Map<String, dynamic>? get _raw => OrderActions.byTrack(order.trackId ?? '');

  Future<void> _advance() async {
    final raw = _raw;
    if (raw == null) return;
    final updated = await OrderActions.advance(context, raw);
    if (updated == null || !mounted) return;
    if (updated['status'] == 'delivered') {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => order = OrderView.activity(updated));
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
                    onTap: () => Navigator.of(context).pop(),
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
                      'Activity details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.inverseSurface,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status pill + order id
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    OrderPhase.of(
                                      order.statusLabel,
                                    )?.pillColor ??
                                    _statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ADDED: pulsating dot, same live-status cue
                                  // used on the Activity list screen cards.
                                  PulsatingDot(
                                    color: _statusColor,
                                    isActive: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      order.statusLabel ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Montserrat',
                                        color:
                                            OrderPhase.of(
                                              order.statusLabel,
                                            )?.pillTextColor ??
                                            _statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.orderId,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        order.route,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // CHANGED: was Icons.person_outline -> ph_user.svg
                      _detailRowSvg(
                        context,
                        'assets/images/ph_user.svg',
                        order.pickupLocation,
                      ),
                      if (order.items != null) ...[
                        const SizedBox(height: 8),
                        // CHANGED: was Icons.inventory_2_outlined -> ph_package.svg
                        _detailRowSvg(
                          context,
                          'assets/images/ph_package.svg',
                          order.items!,
                        ),
                      ],
                      if (order.eta != null) ...[
                        const SizedBox(height: 8),
                        // CHANGED: was Icons.access_time -> ph_clock.svg
                        _detailRowSvg(
                          context,
                          'assets/images/ph_clock.svg',
                          order.eta!,
                        ),
                      ],
                      if (order.amount.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // CHANGED: dropped the payments icon — just show the
                        // amount as plain naira text now.
                        Text(
                          order.amount,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],

                      if (order.trackId != null) ...[
                        const SizedBox(height: 16),
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

                      if (order.progress != null) ...[
                        const SizedBox(height: 20),
                        DeliveryProgress(
                          progress: order.progress!,
                          label: order.statusLabel ?? '',
                          color: _statusColor,
                          trackColor: OrderPhase.of(
                            order.statusLabel,
                          )?.trackColor,
                        ),
                        if (order.progressLabel != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              order.progressLabel!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 20),
                      if ((order.nextActionLabel ?? '').isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _advance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _statusColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  order.nextActionLabel!,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                        ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Material(
                            color: _statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              // Opens the map already tracking this order.
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrackScreen(
                                    initialOrderId: order.trackId ?? order.orderId,
                                  ),
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
                                    Text(
                                      'Navigate',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.map_outlined,
                                      size: 16,
                                      color: _statusColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkResponse(
                            onTap: () => OrderActions.call(context, _raw),
                            child: _plainIconSvg(
                              context,
                              'assets/images/ph_phone-call.svg',
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkResponse(
                            onTap: () => OrderActions.message(context, _raw),
                            child: _plainIconSvg(
                              context,
                              'assets/images/ph_chat-circle-dots.svg',
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkResponse(
                            onTap: () => OrderActions.reportIssue(context, _raw),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              size: 22,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRowSvg(BuildContext context, String iconPath, String text) {
    final color = Theme.of(context).colorScheme.inversePrimary;
    return Row(
      children: [
        SvgPicture.asset(
          iconPath,
          width: 15,
          height: 15,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

  // Call / chat icons sit bare in the design (no grey circle).
  // TODO: wire call and chat once contact details come from the API.
  Widget _plainIconSvg(BuildContext context, String iconPath) {
    return SvgPicture.asset(
      iconPath,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.inversePrimary,
        BlendMode.srcIn,
      ),
    );
  }
}
