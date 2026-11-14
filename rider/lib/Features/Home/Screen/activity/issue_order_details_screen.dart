import 'dart:async';

import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/Features/Home/widget/countdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Issue order details (Activity_Screen 10): report, route, pickup with
/// call/chat, a "Mark issue as resolved" switch and a live auto-cancel
/// countdown. If the countdown runs out while the issue is unresolved the
/// order is cancelled and the screen pops `true`.
class IssueOrderDetailsScreen extends StatefulWidget {
  final ActivityOrder order;

  /// Whether the issue was already marked resolved (kept by ActivityScreen).
  final bool initiallyResolved;

  /// Told when the rider flips the resolved switch.
  final ValueChanged<bool>? onResolvedChanged;

  /// Called when the countdown ends unresolved, before popping.
  final VoidCallback? onAutoCancel;

  const IssueOrderDetailsScreen({
    super.key,
    required this.order,
    this.initiallyResolved = false,
    this.onResolvedChanged,
    this.onAutoCancel,
  });

  @override
  State<IssueOrderDetailsScreen> createState() =>
      _IssueOrderDetailsScreenState();
}

class _IssueOrderDetailsScreenState extends State<IssueOrderDetailsScreen> {
  late bool _resolved = widget.initiallyResolved;
  Timer? _cancelTimer;

  static const _red = Color(0xFFE5202E);

  @override
  void initState() {
    super.initState();
    _scheduleAutoCancel();
  }

  void _scheduleAutoCancel() {
    _cancelTimer?.cancel();
    final at = widget.order.autoCancelAt;
    if (_resolved || at == null) return;
    final remaining = at.difference(DateTime.now());
    _cancelTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _autoCancel,
    );
  }

  void _autoCancel() {
    if (!mounted || _resolved) return;
    // TODO: tell the API the order was auto-cancelled once it exists.
    widget.onAutoCancel?.call();
    Navigator.of(context).pop(true);
  }

  void _setResolved(bool value) {
    // TODO: update the issue status via the API once it exists.
    setState(() => _resolved = value);
    widget.onResolvedChanged?.call(value);
    _scheduleAutoCancel();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final colors = Theme.of(context).colorScheme;
    final onSurface = colors.inversePrimary;

    return Scaffold(
      backgroundColor: colors.primary,
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
                        color: colors.tertiaryContainer,
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
                        color: onSurface,
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
                    color: colors.inverseSurface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Issue pill + order ID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const IssuePill(),
                          Text(
                            order.orderId,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Montserrat',
                              color: onSurface,
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
                            fontFamily: 'Montserrat',
                            color: onSurface,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        order.route,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Pickup + call / chat
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/ph_user.svg',
                            width: 15,
                            height: 15,
                            colorFilter: ColorFilter.mode(
                              onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.pickupLocation,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Montserrat',
                                color: onSurface,
                              ),
                            ),
                          ),
                          // TODO: wire call/chat once contact details come
                          // from the API.
                          _plainIcon('assets/images/ph_phone-call.svg'),
                          const SizedBox(width: 16),
                          _plainIcon('assets/images/ph_chat-circle-dots.svg'),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Mark issue as resolved
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/ph_checks.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              Colors.grey.shade500,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mark issue as resolved',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Montserrat',
                                color: onSurface,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _resolved,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF34A853),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE3E7EB),
                              trackOutlineColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              onChanged: _setResolved,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Auto-cancel note + live countdown
                      if (_resolved)
                        Center(
                          child: Text(
                            'Issue resolved — this order will not be cancelled',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Montserrat',
                              color: const Color(0xFF34A853),
                            ),
                          ),
                        )
                      else if (order.autoCancelAt != null ||
                          order.autoCancelCountdown != null)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Please note: After countdown, order will be cancelled',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Montserrat',
                                color: onSurface,
                              ),
                            ),
                            if (order.autoCancelAt != null)
                              CountdownText(
                                expiresAt: order.autoCancelAt!,
                                compact: true,
                              )
                            else
                              Text(order.autoCancelCountdown!),
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

  Widget _plainIcon(String asset) => SvgPicture.asset(
    asset,
    width: 20,
    height: 20,
    colorFilter: ColorFilter.mode(
      Theme.of(context).colorScheme.inversePrimary,
      BlendMode.srcIn,
    ),
  );
}

/// Red "⚠ Issue" pill from the Issues designs, shared by the list card and
/// the details screen.
class IssuePill extends StatelessWidget {
  const IssuePill({super.key});

  @override
  Widget build(BuildContext context) {
    const red = _IssueOrderDetailsScreenState._red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/warning.svg',
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(red, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          const Text(
            'Issue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
              color: red,
            ),
          ),
        ],
      ),
    );
  }
}
