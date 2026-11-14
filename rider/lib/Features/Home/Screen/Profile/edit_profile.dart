import 'dart:typed_data';

import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/api/session.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _firstNameController = TextEditingController(text: Session.instance.rider?['first_name'] as String? ?? '');
  final _lastNameController = TextEditingController(text: Session.instance.rider?['last_name'] as String? ?? '');
  final _emailController = TextEditingController(text: Session.instance.rider?['email'] as String? ?? '');
  final _phoneController = TextEditingController(text: Session.instance.rider?['phone'] as String? ?? '');
  bool _saving = false;

  Uint8List? _photo; // newly picked photo, uploaded on save
  String? get _currentPhoto {
    final p = Session.instance.rider?['photo'] as String?;
    return p == null || p.isEmpty ? null : p;
  }

  Future<void> _save() async {
    final first = _firstNameController.text.trim(), last = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    if (first.isEmpty || last.isEmpty) return showSnack(context, 'Enter your first and last name.', error: true);
    if (email.isNotEmpty && !email.contains('@')) return showSnack(context, 'Enter a valid email address.', error: true);
    setState(() => _saving = true);
    try {
      final updated = await RiderApi.updateMe({
        'first_name': first,
        'last_name': last,
        'email': email,
        if (_photo != null) 'photo': RiderApi.dataUri(_photo!),
      });
      await Session.instance.updateRider(updated);
      if (!mounted) return;
      showSnack(context, 'Profile updated');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
      final bytes = await picked.readAsBytes();
      setState(() => _photo = bytes);
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
                                  ? MemoryImage(_photo!)
                                  : (_currentPhoto == null ? null : NetworkImage(_currentPhoto!)) as ImageProvider?,
                              child: _photo == null && _currentPhoto == null
                                  ? Icon(Icons.person_outline, size: 50, color: Colors.grey.shade400)
                                  : null,
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
                    // Your sign-in number. Contact support to change it.
                    _InputField(
                      controller: _phoneController,
                      hint: '',
                      readOnly: true,
                    ),

                    const SizedBox(height: 40),

                    // ── Save button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5E2E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                            : const Text(
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
  final bool readOnly;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
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
