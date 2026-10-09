import 'package:dyspatch_app/Features/Home/model/delivery_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;

  const DeliveryCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiaryContainer,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route
            Text(
              delivery.route,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Status + Order ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: delivery.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: delivery.statusColor),
                      const SizedBox(width: 5),
                      Text(
                        delivery.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: delivery.statusColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  delivery.orderId,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Rider + ETA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_bike_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      delivery.rider,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.inversePrimary,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Montserrat',
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF298341),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 13,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delivery.eta,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.inversePrimary,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Items + Amount
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  delivery.items,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const Spacer(),
                Text(
                  delivery.amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Track ID
            Text(
              'Track-ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.inversePrimary,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0XFFE3E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    delivery.trackId,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Montserrat',
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: delivery.trackId));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Track ID ${delivery.trackId} copied')));
                    },
                    child: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tap hint
            Center(
              child: Text(
                'Tap card to view more details',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
