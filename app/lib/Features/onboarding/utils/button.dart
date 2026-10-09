import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String button_text;
  final Color color;
  final void Function()? onTap;
  final bool loading;

  const Button({
    super.key,
    required this.button_text,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: color == const Color(0xFF298341) ? Colors.white : const Color(0xFF298341),
                  ),
                )
              : Text(
            button_text,
            style: TextStyle(
              color: color == const Color(0xFF298341)
                  ? Colors.white
                  : const Color(0xFF298341),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ),
    );
  }
}
