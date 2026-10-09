import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TruckCard extends StatelessWidget {
  const TruckCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, top: 0, bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: Text ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dyspatch Truck \nComing Soon!!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.inversePrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Transport bigger vessels \nwith ease",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: "Montserrat",
                    color: Color(0xFF5F6368),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Right: Truck SVG ──
          Image.asset(
            "assets/images/truck.png",
            width: 180,
            height: 200,
            fit: BoxFit.contain,
            alignment: Alignment.bottomRight,
          ),
        ],
      ),
    );
  }
}
