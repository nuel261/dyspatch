import 'dart:io';

import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/document_capture_screen.dart';
import 'package:flutter/material.dart';

class RideDetailsScreen extends StatefulWidget {
  const RideDetailsScreen({super.key});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final _plateNumberController = TextEditingController();
  final _rideBrandController = TextEditingController();
  final _rideModelController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _businessAddressController = TextEditingController();

  File? _governmentIdImage;
  File? _businessCertificateImage;

  static const List<String> _rideTypes = [
    "Motorbike",
    "Car",
    "Pickup Truck",
    "Truck",
  ];
  String _selectedRideType = "Motorbike";

  @override
  void dispose() {
    _plateNumberController.dispose();
    _rideBrandController.dispose();
    _rideModelController.dispose();
    _businessNameController.dispose();
    _regNumberController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  Future<File?> _captureDocument(String title, File? current) {
    return Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCaptureScreen(
          title: title,
          documentName: title,
          initialImage: current,
        ),
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
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Ride details",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Form ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(label: "Plate number", required: true),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _plateNumberController,
                      hint: "e.g. ABC-123DE",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(label: "Ride type", required: true),
                    const SizedBox(height: 8),
                    _RideTypeDropdown(
                      value: _selectedRideType,
                      options: _rideTypes,
                      onChanged: (value) {
                        setState(() => _selectedRideType = value);
                      },
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(label: "Ride brand", required: true),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _rideBrandController,
                      hint: "e.g. Airport Road",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(label: "Ride model", required: true),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _rideModelController,
                      hint: "e.g. Airport Road",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(label: "Business name", required: true),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _businessNameController,
                      hint: "e.g. Iya Bose Restaurant",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(
                      label: "Business registration number",
                      required: true,
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _regNumberController,
                      hint: "e.g. 774T9X0KG",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(
                      label: "Business address",
                      required: true,
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _businessAddressController,
                      hint: "e.g. Ring Road",
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(
                      label: "Upload government ID",
                      required: true,
                    ),
                    const SizedBox(height: 8),
                    _DocumentUploadBox(
                      image: _governmentIdImage,
                      description:
                          "We only accept Driver's license, NIN Card,\nand the Nigerian International passport",
                      onTap: () async {
                        final file = await _captureDocument(
                          "Government ID",
                          _governmentIdImage,
                        );
                        if (file != null) {
                          setState(() => _governmentIdImage = file);
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    const _FieldLabel(
                      label: "Upload business certificate",
                      required: true,
                    ),
                    const SizedBox(height: 8),
                    _DocumentUploadBox(
                      image: _businessCertificateImage,
                      description:
                          "Upload a clear photo of your business\nregistration certificate",
                      onTap: () async {
                        final file = await _captureDocument(
                          "Business certificate",
                          _businessCertificateImage,
                        );
                        if (file != null) {
                          setState(() => _businessCertificateImage = file);
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    // ── Save ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: send the ride + business details and the
                          // document photos to the API once it exists. For
                          // now just return to Ride verification.
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          // #34A853 in both light and dark mode.
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                          ),
                        ),
                      ),
                    ),

                    // Extra room so the button can scroll clear of the
                    // floating nav bar.
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: "Montserrat",
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        children: required
            ? const [
                TextSpan(
                  text: " *",
                  style: TextStyle(color: Color(0xFFD32F2F)),
                ),
              ]
            : null,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 14,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.inversePrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w400,
          color: Color(0xFFBDBDBD),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.primary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1D5E2E), width: 1.5),
        ),
      ),
    );
  }
}

// Ride type picker matching the mockup: a grey field with a chevron that
// expands inline (pushing the fields below down) to list the other options.
// Built by hand rather than with DropdownButton, whose popup takes its
// background from colorScheme.surface — green in the light theme.
class _RideTypeDropdown extends StatefulWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _RideTypeDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_RideTypeDropdown> createState() => _RideTypeDropdownState();
}

class _RideTypeDropdownState extends State<_RideTypeDropdown> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // #F5F5F5 in light mode, #1A1A1A in dark mode.
    final fill = colors.secondary;
    final otherOptions = widget.options.where((o) => o != widget.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isOpen = !_isOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                        color: colors.inversePrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_isOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Material(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: otherOptions
                            .map(
                              (option) => InkWell(
                                onTap: () {
                                  setState(() => _isOpen = false);
                                  widget.onChanged(option);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.w400,
                                      color: colors.inversePrimary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// Dashed upload box from the 6c design. Opens the full-screen capture
// screen; once a photo exists it shows a thumbnail instead.
class _DocumentUploadBox extends StatelessWidget {
  final File? image;
  final String description;
  final VoidCallback onTap;

  const _DocumentUploadBox({
    required this.image,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // #34A853 in both light and dark mode.
    final green = colors.onSecondaryContainer;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const DashedBorderPainter(color: Color(0xFFD0D5DD)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
                    Text(
                      "Tap to change photo",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                        color: green,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        height: 1.5,
                        color: colors.inversePrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green.withValues(alpha: 0.12),
                        foregroundColor: green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Take photo",
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
