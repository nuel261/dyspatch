import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Full-screen photo capture for a verification document (Government ID,
/// Business certificate, ...). Pops with the captured [File], or null if
/// the rider backs out without taking a photo.
class DocumentCaptureScreen extends StatefulWidget {
  /// Shown in the top bar, e.g. "Government ID".
  final String title;

  /// Used in the consent line, e.g. "Government ID" →
  /// "...having access to your Government ID".
  final String documentName;

  /// Previously captured photo, shown so the rider can retake it.
  final File? initialImage;

  const DocumentCaptureScreen({
    super.key,
    required this.title,
    required this.documentName,
    this.initialImage,
  });

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  late File? _image = widget.initialImage;

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    setState(() => _image = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = _image != null;

    return Scaffold(
      backgroundColor: colors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          color: colors.inversePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  children: [
                    // ── Photo frame ──────────────────────────────────
                    CustomPaint(
                      painter: const DashedBorderPainter(
                        color: Color(0xFFD0D5DD),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 240,
                        child: hasImage
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_image!, fit: BoxFit.cover),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "By using this, you consent to Dyspatch having\naccess to your ${widget.documentName}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        height: 1.5,
                        color: colors.inversePrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Actions ──────────────────────────────────────
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: hasImage
                            ? () => Navigator.pop(context, _image)
                            : _takePhoto,
                        style: _greenButtonStyle(colors),
                        child: Text(
                          hasImage ? "Save" : "Take photo",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                          ),
                        ),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _takePhoto,
                        child: Text(
                          "Retake photo",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _greenButtonStyle(ColorScheme colors) => ElevatedButton.styleFrom(
    // #34A853 in both light and dark mode.
    backgroundColor: colors.onSecondaryContainer,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 0,
  );
}

/// Rounded dashed outline used by the document upload boxes.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 8,
    this.dashSpace = 5,
    this.radius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashSpace;
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.radius != radius;
}
