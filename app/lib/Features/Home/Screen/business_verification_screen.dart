import 'dart:convert';
import 'dart:io';

import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BusinessVerificationScreen extends StatefulWidget {
  const BusinessVerificationScreen({super.key});

  @override
  State<BusinessVerificationScreen> createState() =>
      _BusinessVerificationScreenState();
}

class _BusinessVerificationScreenState
    extends State<BusinessVerificationScreen> {
  bool _started = false;

  final _businessNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _addressController = TextEditingController();

  File? _governmentIdImage;
  bool _submitting = false;
  Map<String, dynamic>? _existing;

  @override
  void initState() {
    super.initState();
    DyspatchApi.businessVerification().then((v) {
      if (mounted) setState(() => _existing = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _regNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (picked != null) {
      setState(() => _governmentIdImage = File(picked.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked != null) {
      setState(() => _governmentIdImage = File(picked.path));
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF1D5E2E),
                ),
                title: const Text(
                  "Take photo",
                  style: TextStyle(fontFamily: "Montserrat"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF1D5E2E),
                ),
                title: const Text(
                  "Choose from gallery",
                  style: TextStyle(fontFamily: "Montserrat"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final allFilled =
        _businessNameController.text.isNotEmpty &&
        _regNumberController.text.isNotEmpty &&
        _addressController.text.isNotEmpty &&
        _governmentIdImage != null;

    if (!allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Please fill in all fields and upload your ID",
            style: TextStyle(fontFamily: "Montserrat"),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final bytes = await _governmentIdImage!.readAsBytes();
      await DyspatchApi.submitBusinessVerification({
        'business_name': _businessNameController.text.trim(),
        'reg_number': _regNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'id_document': 'data:image/jpeg;base64,${base64Encode(bytes)}',
      });
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Submitted!",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          "Your business verification has been submitted. This usually takes less than 24 hours.",
          style: TextStyle(fontFamily: "Montserrat", fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Color(0xFF1D5E2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_started) {
                        setState(() => _started = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Business verification",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            SizedBox(height: 20),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _started
                    ? _VerificationForm(
                        businessNameController: _businessNameController,
                        regNumberController: _regNumberController,
                        addressController: _addressController,
                        governmentIdImage: _governmentIdImage,
                        onPhotoTap: _showPhotoOptions,
                        onSubmit: _submitting ? () {} : _handleSubmit,
                      )
                    : Column(children: [
                        if (_existing != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: (_existing!['status'] == 'verified' ? const Color(0xFF298341) : _existing!['status'] == 'rejected' ? Colors.red : const Color(0xFFF59E0B)).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _existing!['status'] == 'verified'
                                  ? '${_existing!['business_name']} is verified ✓'
                                  : _existing!['status'] == 'rejected'
                                      ? 'Your last submission was not approved${_existing!['note'] != null ? ': ${_existing!['note']}' : ''}. You can submit again.'
                                      : '${_existing!['business_name']} is under review. We\'ll notify you once it\'s done.',
                              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        if (_existing == null || _existing!['status'] == 'rejected')
                          _VerificationIntro(
                            onStart: () => setState(() => _started = true),
                          ),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intro
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationIntro extends StatelessWidget {
  final VoidCallback onStart;
  const _VerificationIntro({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          "Verify your business",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: "Montserrat",
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "To use delivery services, we need to confirm your business identity.\nVerification usually takes less than 24 hours.",
          style: TextStyle(
            fontSize: 13,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w400,
            color: Color(0xFF5F6368),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Required Information",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        ...[
          "Business name",
          "Business registration number",
          "Business address",
          "Government ID",
        ].map((item) => _CheckItem(label: item)),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D5E2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Start verification",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  const _CheckItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Color(0xFF1D5E2E)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w400,
              color: Color(0xFF5F6368),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationForm extends StatelessWidget {
  final TextEditingController businessNameController;
  final TextEditingController regNumberController;
  final TextEditingController addressController;
  final File? governmentIdImage;
  final VoidCallback onPhotoTap;
  final VoidCallback onSubmit;

  const _VerificationForm({
    required this.businessNameController,
    required this.regNumberController,
    required this.addressController,
    required this.governmentIdImage,
    required this.onPhotoTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        _FormField(
          label: "Business name*",
          hint: "e.g. Mama Nkechi Restaurant",
          controller: businessNameController,
        ),
        const SizedBox(height: 24),

        _FormField(
          label: "Business registration number*",
          hint: "e.g. Y6U788R3416",
          controller: regNumberController,
        ),
        const SizedBox(height: 24),

        _FormField(
          label: "Business address*",
          hint: "e.g. Airport Road",
          controller: addressController,
        ),
        const SizedBox(height: 24),

        const Text(
          "Upload government ID*",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),

        _GovernmentIdUpload(image: governmentIdImage, onTap: onPhotoTap),

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D5E2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Submit for verification",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Government ID upload box
// ─────────────────────────────────────────────────────────────────────────────

// ─── Dashed border painter ──────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const _DashedBorderPainter({
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

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
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
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.radius != radius;
}

// ─── Government ID upload box ───────────────────────────────────────────────

class _GovernmentIdUpload extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;

  const _GovernmentIdUpload({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: Color(0xFFD0D5DD),
          strokeWidth: 1.5,
          dashWidth: 8,
          dashSpace: 5,
          radius: 12,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            // ← no border here anymore; painter handles it
          ),
          child: image != null
              ? Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        image!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Tap to change photo",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        color: Color(0xFF1D5E2E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "We only accept Driver's license, NIN Card,\nand the Nigerian International passport",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5F6368),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text(
                        "Take photo",
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1D5E2E,
                        ).withOpacity(0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Reusable form field
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDBDBD),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1D5E2E),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
