import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/rider_api.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'bank_accounts_screen.dart';

class WithdrawScreen extends StatefulWidget {
  final Map<String, dynamic> wallet;
  const WithdrawScreen({super.key, required this.wallet});
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amount = TextEditingController();
  late List<Map<String, dynamic>> _banks = ((widget.wallet['bank_accounts'] as List?) ?? []).map((b) => Map<String, dynamic>.from(b as Map)).toList();
  int? _bankId;
  int? _fee;
  String? _payoutDate;
  Timer? _debounce;
  bool _sending = false;

  int get _balance => (widget.wallet['balance_kobo'] as num?)?.toInt() ?? 0;
  int get _min => (widget.wallet['withdrawal_min_kobo'] as num?)?.toInt() ?? 50000;
  int get _kobo => toKobo(_amount.text);

  @override
  void initState() {
    super.initState();
    if (_banks.isNotEmpty) _bankId = (_banks.firstWhere((b) => b['is_default'] == true, orElse: () => _banks.first)['id'] as num).toInt();
  }

  void _onAmount(String _) {
    setState(() => _fee = null);
    _debounce?.cancel();
    if (_kobo < _min) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await RiderApi.withdrawalFee(_amount.text);
        if (mounted) setState(() {
          _fee = (r['fee_kobo'] as num?)?.toInt() ?? 0;
          _payoutDate = r['payout_date'] as String?;
        });
      } catch (_) {}
    });
  }

  String? get _problem {
    if (_amount.text.isEmpty) return null;
    if (_kobo < _min) return 'Minimum withdrawal is ${naira(_min)}';
    if (_kobo + (_fee ?? 0) > _balance) return 'Not enough balance (including the fee)';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final env = await RiderApi.withdraw(_amount.text, bankAccountId: _bankId);
      RiderState.instance.refresh();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: brandGreen, size: 48),
          title: const Text('Withdrawal requested'),
          content: Text(env['message'] as String? ?? 'Your transfer is on its way.', textAlign: TextAlign.center),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addBank() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen()));
    try {
      final w = await RiderApi.wallet();
      if (!mounted) return;
      setState(() {
        _banks = ((w['bank_accounts'] as List?) ?? []).map((b) => Map<String, dynamic>.from(b as Map)).toList();
        if (_bankId == null && _banks.isNotEmpty) _bankId = (_banks.first['id'] as num).toInt();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Scaffold(
      appBar: appBar(context, 'Withdraw'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Available: ${naira(_balance, decimals: true)}', style: const TextStyle(color: inkGrey, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              onChanged: _onAmount,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.ink),
              decoration: InputDecoration(prefixText: '₦ ', hintText: '0', border: InputBorder.none, prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.ink)),
            ),
            if (problem != null) Text(problem, style: const TextStyle(color: dangerRed, fontSize: 13)),
            if (problem == null && _fee != null) ...[
              Text('Transfer fee: ${naira(_fee)} · You receive ${naira(_kobo)}', style: const TextStyle(color: inkGrey, fontSize: 13)),
              if (_payoutDate != null) Text('Paid on: $_payoutDate', style: const TextStyle(color: inkGrey, fontSize: 13)),
            ],
          ]),
        ),
        const SectionLabel('Send to'),
        if (_banks.isEmpty)
          AppCard(
            onTap: _addBank,
            child: const Row(children: [
              Icon(Icons.add_circle_outline, color: brandGreen),
              SizedBox(width: 12),
              Text('Add a bank account', style: TextStyle(color: brandGreen, fontWeight: FontWeight.w700)),
            ]),
          ),
        ..._banks.map((b) {
          final id = (b['id'] as num).toInt();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => setState(() => _bankId = id),
              child: Row(children: [
                Icon(_bankId == id ? Icons.radio_button_checked : Icons.radio_button_off, color: _bankId == id ? brandGreen : inkGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b['account_name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
                    Text('${b['bank_name']} · ${b['account_number']}', style: const TextStyle(fontSize: 13, color: inkGrey)),
                  ]),
                ),
              ]),
            ),
          );
        }),
        if (_banks.isNotEmpty) TextButton.icon(onPressed: _addBank, icon: const Icon(Icons.add, color: brandGreen), label: const Text('Add another account', style: TextStyle(color: brandGreen))),
        const SizedBox(height: 20),
        AppButton('Withdraw ${_kobo > 0 ? naira(_kobo) : ''}', loading: _sending, onTap: _bankId != null && _amount.text.isNotEmpty && problem == null && _fee != null ? _submit : null),
      ]),
    );
  }
}
