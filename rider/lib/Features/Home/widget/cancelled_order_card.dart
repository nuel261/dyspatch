import 'package:dyspatch_rider/Features/Home/Screen/Track/track_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/cancelled_order_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Cancelled order card, shared by the Activity "Cancelled" tab and Home's
/// Recent Orders. The variant comes from the order: compensation (sender
/// cancelled), note (rider cancelled / late / fraud) and returnToSender.
class CancelledOrderCard extends StatelessWidget {
  final ActivityOrder order;

  /// "Find New Orders" on compensated cards.
  final VoidCallback onFindNewOrders;

  /// "Return to home".
  final VoidCallback onGoHome;

  const CancelledOrderCard({
    super.key,
    required this.order,
    required this.onFindNewOrders,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.inversePrimary;
    final bodyStyle = TextStyle(
      fontSize: 14,
      color: textColor,
      fontFamily: 'Montserrat',
      height: 22 / 14,
    );
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CancelledOrderDetailsScreen(order: order),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.inverseSurface),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusPill(),
                Text(order.orderId, style: bodyStyle),
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
            // Cancelled by the customer: rider is compensated.
            if (order.compensation != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/ph_user.svg',
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      order.pickupLocation,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${order.compensation!} Compensation', style: bodyStyle),
            ],
            // Cancelled by the rider.
            if (order.note != null) ...[
              const SizedBox(height: 12),
              Text('Note: ${order.note!}', style: bodyStyle),
              const SizedBox(height: 4),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/warning.svg',
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      order.affectsRating
                          ? 'This may affect your ratings'
                          : 'This will not affect your ratings',
                      style: bodyStyle,
                    ),
                  ),
                ],
              ),
            ],
            if (order.reason != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  order.reason!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ..._actions(context),
          ],
        ),
      ),
    );
  }

  Widget _statusPill() {
    const fg = Color(0xFF1A1A1A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/cancle.svg',
            height: 13,
            width: 13,
            colorFilter: const ColorFilter.mode(fg, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          const Text(
            'Cancelled',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
              color: fg,
              height: 16 / 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  // What the rider can do next:
  //  • still holding the package → Navigate to sender
  //  • compensated before pickup → Find New Orders (+ Return to home)
  //  • otherwise → Return to home
  List<Widget> _actions(BuildContext context) {
    if (order.returnToSender) {
      return [
        _button(
          'Navigate to sender',
          icon: Icons.map_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackScreen(initialOrderId: order.orderId),
            ),
          ),
        ),
      ];
    }
    if (order.compensation != null) {
      return [
        _button('Find New Orders', onTap: onFindNewOrders),
        const SizedBox(height: 12),
        _button('Return to home', secondary: true, onTap: onGoHome),
      ];
    }
    return [_button('Return to home', onTap: onGoHome)];
  }

  Widget _button(
    String label, {
    required VoidCallback onTap,
    IconData? icon,
    bool secondary = false,
  }) {
    const green = Color(0xFF34A853);
    final fg = secondary ? green : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: secondary ? green.withValues(alpha: 0.1) : green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: secondary
              ? BorderSide(color: green.withValues(alpha: 0.2))
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
