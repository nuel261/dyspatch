import 'dart:async';

import 'package:dyspatch_rider/Features/Home/widget/app_bottom_sheet.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
import 'package:dyspatch_rider/core/ui/format.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Earning/add_account_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Earning/wallet_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EarningScreen extends StatefulWidget {
  /// Set when shown as a Home tab: back goes to the Home tab.
  final VoidCallback? onBack;
  const EarningScreen({super.key, this.onBack});

  @override
  State<EarningScreen> createState() => _EarningScreenState();
}

class _EarningScreenState extends State<EarningScreen> {
  bool _balanceVisible = true;

  Map<String, dynamic>? _wallet;
  int? _accountId; // account used for withdrawals
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    RiderState.instance.refresh();
  }

  Future<void> _load() async {
    try {
      final w = await RiderApi.wallet();
      if (!mounted) return;
      setState(() {
        _wallet = w;
        final accs = _accounts;
        if (_accountId == null || !accs.any((a) => a['id'] == _accountId)) {
          final def = accs.where((a) => a['is_default'] == true).toList();
          _accountId = (def.isNotEmpty ? def.first : (accs.isNotEmpty ? accs.first : null))?['id'] as int?;
        }
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _accounts =>
      ((_wallet?['bank_accounts'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Map<String, dynamic>? get _account {
    for (final a in _accounts) {
      if (a['id'] == _accountId) return a;
    }
    return null;
  }

  int get _balanceKobo => (_wallet?['balance_kobo'] as num?)?.toInt() ?? RiderState.instance.walletKobo;

  Future<void> _changeAccount() async {
    final accs = _accounts;
    if (accs.length < 2) {
      showSnack(context, accs.isEmpty ? 'Add a bank account first.' : 'You have one account. Tap "Add" to add another.');
      return;
    }
    final picked = await showAppBottomSheet<int>(
      context: context,
      title: 'Choose account',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in accs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                a['id'] == _accountId ? Icons.radio_button_checked : Icons.radio_button_off,
                color: const Color(0xFF298341),
              ),
              title: Text('${a['bank_name']}', style: AppBottomSheetStyle.optionStyle),
              subtitle: Text('${a['account_name']} · ${a['account_number']}', style: AppBottomSheetStyle.subtitleStyle),
              onTap: () => Navigator.pop(context, a['id'] as int),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _accountId = picked);
  }

  Future<void> _withdraw() async {
    if (_account == null) {
      showSnack(context, 'Add a bank account to withdraw to.', error: true);
      return;
    }
    final done = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      title: 'Withdraw',
      child: _WithdrawSheet(
        balanceKobo: _balanceKobo,
        minKobo: (_wallet?['withdrawal_min_kobo'] as num?)?.toInt() ?? 50000,
        account: _account!,
      ),
    );
    if (done == true) {
      _load();
      RiderState.instance.refresh();
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
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onBack != null ? widget.onBack!() : Navigator.maybePop(context),
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
                        "Wallet",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalletHistoryScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF298341)),

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
                                _balanceVisible ? naira(_balanceKobo, decimals: true) : "₦ ••••••",
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
                          const SizedBox(height: 10),
                          // ── Orders Received / Delivered ──
                          Text(
                            "Order Received: ${RiderState.instance.me?['total_jobs'] ?? 0}  •  Order Delivered: ${RiderState.instance.me?['total_deliveries'] ?? 0}",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                          if ((_wallet?['pending_withdrawals'] as num? ?? 0) > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_wallet!['pending_withdrawals']} withdrawal(s) processing',
                              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Color(0xFFB88704)),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _withdraw,
                              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                              label: const Text('Withdraw', style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF298341),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Account label ────────────────────────────────
                    Text(
                      _account == null ? "No bank account yet" : "Account ${_accounts.indexWhere((a) => a['id'] == _accountId) + 1}",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Bank card ────────────────────────────────────
                    _BankCard(account: _account),

                    const SizedBox(height: 20),

                    // ── Change Account / Add ────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _changeAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF298341,
                              ).withOpacity(0.10),
                              foregroundColor: const Color(0xFF298341),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Change Account",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddAccountScreen(),
                                ),
                              );
                              _load();
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              "Add",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF298341),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
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
// Bank card
// ─────────────────────────────────────────────────────────────────────────────

class _BankCard extends StatelessWidget {
  final Map<String, dynamic>? account;
  const _BankCard({this.account});

  @override
  Widget build(BuildContext context) {
    final a = account;
    final number = (a?['account_number'] ?? '').toString();
    final spaced = number.length == 10 ? '${number.substring(0, 3)}  ${number.substring(3, 7)}  ${number.substring(7)}' : number;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CA661), Color(0xFF0E2E18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a == null ? 'Add your bank account' : '${a['bank_name']}',
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            a == null ? 'Your earnings are paid out here' : '${a['account_name']}'.toUpperCase(),
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: number.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: number));
                    showSnack(context, 'Account number copied');
                  },
            child: Text(
              number.isEmpty ? '•••  ••••  •••' : spaced,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount → live fee quote → confirm. Pops true once the request is placed.
class _WithdrawSheet extends StatefulWidget {
  final int balanceKobo;
  final int minKobo;
  final Map<String, dynamic> account;
  const _WithdrawSheet({required this.balanceKobo, required this.minKobo, required this.account});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amount = TextEditingController();
  int? _feeKobo;
  bool _sending = false;
  Timer? _debounce;

  int get _kobo => toKobo(_amount.text);

  String? get _problem {
    if (_kobo == 0) return null;
    if (_kobo < widget.minKobo) return 'Minimum withdrawal is ${naira(widget.minKobo)}';
    if (_kobo + (_feeKobo ?? 0) > widget.balanceKobo) return 'Not enough balance (fee included)';
    return null;
  }

  void _onChanged(String _) {
    setState(() => _feeKobo = null);
    _debounce?.cancel();
    if (_kobo < widget.minKobo) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await RiderApi.withdrawalFee(_amount.text);
        if (mounted) setState(() => _feeKobo = (r['fee_kobo'] as num?)?.toInt() ?? 0);
      } catch (_) {}
    });
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final env = await RiderApi.withdraw(_amount.text, bankAccountId: widget.account['id'] as int?);
      if (!mounted) return;
      showSnack(context, (env['message'] as String?) ?? 'Withdrawal requested');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Available: ${naira(widget.balanceKobo, decimals: true)}', textAlign: TextAlign.center, style: AppBottomSheetStyle.subtitleStyle),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: _onChanged,
            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₦ ',
              hintText: '0.00',
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            problem ?? (_feeKobo == null ? 'To ${widget.account['bank_name']} · ${widget.account['account_number']}' : 'Fee ${naira(_feeKobo, decimals: true)} · You receive ${naira(_kobo, decimals: true)}'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: problem != null ? const Color(0xFFD32F2F) : const Color(0xFF5F6368)),
          ),
          const SizedBox(height: 16),
          Button(
            button_text: 'Withdraw ${_kobo > 0 ? naira(_kobo) : ''}',
            color: const Color(0xFF298341),
            textColor: Colors.white,
            loading: _sending,
            onTap: _kobo > 0 && problem == null && _feeKobo != null ? _submit : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
