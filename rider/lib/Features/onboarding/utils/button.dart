import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String button_text;
  final Color color;
  final void Function()? onTap;
  // Optional explicit text color. When null, falls back to the original
  // behavior (white on the primary green, green otherwise) so every
  // existing call site keeps working unchanged.
  final Color? textColor;
  // Shows a small spinner instead of the label and ignores taps.
  final bool loading;

  const Button({
    super.key,
    required this.button_text,
    required this.color,
    this.onTap,
    this.textColor,
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: textColor ?? Colors.white,
                  ),
                )
              : Text(
            button_text,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  textColor ??
                  (color == const Color(0xFF298341)
                      ? Colors.white
                      : const Color(0xFF298341)),
              height: 20 / 14, // 1.429
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
