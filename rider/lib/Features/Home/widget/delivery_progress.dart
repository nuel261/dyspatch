import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Delivery progress from the order-card design: "50%  Picked-up" above a
/// rounded bar tinted with the status colour, with the bike sitting at the
/// end of the track (the drop-off).
class DeliveryProgress extends StatelessWidget {
  /// 0.0 – 1.0
  final double progress;

  /// Status shown beside the percentage, e.g. "Picked-up".
  final String label;

  final Color color;

  /// Unfilled part of the bar; defaults to a light tint of [color].
  final Color? trackColor;

  /// Share of the card width the bar takes up; the design centres a
  /// shorter bar rather than running it edge to edge.
  final double widthFactor;

  const DeliveryProgress({
    super.key,
    required this.progress,
    required this.label,
    required this.color,
    this.trackColor,
    this.widthFactor = 0.72,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.inversePrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: colors.inversePrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          trackColor ?? color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // The artwork is a full-colour photo, so it's never tinted —
                // that flattens it into a blob.
                SvgPicture.asset(
                  'assets/images/Bike.svg',
                  width: 24,
                  height: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
