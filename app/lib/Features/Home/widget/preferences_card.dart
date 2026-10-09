import 'package:flutter/material.dart';
import 'toggle_row.dart'; // Import your new toggle row file

class PreferencesCard extends StatelessWidget { // Removed the underscore
  final bool lightMode;
  final bool autoAssignRiders;
  final ValueChanged<bool> onLightModeChanged;
  final ValueChanged<bool> onAutoAssignChanged;
  final VoidCallback onDeliveryTypeTap;

  const PreferencesCard({
    super.key,
    required this.lightMode,
    required this.autoAssignRiders,
    required this.onLightModeChanged,
    required this.onAutoAssignChanged,
    required this.onDeliveryTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      child: Column(
        children: [
          // Notice we removed the underscore here
          ToggleRow(
            icon: Icons.wb_sunny_outlined,
            label: "Light Mode",
            value: lightMode,
            onChanged: onLightModeChanged,
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 50,
            endIndent: 16,
            color: Colors.grey.shade400,
          ),

          // Language row... (Keep your existing code)
          // Divider...
          
          // Default Delivery Type... (Keep your existing code)
          // Divider...

          ToggleRow(
            icon: Icons.people_outline,
            label: "Auto-Assign Riders",
            value: autoAssignRiders,
            onChanged: onAutoAssignChanged,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}