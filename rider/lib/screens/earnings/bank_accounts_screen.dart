import 'package:flutter/material.dart';

import '../../core/api/rider_api.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});
  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await RiderApi.wallet();
      if (mounted) setState(() => _rows = ((w['bank_accounts'] as List?) ?? []).map((b) => Map<String, dynamic>.from(b as Map)).toList());
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _remove(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text('${b['bank_name']} · ${b['account_number']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: dangerRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RiderApi.removeBankAccount((b['id'] as num).toInt());
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(context, 'Bank accounts'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandGreen,
        onPressed: () async {
          final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const _AddBankScreen()));
          if (added == true) _load();
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _rows == null
          ? const Center(child: CircularProgressIndicator())
          : _rows!.isEmpty
              ? const EmptyState(icon: Icons.account_balance_outlined, title: 'No bank account yet', subtitle: 'Add the account your earnings should be paid into. It must be in your name.')
              : ListView(padding: const EdgeInsets.all(16), children: _rows!
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(children: [
                            const CircleAvatar(backgroundColor: Color(0x1A298341), child: Icon(Icons.account_balance, color: brandGreen, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(b['account_name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
                                Text('${b['bank_name']} · ${b['account_number']}', style: const TextStyle(fontSize: 13, color: inkGrey)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  if (b['is_default'] == true) const StatusPill('Default'),
                                  if (b['is_default'] == true) const SizedBox(width: 6),
                                  StatusPill(b['is_verified'] == true ? 'Verified' : 'Pending check', color: b['is_verified'] == true ? brandGreen : warnAmber),
                                ]),
                              ]),
                            ),
                            IconButton(icon: const Icon(Icons.delete_outline, color: inkGrey), onPressed: () => _remove(b)),
                          ]),
                        ),
                      ))
                  .toList()),
    );
  }
}

class _AddBankScreen extends StatefulWidget {
  const _AddBankScreen();
  @override
  State<_AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends State<_AddBankScreen> {
  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _bank;
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    RiderApi.banks().then((b) {
      if (mounted) setState(() => _banks = b);
    }).catchError((_) {});
  }

  Future<void> _pickBank() async {
    final q = TextEditingController();
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          final list = _banks.where((b) => (b['name'] as String).toLowerCase().contains(q.text.toLowerCase())).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: AppField('Search bank', q, autofocus: true, onChanged: (_) => set(() {}))),
              Expanded(child: ListView(children: list.map((b) => ListTile(title: Text(b['name'] as String), onTap: () => Navigator.pop(ctx, b))).toList())),
            ]),
          );
        },
      ),
    );
    if (picked != null) setState(() => _bank = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final env = await RiderApi.addBankAccount(bankName: _bank!['name'] as String, bankCode: _bank!['code'] as String?, accountNumber: _number.text.trim(), accountName: _name.text.trim());
      if (!mounted) return;
      toast(context, env['message'] as String? ?? 'Account saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _bank != null && _number.text.trim().length == 10 && _name.text.trim().length > 3;
    return Scaffold(
      appBar: appBar(context, 'Add bank account'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _banks.isEmpty ? null : _pickBank,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(color: context.cs.secondary, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: Text(_bank?['name'] as String? ?? (_banks.isEmpty ? 'Loading banks…' : 'Choose your bank'), style: TextStyle(color: _bank == null ? inkGrey : context.ink))),
              const Icon(Icons.expand_more, color: inkGrey),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        AppField('Account number', _number, keyboard: TextInputType.number, maxLength: 10, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        AppField('Account name', _name, caps: TextCapitalization.characters, hint: 'As it appears at the bank', onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        const Text('Payouts only go to accounts in your own name. We check the name with your bank when possible.', style: TextStyle(fontSize: 12.5, color: inkGrey, height: 1.5)),
        const SizedBox(height: 24),
        AppButton('Save account', loading: _saving, onTap: ok ? _save : null),
      ]),
    );
  }
}
