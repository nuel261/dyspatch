import 'package:flutter/material.dart';

class ButtonContainer extends StatelessWidget {
  final String button_text;
  final Color color;
  final Color text_color;
  final void Function()? onTap;

  const ButtonContainer({
    super.key,
    required this.button_text,
    required this.text_color,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: Text(
            button_text,
            style: TextStyle(
              color: text_color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ),
    );
  }
}
