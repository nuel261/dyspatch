import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:flutter/material.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _bankNameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  bool _submitting = false;
  List<Map<String, dynamic>> _banks = [];
  String? _bankCode;

  @override
  void initState() {
    super.initState();
    DyspatchApi.banks().then((b) {
      if (mounted) setState(() => _banks = b);
    }).catchError((_) {});
  }

  Future<void> _pickBank() async {
    if (_banks.isEmpty) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: ListView(
          children: _banks
              .map((b) => ListTile(
                    title: Text((b['name'] ?? '') as String, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14)),
                    onTap: () => Navigator.pop(ctx, b),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _bankNameController.text = picked['name'] as String;
        _bankCode = picked['code'] as String?;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final bankName = _bankNameController.text.trim();
    final accountName = _accountNameController.text.trim();
    final accountNumber = _accountNumberController.text.replaceAll(RegExp(r'\D'), '');

    if (bankName.isEmpty || accountName.isEmpty || accountNumber.isEmpty) {
      _showSnack("Please fill in all fields");
      return;
    }
    if (accountNumber.length != 10) {
      _showSnack("Enter a valid 10-digit account number");
      return;
    }
    final match = _banks.where((b) => (b['name'] as String).toLowerCase() == bankName.toLowerCase());
    final code = _bankCode ?? (match.isNotEmpty ? match.first['code'] as String? : null);
    setState(() => _submitting = true);
    try {
      final r = await DyspatchApi.addBankAccount(bankName, accountName, accountNumber, bankCode: code);
      if (!mounted) return;
      _showSnack((r['message'] as String?) ?? "Account saved");
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                        "Add Account",
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

                    _LabeledField(
                      label: "Bank name *",
                      hint: "e.g. Guaranty Trust Bank",
                      controller: _bankNameController,
                    ),
                    if (_banks.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _pickBank,
                          child: const Text('Choose from list', style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF298341), fontWeight: FontWeight.w600)),
                        ),
                      ),

                    const SizedBox(height: 20),

                    _LabeledField(
                      label: "Account name *",
                      hint: "e.g. Dan-John Chibuzor Daniel",
                      controller: _accountNameController,
                    ),

                    const SizedBox(height: 20),

                    _LabeledField(
                      label: "Account number *",
                      hint: "e.g. 3124209490",
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        "Verification usually takes less than 2 hours.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Submit button ─────────────────────────────────
                    Center(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _handleSubmit,
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
                          "Submit & Verify",
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
// Reusable labeled text field
// ─────────────────────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
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
              vertical: 16,
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
