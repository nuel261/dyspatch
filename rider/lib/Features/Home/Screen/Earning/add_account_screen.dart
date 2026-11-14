import 'package:dyspatch_rider/Features/Home/widget/app_bottom_sheet.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Earning/add_account_sucess_screen.dart';
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
  String? _bankCode;
  List<Map<String, dynamic>> _banks = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    RiderApi.banks().then((b) {
      if (mounted) setState(() => _banks = b);
    }).catchError((_) {});
  }

  Future<void> _pickBank() async {
    if (_banks.isEmpty) return; // no list: the field stays typeable
    final picked = await showAppBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      title: 'Select bank',
      child: _BankPicker(banks: _banks),
    );
    if (picked != null) {
      setState(() {
        _bankNameController.text = '${picked['name']}';
        _bankCode = picked['code']?.toString();
      });
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final bankName = _bankNameController.text;
    final accountName = _accountNameController.text;
    final accountNumber = _accountNumberController.text;

    if (bankName.isEmpty || accountName.isEmpty || accountNumber.isEmpty) {
      _showSnack("Please fill in all fields");
      return;
    }
    if (accountNumber.length < 10) {
      _showSnack("Enter a valid account number");
      return;
    }
    setState(() => _saving = true);
    try {
      await RiderApi.addBankAccount(
        bankName: bankName.trim(),
        bankCode: _bankCode,
        accountNumber: accountNumber.trim(),
        accountName: accountName.trim(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(errorText(e));
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AddAccountSuccessScreen()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
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
                      readOnly: _banks.isNotEmpty,
                      onTap: _pickBank,
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
                      maxLength: 10,
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
                        onPressed: _saving ? null : _handleSubmit,
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
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                            : const Text(
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
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLength;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          maxLength: maxLength,
          style: TextStyle(
            fontSize: 14,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            suffixIcon: readOnly ? const Icon(Icons.keyboard_arrow_down_rounded) : null,
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
            fillColor: Theme.of(context).colorScheme.primary,
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

class _BankPicker extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  const _BankPicker({required this.banks});

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.banks.where((b) => '${b['name']}'.toLowerCase().contains(_q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search banks',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text('${list[i]['name']}', style: AppBottomSheetStyle.optionStyle),
                onTap: () => Navigator.pop(context, list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
