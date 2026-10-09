import 'package:dyspatch_app/Features/Home/Screen/add_account_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool _balanceVisible = true;
  int _selectedAccount = 0; // 0 = Account 1, 1 = Account 2
  final _amountController = TextEditingController();

  static const List<int> _quickAmounts = [
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
  ];

  // Loaded from GET /wallet
  List<_AccountInfo> _accounts = const [];
  int _balanceKobo = 0;
  int _minKobo = 50000;
  bool _loading = true;
  bool _submitting = false;
  String _processing = "Before 5pm: paid today · after: next business day";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await DyspatchApi.wallet();
      if (!mounted) return;
      setState(() {
        _balanceKobo = (w['balance_kobo'] as num?)?.toInt() ?? 0;
        _minKobo = (w['withdrawal_min_kobo'] as num?)?.toInt() ?? 50000;
        _accounts = ((w['bank_accounts'] as List?) ?? const [])
            .map((b) => _AccountInfo(
                  id: (b['id'] as num).toInt(),
                  bank: (b['bank_name'] ?? '') as String,
                  name: (b['account_name'] ?? '') as String,
                  number: _spaced((b['account_number'] ?? '') as String),
                ))
            .toList();
        if (_selectedAccount >= _accounts.length) _selectedAccount = 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack(e.toString());
      }
    }
  }

  static String _spaced(String n) => n.length == 10 ? '${n.substring(0, 3)}  ${n.substring(3, 7)}  ${n.substring(7)}' : n;

  Future<void> _addAccount() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen()));
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  Future<void> _handleTransfer() async {
    if (_submitting) return;
    if (_accounts.isEmpty) {
      _addAccount();
      return;
    }
    final amount = toKobo(_amountController.text);
    if (amount <= 0) {
      _showSnack("Enter an amount");
      return;
    }
    if (amount < _minKobo) {
      _showSnack("Minimum withdrawal is ${naira(_minKobo)}");
      return;
    }
    setState(() => _submitting = true);
    try {
      final fee = await DyspatchApi.withdrawalFee(amount);
      final feeKobo = (fee['fee_kobo'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      final acct = _accounts[_selectedAccount];
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm transfer', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17)),
          content: Text(
            'Send ${naira(amount, decimals: true)} to ${acct.name} (${acct.bank}).\n\nFee: ${naira(feeKobo, decimals: true)}\nTotal from wallet: ${naira(amount + feeKobo, decimals: true)}',
            style: const TextStyle(fontFamily: 'Montserrat', height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer', style: TextStyle(color: Color(0xFF298341), fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (ok != true) return;
      final r = await DyspatchApi.withdraw(acct.id, amount);
      if (!mounted) return;
      _amountController.clear();
      _showSnack((r['message'] as String?) ?? "Transfer initiated");
      await _load();
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
    final cs = Theme.of(context).colorScheme;
    final account = _accounts.isEmpty ? null : _accounts[_selectedAccount];

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
                        "Transfer",
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

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

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
                                _balanceVisible ? (_loading ? "₦ …" : naira(_balanceKobo, decimals: true)) : "₦ ••••••",
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

                    const SizedBox(height: 28),

                    // ── Transfer to ───────────────────────────────
                    const Text(
                      "Transfer to:",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: List.generate(_accounts.length, (i) {
                        final isSelected = i == _selectedAccount;
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedAccount = i),
                            child: Text(
                              "Account ${i + 1}",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 14),

                    // ── Bank card ──────────────────────────────────
                    account == null
                        ? GestureDetector(
                            onTap: _addAccount,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF298341)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(_loading ? 'Loading accounts…' : '+ Add a bank account to transfer to',
                                  style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Color(0xFF298341))),
                            ),
                          )
                        : _TransferBankCard(account: account),

                    const SizedBox(height: 20),

                    // ── Amount + quick amounts panel ───────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF298341).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  "₦",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Processing time
                          Row(
                            children: [
                              Text(
                                _processing,
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Quick amounts grid
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.6,
                            children: _quickAmounts.map((amount) {
                              return GestureDetector(
                                onTap: () => _setQuickAmount(amount),
                                child: Center(
                                  child: Text(
                                    "₦${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}",
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Transfer button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleTransfer,
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
                          "Transfer",
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
// Account model + bank card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountInfo {
  final int id;
  final String bank;
  final String name;
  final String number;

  const _AccountInfo({
    required this.id,
    required this.bank,
    required this.name,
    required this.number,
  });
}

class _TransferBankCard extends StatelessWidget {
  final _AccountInfo account;

  const _TransferBankCard({required this.account});

  @override
  Widget build(BuildContext context) {
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
            account.bank,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            account.name,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            account.number,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
