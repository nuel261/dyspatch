import 'package:dyspatch_app/Features/onboarding/utils/phone_input.dart';
import 'dart:convert';

import 'package:dyspatch_app/core/api/api_client.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _u = Session.instance.user ?? const <String, dynamic>{};
  late final _firstNameController = TextEditingController(text: (_u['first_name'] ?? '') as String);
  late final _lastNameController = TextEditingController(text: (_u['last_name'] ?? '') as String);
  late final _emailController = TextEditingController(text: (_u['email'] ?? '') as String);
  late final _addressController = TextEditingController(text: (_u['address'] ?? '') as String);
  String _phoneNumber = '';
  bool _phoneValid = false;
  bool _saving = false;
  String? _avatarUrl;
  String? _avatarData; // base64 data URI for upload

  @override
  void initState() {
    super.initState();
    _avatarUrl = _u['avatar'] as String?;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarData = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<String?> _askCode(String phone) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify new number', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the 4-digit code sent to $phone', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13)),
          TextField(controller: c, keyboardType: TextInputType.number, maxLength: 6, autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Verify', style: TextStyle(color: Color(0xFF298341)))),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final body = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      if (_avatarData != null) 'avatar': _avatarData,
      if (_phoneValid && _phoneNumber != _u['phone']) 'phone': _phoneNumber,
    };
    setState(() => _saving = true);
    try {
      try {
        await DyspatchApi.updateMe(body);
      } on ApiException catch (e) {
        if (e.status != 428) rethrow;
        // Changing phone number: the server sent an OTP to the new number.
        final code = await _askCode(_phoneNumber);
        if (code == null || code.isEmpty) return;
        await DyspatchApi.updateMe({...body, 'phone_code': code});
      }
      if (!mounted) return;
      toast(context, 'Profile updated');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                        color: const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Edit profile",
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
            SizedBox(height: 40),
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
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _avatarData != null
                                    ? MemoryImage(base64Decode(_avatarData!.split(',').last))
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: _avatarData == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 44, color: Color(0xFF298341))
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickPhoto,
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

                    // ── Address ───────────────────────────────────────
                    const _FieldLabel(label: "Address"),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _addressController,
                      hint: "e.g. Airport Road, Benin City",
                    ),

                    const SizedBox(height: 20),

                    // ── Phone ─────────────────────────────────────────
                    const _FieldLabel(label: "Phone number"),
                    const SizedBox(height: 4),
                    Text(
                      _u['phone'] != null ? 'Current: ${_u['phone']} — enter a new number to change it' : 'Add a phone number for delivery updates',
                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Color(0xFF5F6368)),
                    ),
                    const SizedBox(height: 8),
                    CustomPhoneInput(
                      onPhoneChanged: (phone, isValid) {
                        setState(() {
                          _phoneNumber = phone;
                          _phoneValid = isValid;
                        });
                      },
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: "Montserrat",
        color: Color(0xFF1A1A1A),
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
      style: const TextStyle(
        fontSize: 14,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
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
        fillColor: Colors.white,
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

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedFlag;
  final String selectedCode;
  final List<Map<String, String>> countryCodes;
  final void Function(String flag, String code) onCountryChanged;

  const _PhoneField({
    required this.controller,
    required this.selectedFlag,
    required this.selectedCode,
    required this.countryCodes,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          // Country picker
          GestureDetector(
            onTap: () async {
              final result = await showModalBottomSheet<Map<String, String>>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => _CountryPickerSheet(
                  countryCodes: countryCodes,
                  selectedCode: selectedCode,
                ),
              );
              if (result != null) {
                onCountryChanged(result['flag']!, result['code']!);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1D5E2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(selectedFlag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Country code text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              selectedCode,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),

          // Divider
          Container(width: 1, height: 24, color: const Color(0xFFE0E0E0)),

          // Phone input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 14,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
              decoration: const InputDecoration(
                hintText: "Enter Mobile number",
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFBDBDBD),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final List<Map<String, String>> countryCodes;
  final String selectedCode;

  const _CountryPickerSheet({
    required this.countryCodes,
    required this.selectedCode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select country",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 16),
          ...countryCodes.map(
            (c) => ListTile(
              leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
              title: Text(
                c['name']!,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Text(
                c['code']!,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Color(0xFF5F6368),
                ),
              ),
              selected: c['code'] == selectedCode,
              selectedColor: const Color(0xFF1D5E2E),
              onTap: () => Navigator.pop(context, c),
            ),
          ),
        ],
      ),
    );
  }
}
