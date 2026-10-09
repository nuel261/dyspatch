import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class MyBottomNav extends StatelessWidget {
  final Function(int)? onTabChange;
  const MyBottomNav({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: GNav(
        color: Theme.of(context).colorScheme.inversePrimary,
        tabMargin: EdgeInsetsGeometry.only(bottom: 12),
        mainAxisAlignment: MainAxisAlignment.center,
        activeColor: Theme.of(context).colorScheme.primary,
        tabBorderRadius: 16,
        tabBackgroundColor: Theme.of(context).colorScheme.inversePrimary,
        onTabChange: (value) => onTabChange!(value),
        tabs: [
          GButton(icon: Icons.book, text: "Note"),
          GButton(icon: Icons.edit, text: "Todo"),
        ],
      ),
    );
  }
}
