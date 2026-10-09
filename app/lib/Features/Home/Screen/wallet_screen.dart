import 'package:dyspatch_app/Features/Home/Screen/add_account_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/topup_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/transfer_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/wallet_history_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TxType { credit, debit }

class Transaction {
  final String title;
  final String subtitle;
  final double amount; // naira, signed
  final String date;
  final TxType type;

  const Transaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final credit = j['type'] == 'credit';
    final kobo = (j['amount_kobo'] as num?)?.toInt() ?? 0;
    final track = j['track_id'] as String?;
    return Transaction(
      title: (j['title'] ?? '') as String,
      subtitle: track != null ? 'Order $track' : ((j['description'] ?? j['reference'] ?? '') as String),
      amount: (credit ? kobo : -kobo) / 100,
      date: dayTime(parseTime(j['created_at'])),
      type: credit ? TxType.credit : TxType.debit,
    );
  }
}

class WalletScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const WalletScreen({super.key, this.onBack});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _balanceVisible = true;

  List<Transaction> _transactions = [];
  List<Map<String, dynamic>> _accounts = [];
  int _balanceKobo = 0;
  bool _loading = true;
  String? _error;

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
        _accounts = List<Map<String, dynamic>>.from(w['bank_accounts'] ?? const []);
        _transactions = ((w['recent_transactions'] as List?) ?? const [])
            .map((t) => Transaction.fromJson(Map<String, dynamic>.from(t)))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _changeAccount() async {
    if (_accounts.length < 2) {
      toast(context, _accounts.isEmpty ? 'Add a bank account first' : 'Add another account to switch between them');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _accounts
              .map((a) => ListTile(
                    leading: Icon(a['is_default'] == true ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF298341)),
                    title: Text('${a['bank_name']}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                    subtitle: Text('${a['account_name']} · ${a['account_number']}', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                    onTap: () => Navigator.pop(ctx, a),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await DyspatchApi.setDefaultBank((picked['id'] as num).toInt());
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
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
                    onTap: () => _go(const WalletHistoryScreen()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.history_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF298341),
                onRefresh: _load,
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

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

                                  decorationThickness: 1.6,
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

                    const SizedBox(height: 24),

                    // ── Action buttons ──────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _go(const TopUpScreen()),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 16,
                            ),
                            label: const Text(
                              "Top-up",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF298341),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _go(const TransferScreen()),
                            icon: const Icon(
                              Icons.sync_alt_rounded,
                              size: 16,
                              color: Color(0xFF298341),
                            ),
                            label: const Text(
                              "Transfer",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF298341),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF298341,
                              ).withOpacity(0.10),
                              foregroundColor: const Color(0xFF298341),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Account label ────────────────────────────────
                    Text(
                      _accounts.isEmpty ? "Payout account" : "Account ${_accounts.indexWhere((a) => a['is_default'] == true) + 1}",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Bank card ────────────────────────────────────
                    _BankCard(account: _accounts.isEmpty ? null : _accounts.firstWhere((a) => a['is_default'] == true, orElse: () => _accounts.first)),

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
                            onPressed: () => _go(const AddAccountScreen()),
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

                    // ── Recent Transactions ─────────────────────────
                    const Text(
                      "Recent Transactions",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _transactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(_loading ? 'Loading…' : (_error ?? 'No transactions yet'),
                                    style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, color: Color(0xFF5F6368))),
                              ),
                            )
                          : Column(
                        children: List.generate(_transactions.length, (i) {
                          final tx = _transactions[i];
                          final isLast = i == _transactions.length - 1;
                          return _TransactionTile(tx: tx, showDivider: !isLast);
                        }),
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction tile
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final bool showDivider;

  const _TransactionTile({required this.tx, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == TxType.credit;
    final amountStr =
        '${isCredit ? '+' : '-'}₦${tx.amount.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isCredit
                      ? const Color(0xFF298341).withOpacity(0.12)
                      : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18,
                  color: isCredit ? const Color(0xFF298341) : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.subtitle,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountStr,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCredit
                          ? const Color(0xFF298341)
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tx.date,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 10,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 70,
            endIndent: 16,
            color: Color(0x1A000000),
          ),
      ],
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
    final number = (a?['account_number'] ?? '') as String;
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
          Row(children: [
            Expanded(
              child: Text(
                a == null ? "No payout account yet" : (a['bank_name'] ?? '') as String,
                style: const TextStyle(fontFamily: "Montserrat", fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            if (a != null && a['is_verified'] == true) const Icon(Icons.verified, color: Colors.white, size: 16),
          ]),
          const SizedBox(height: 22),
          Text(
            a == null ? "Tap “Add” to save the account you withdraw to" : (a['account_name'] ?? '') as String,
            style: const TextStyle(fontFamily: "Montserrat", fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          if (a != null)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: number));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number copied')));
              },
              child: Text(
                spaced,
                style: const TextStyle(fontFamily: "Montserrat", fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
