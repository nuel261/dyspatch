import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/rider_api.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'bank_accounts_screen.dart';
import 'withdraw_screen.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});
  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>>? _tx;
  String? _error;
  int _lastDeliveries = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([RiderApi.wallet(), RiderApi.transactions()]);
      if (!mounted) return;
      setState(() {
        _wallet = r[0] as Map<String, dynamic>;
        _tx = r[1] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RiderState>();
    if (st.todayDeliveries != _lastDeliveries) {
      _lastDeliveries = st.todayDeliveries;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final bal = (_wallet?['balance_kobo'] as num?)?.toInt() ?? st.walletKobo;
    final pending = (_wallet?['pending_withdrawals'] as num?)?.toInt() ?? 0;
    final banks = ((_wallet?['bank_accounts'] as List?) ?? []).map((b) => Map<String, dynamic>.from(b as Map)).toList();
    return Scaffold(
      appBar: appBar(context, 'Earnings'),
      body: RefreshIndicator(
        color: brandGreen,
        onRefresh: () async {
          await _load();
          await st.refresh();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF298341), Color(0xFF1D5E2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wallet balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              const SizedBox(height: 6),
              Text(naira(bal, decimals: true), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
              if (pending > 0) ...[
                const SizedBox(height: 4),
                Text('${naira(pending)} being paid out', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _wallet == null
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawScreen(wallet: _wallet!))).then((_) => _load()),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    label: const Text('Withdraw'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandGreen, elevation: 0, minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())).then((_) => _load()),
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: Text(banks.isEmpty ? 'Add bank' : 'Banks (${banks.length})'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Montserrat')),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _mini(context, 'Today', naira(st.todayEarningsKobo))),
            const SizedBox(width: 10),
            Expanded(child: _mini(context, 'Deliveries today', '${st.todayDeliveries}')),
          ]),
          const SectionLabel('Transactions'),
          if (_error != null) EmptyState(icon: Icons.wifi_off, title: "Couldn't load your wallet", subtitle: _error, action: AppButton('Try again', onTap: _load)),
          if (_tx == null && _error == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (_tx != null && _tx!.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet', subtitle: 'Earnings from each delivery appear here.'),
          if (_tx != null && _tx!.isNotEmpty)
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < _tx!.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.line, indent: 16, endIndent: 16),
                  _txRow(context, _tx![i]),
                ],
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _mini(BuildContext context, String l, String v) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 12, color: inkGrey)),
          const SizedBox(height: 4),
          Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.ink)),
        ]),
      );

  Widget _txRow(BuildContext context, Map<String, dynamic> t) {
    final credit = t['type'] == 'credit';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (credit ? brandGreen : dangerRed).withValues(alpha: 0.1),
        child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded, color: credit ? brandGreen : dangerRed, size: 20),
      ),
      title: Text(t['title'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.ink)),
      subtitle: Text('${t['description'] ?? ''}\n${dayTime(parseTime(t['created_at']))}', style: const TextStyle(fontSize: 12, color: inkGrey, height: 1.4)),
      isThreeLine: true,
      trailing: Text(t['amount'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: credit ? brandGreen : context.ink)),
    );
  }
}
