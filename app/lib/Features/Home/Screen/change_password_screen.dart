import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrent = false;
  bool _saving = false;
  // Accounts created with phone OTP / Google have no password until they set one.
  final bool _hasPassword = Session.instance.user?['has_password'] == true;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if ((_hasPassword && current.isEmpty) || newPass.isEmpty || confirm.isEmpty) {
      _showSnack("Please fill in all fields");
      return;
    }
    if (newPass != confirm) {
      _showSnack("Passwords do not match");
      return;
    }
    if (newPass.length < 8) {
      _showSnack("Password must be at least 8 characters");
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await DyspatchApi.changePassword(current, newPass);
      await Session.instance.updateUser({'has_password': true});
      if (!mounted) return;
      _showSnack("Password updated successfully");
      Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Password",
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

            // ── Form ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    if (!_hasPassword)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text("You sign in with a one-time code. Set a password as an extra security option.",
                            style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Color(0xFF5F6368))),
                      ),
                    if (_hasPassword) _PasswordField(
                      label: "Current Password *",
                      hint: "Enter current password",
                      controller: _currentPasswordController,
                      showPassword: _showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                    ),

                    if (_hasPassword) const SizedBox(height: 20),

                    _PasswordField(
                      label: "New Password *",
                      hint: "Enter new password",
                      controller: _newPasswordController,
                      showPassword: _showNew,
                      onToggle: () => setState(() => _showNew = !_showNew),
                    ),

                    const SizedBox(height: 20),

                    _PasswordField(
                      label: "Confirm New Password *",
                      hint: "Confirm new password",
                      controller: _confirmPasswordController,
                      showPassword: _showConfirm,
                      onToggle: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),

                    const SizedBox(height: 40),

                    // ── Update button ─────────────────────────────────
                    Center(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5E2E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Update password",
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
// Reusable password field
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool showPassword;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.showPassword,
    required this.onToggle,
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
          obscureText: !showPassword,
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
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                showPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: const Color(0xFF9E9E9E),
              ),
            ),
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
