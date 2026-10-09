import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  final String label;
  
  const SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style:  TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: "Montserrat",
        color: Theme.of(context).colorScheme.onTertiaryContainer,
        letterSpacing: 0.8,
      ),
    );
  }
}