import 'package:flutter/material.dart';

class MenuCard extends StatelessWidget {
  final List<MenuItem> items;

  const MenuCard({super.key, required this.items});

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
      child: Column(children: items),
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final bool showDivider;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.showDivider = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabelColor = labelColor ?? const Color(0xFF1A1A1A);
    final effectiveIconColor = iconColor ?? const Color(0xFF5F6368);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),

          child: Column(
            children: [
              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: effectiveIconColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Montserrat",
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: effectiveLabelColor == const Color(0xFFD32F2F)
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF5F6368),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 50,
            endIndent: 16,
            color: Colors.grey.shade400,
          ),
      ],
    );
  }
}
