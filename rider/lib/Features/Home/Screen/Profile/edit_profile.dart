import 'dart:io';

import 'package:dyspatch_rider/Features/onboarding/utils/phone_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _firstNameController = TextEditingController(text: '');
  final _lastNameController = TextEditingController(text: '');
  final _emailController = TextEditingController(text: '');
  String _phoneNumber = '';

  File? _photo;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── Photo picking ───────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800, // keeps the upload small
        imageQuality: 80,
      );
      if (picked == null) return; // user cancelled
      setState(() => _photo = File(picked.path));
    } on PlatformException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permission denied. Allow access in your phone settings.',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
        ),
      );
    }
  }

  void _showPhotoOptions() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget option(
          IconData icon,
          String label,
          VoidCallback onTap, {
          Color? color,
        }) {
          final c = color ?? colors.inversePrimary;
          return ListTile(
            leading: Icon(icon, color: c),
            title: Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(
                  Icons.photo_camera_outlined,
                  'Take photo',
                  () => _pickImage(ImageSource.camera),
                ),
                option(
                  Icons.photo_library_outlined,
                  'Choose from gallery',
                  () => _pickImage(ImageSource.gallery),
                ),
                if (_photo != null)
                  option(
                    Icons.delete_outline,
                    'Remove photo',
                    () => setState(() => _photo = null),
                    color: const Color(0xFFD32F2F),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: colors.inversePrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Edit profile",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                          color: colors.inversePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + Change Photo
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: colors.surfaceContainerHighest,
                              backgroundImage: _photo != null
                                  ? FileImage(_photo!)
                                  : const NetworkImage(
                                          'https://picsum.photos/200',
                                        )
                                        as ImageProvider,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "Change Photo",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: "Montserrat",
                                    color: Color(0xFF1D5E2E),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF1D5E2E),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Color(0xFF1D5E2E),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Name ─────────────────────────────────────────
                    const _FieldLabel(label: "Name"),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _firstNameController,
                      hint: "First name",
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      controller: _lastNameController,
                      hint: "Second name",
                    ),

                    const SizedBox(height: 20),

                    // ── Email ─────────────────────────────────────────
                    const _FieldLabel(label: "Email Address"),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _emailController,
                      hint: "e.g. dyspatch@gmail.com",
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 20),

                    // ── Phone ─────────────────────────────────────────
                    const _FieldLabel(label: "Phone number"),
                    const SizedBox(height: 8),
                    CustomPhoneInput(
                      onPhoneChanged: (phone, isValid) {
                        setState(() => _phoneNumber = phone);
                      },
                    ),

                    const SizedBox(height: 40),

                    // ── Save button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: send to backend — _photo (multipart),
                          // names, email and _phoneNumber.
                          debugPrint(
                            'Save: ${_firstNameController.text} '
                            '${_lastNameController.text}, '
                            '${_emailController.text}, $_phoneNumber, '
                            'photo: ${_photo?.path}',
                          );
                        },
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
                          "Save changes",
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: "Montserrat",
        color: Theme.of(context).colorScheme.inversePrimary,
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
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 14,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w500,
        color: colors.inversePrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w400,
          color: colors.inversePrimary.withOpacity(0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: colors.primary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colors.inversePrimary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1D5E2E), width: 1.5),
        ),
      ),
    );
  }
}
