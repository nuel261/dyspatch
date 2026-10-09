import 'package:dyspatch_app/Features/Home/Screen/top_up_pending_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  bool _balanceVisible = true;
  bool _submitting = false;

  // ── Loaded from the backend (bank details are set in Admin → Settings) ──
  String _bankName = "…";
  String _accountName = "…";
  String _accountNumber = "…";
  String _topUpId = "…";
  String _balance = "₦ …";
  bool _ready = false;
  String? _error;
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([DyspatchApi.startTopup(), DyspatchApi.wallet()]);
      final t = r[0];
      final bank = Map<String, dynamic>.from(t['bank'] ?? {});
      if (!mounted) return;
      setState(() {
        _bankName = (bank['bank_name'] ?? '') as String;
        _accountName = (bank['account_name'] ?? '') as String;
        _accountNumber = (bank['account_number'] ?? '') as String;
        _topUpId = (t['reference'] ?? '') as String;
        _balance = naira(r[1]['balance_kobo'], decimals: true);
        _ready = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$label copied",
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _handleSentMoney() async {
    if (!_ready) {
      _load();
      return;
    }
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How much did you send?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17)),
        content: TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₦ ', hintText: 'e.g. 10,000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _amountController.text),
            child: const Text('Confirm', style: TextStyle(color: Color(0xFF298341), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (amount == null) return;
    setState(() => _submitting = true);
    try {
      await DyspatchApi.topupSent(_topUpId, amountKobo: toKobo(amount));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => PendingConfirmationScreen(reference: _topUpId)));
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Top-up",
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

            // ── Scrollable content (everything except the button) ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // ── Balance ───────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "CURRENT BALANCE",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F6368),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _balanceVisible ? _balance : "₦ ••••••",
                                style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _balanceVisible = !_balanceVisible,
                                ),
                                child: Icon(
                                  _balanceVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Bank info section ────────────────────────
                    const Text(
                      "BANK INFO",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5F6368),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _InfoBlock(label: "Bank name", value: _bankName),
                    const SizedBox(height: 16),
                    _InfoBlock(label: "Account name", value: _accountName),
                    const SizedBox(height: 16),

                    const Text(
                      "Account number",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Montserrat",
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CopyField(
                      value: _accountNumber,
                      onCopy: () => _copy(_accountNumber, "Account number"),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Top-up ID",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Montserrat",
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CopyField(
                      value: _topUpId,
                      onCopy: () => _copy(_topUpId, "Top-up ID"),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        "Note: Please ensure that you paste your Top-up ID in the narration field whenever you make a transfer.",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: _load,
                          child: Text('$_error  ·  Tap to retry', style: const TextStyle(color: Colors.red, fontFamily: 'Montserrat', fontSize: 12)),
                        ),
                      ),
                    // Small bottom padding so the last note isn't flush
                    // against the pinned button area.
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Confirm button — pinned to the bottom, outside the
            //     scroll view, so it never moves while scrolling ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleSentMoney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF298341),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "I've sent the money",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                          ),
                        ),
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
// Plain label/value block (no copy button) — bank name, account name
// ─────────────────────────────────────────────────────────────────────────

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: "Montserrat",
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Field with a copy icon — account number, top-up ID
// ─────────────────────────────────────────────────────────────────────────

class _CopyField extends StatelessWidget {
  final String value;
  final VoidCallback onCopy;

  const _CopyField({required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: "Montserrat",
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            child: Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
