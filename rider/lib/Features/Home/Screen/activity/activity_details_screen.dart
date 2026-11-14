import 'package:flutter/material.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/Features/Home/widget/countdown_text.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ActivityDetailsScreen extends StatelessWidget {
  final ActivityOrder order;

  const ActivityDetailsScreen({super.key, required this.order});

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/newOrder.svg',
                                  height: 13,
                                  width: 13,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF298341),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'New Order',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Montserrat',
                                    color: Color(0xFF298341),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (order.expiresAt != null)
                            CountdownText(
                              expiresAt: order.expiresAt!,
                              boxed: true,
                            )
                          else if (order.timeLeft != null)
                            Text(
                              order.timeLeft!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'From:',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // NOTE: no ph_ SVG provided for this yet — left as Material.
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.fromLocation,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat',
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'To:',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // NOTE: no ph_ SVG provided for this yet — left as Material.
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.toLocation,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat',
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _detailRowSvg(
                        'assets/images/ph_user.svg',
                        order.pickupLocation,
                      ),
                      // ADDED: number of items row, right after pickup —
                      // reuses ph_package.svg like the other order cards.
                      if (order.items != null) ...[
                        const SizedBox(height: 10),
                        _detailRowSvg(
                          'assets/images/ph_package.svg',
                          order.items!,
                        ),
                      ],
                      if (order.distance != null) ...[
                        const SizedBox(height: 10),
                        // CHANGED: was Icons.route_outlined -> distance.svg
                        _detailRowSvg(
                          'assets/images/distance.svg',
                          order.distance!,
                        ),
                      ],
                      if (order.duration != null) ...[
                        const SizedBox(height: 10),
                        _detailRowSvg(
                          'assets/images/ph_clock.svg',
                          order.duration!,
                        ),
                      ],
                      const SizedBox(height: 10),
                      // CHANGED: dropped the payments icon — just show the
                      // amount as plain naira text now.
                      Text(
                        order.amount,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              // Pops `true` so ActivityScreen moves the
                              // order into Active.
                              onPressed: () => Navigator.of(context).pop(true),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8F5E9),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  color: Color(0xFF298341),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              // Pops `false` so ActivityScreen drops it.
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDECEA),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
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

  // CHANGED: new helper for rows that use an SVG asset instead of an
  // Icon(IconData).
  Widget _detailRowSvg(String iconPath, String text) {
    return Row(
      children: [
        SvgPicture.asset(
          iconPath,
          width: 15,
          height: 15,
          colorFilter: ColorFilter.mode(Colors.grey.shade500, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }
}
