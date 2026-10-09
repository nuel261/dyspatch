import 'package:flutter/material.dart';

class ToggleRow extends StatelessWidget { // Removed the underscore
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const ToggleRow({
    super.key, // Added super.key for best practices
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5F6368)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: "Montserrat",
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF1D5E2E),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE0E0E0),
            ),
          ),
        ],
      ),
    );
  }
}