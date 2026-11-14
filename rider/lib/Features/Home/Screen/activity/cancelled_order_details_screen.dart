import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';

class CancelledOrderDetailsScreen extends StatelessWidget {
  final ActivityOrder order;

  const CancelledOrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.inversePrimary;
    // Rider-cancelled orders carry a note; customer-cancelled ones pay
    // compensation instead.
    final byRider = order.compensation == null;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
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
                              color: const Color(0xFFE3E7EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/cancle.svg',
                                  width: 13,
                                  height: 13,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF1A1A1A),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Cancelled',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Montserrat',
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            order.orderId,
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
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.fromLocation,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat',
                              color: textColor,
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
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.toLocation,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat',
                              color: textColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _labelValueRow(
                        'Status:',
                        byRider
                            ? 'Cancelled by Rider!'
                            : 'Cancelled by Customer',
                        textColor,
                      ),
                      if (order.deliveryPhase != null) ...[
                        const SizedBox(height: 8),
                        _labelValueRow(
                          'Delivery phase:',
                          order.deliveryPhase!,
                          textColor,
                        ),
                      ],
                      if (order.cancelledDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          order.cancelledDate!,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                      if (order.reason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          order.reason!,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                      if (order.compensation != null) ...[
                        const SizedBox(height: 8),
                        _labelValueRow(
                          'Compensation:',
                          order.compensation!,
                          textColor,
                        ),
                      ],
                      if (byRider) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Disclaimer: This may affect your ratings!',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          // Back to the Activity screen (filters + list).
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF298341),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Return to home',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  Widget _labelValueRow(String label, String value, Color textColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontFamily: 'Montserrat',
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}
