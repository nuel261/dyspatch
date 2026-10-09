import 'package:flutter/material.dart';
class DeliveryCards extends StatelessWidget {
  final String title;
  final List<String> features;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const DeliveryCards({
    required this.title,
    required this.features,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFFB9F5C8), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1D5E2E) : const Color(0xFFE0E0E0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Montserrat",
                    color: isSelected
                        ? const Color(0xFF1D5E2E)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 14,
                          color: isSelected
                              ? const Color(0xFF1D5E2E)
                              : const Color(0xFF9E9E9E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFF1D5E2E)
                                : const Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Toggle
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isSelected,
              onChanged: onToggle,
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
