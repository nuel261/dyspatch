import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:flutter/material.dart';

/// Fleet owners' "Ride 1, Ride 2, ..." row — scrolls sideways when the
/// fleet is wide. Used on Home, Activity, Earning and Notifications so the
/// tabs look the same everywhere. Only render it when
/// [RiderSession.isFleetOwner].
class RideTabs extends StatelessWidget {
  /// Selected tab index into [labels].
  final int selected;
  final ValueChanged<int> onSelected;

  /// Defaults to Ride 1..[RiderSession.fleetRideCount]; Earning prepends
  /// "Total".
  final List<String>? labels;

  /// Side padding for screens whose lists run edge to edge.
  final EdgeInsetsGeometry padding;

  const RideTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.labels,
    this.padding = EdgeInsets.zero,
  });

  static List<String> get rideLabels => [
    for (var i = 1; i <= RiderSession.fleetRideCount; i++) 'Ride $i',
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = labels ?? rideLabels;
    final selectedColor = Theme.of(context).colorScheme.inversePrimary;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: kThemeAnimationDuration,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? selectedColor : const Color(0xFF9AA0A6),
                  ),
                  child: Text(tabs[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
