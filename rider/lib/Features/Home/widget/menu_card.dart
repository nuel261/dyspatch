import 'package:flutter/material.dart';

class MenuCard extends StatelessWidget {
  final List<MenuItem> items;

  /// Card background; defaults to the theme's onPrimaryContainer.
  final Color? color;

  const MenuCard({super.key, required this.items, this.color});

  @override
  Widget build(BuildContext context) {
    final background =
        color ?? Theme.of(context).colorScheme.onPrimaryContainer;
    // Animate with the same timing as MaterialApp's theme transition so an
    // explicit color doesn't snap ahead of the rest of the screen.
    return AnimatedContainer(
      duration: kThemeAnimationDuration,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: background),
      ),
      child: Column(children: items),
    );
  }
}

class MenuItem extends StatelessWidget {
  // CHANGED: icon is now a Widget (e.g. SvgPicture.asset(...)) instead of
  // IconData, so callers control the asset + color directly — matches
  // settings.dart's ph_*.svg pattern. Anywhere still doing
  // MenuItem(icon: Icons.something, ...) needs to become
  // MenuItem(icon: Icon(Icons.something), ...) at minimum.
  final Widget icon;
  final String label;
  final Color? labelColor;
  final bool showDivider;
  final VoidCallback onTap;
  final Widget? trailing;

  const MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.labelColor,
    this.showDivider = true,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabelColor = labelColor ?? const Color(0xFF1A1A1A);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Montserrat",
                          color:
                              labelColor ??
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    trailing ??
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
