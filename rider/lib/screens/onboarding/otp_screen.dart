import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/rider_api.dart';
import '../../core/api/session.dart';
import '../../core/services/push_service.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'splash_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> start;
  const OtpScreen({super.key, required this.phone, required this.start});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late int _len = (widget.start['length'] as num?)?.toInt() ?? 4;
  late int _resendIn = (widget.start['resend_in'] as num?)?.toInt() ?? 60;
  late String? _debug = widget.start['debug_code'] as String?;
  Timer? _timer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
      if (_resendIn == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_ctrl.text.length != _len || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RiderApi.verifyOtp(widget.phone, _ctrl.text);
      await Session.instance.save(r['token'] as String, Map<String, dynamic>.from(r['rider'] as Map));
      PushService.instance.syncToken();
      if (Session.instance.profileComplete) RiderState.instance.start();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => nextScreenFor(Session.instance)), (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final r = await RiderApi.requestOtp(widget.phone);
      setState(() {
        _resendIn = (r['resend_in'] as num?)?.toInt() ?? 60;
        _len = (r['length'] as num?)?.toInt() ?? _len;
        _debug = r['debug_code'] as String?;
        _error = null;
      });
      _tick();
      if (mounted) toast(context, 'New code sent');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.card,
      appBar: AppBar(backgroundColor: context.card, elevation: 0, foregroundColor: context.ink, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Enter the code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 8),
            Text('Sent by SMS to ${widget.phone}', style: const TextStyle(fontSize: 14, color: inkGrey)),
            const SizedBox(height: 28),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_len)],
              onChanged: (v) {
                setState(() {});
                if (v.length == _len) _verify();
              },
              style: TextStyle(fontSize: 30, letterSpacing: 20, fontWeight: FontWeight.w700, color: context.ink),
              decoration: InputDecoration(
                hintText: '•' * _len,
                hintStyle: const TextStyle(color: Color(0xFFBDBDBD), letterSpacing: 20),
                filled: true,
                fillColor: context.cs.secondary,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _error != null ? dangerRed : Colors.transparent, width: 1.6)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _error != null ? dangerRed : brandGreen, width: 1.6)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: dangerRed, fontSize: 13)),
            ],
            if (_debug != null) ...[
              const SizedBox(height: 16),
              AppCard(
                color: warnAmber.withValues(alpha: 0.12),
                child: Text('SMS is in test mode on the server. Your code is $_debug',
                    style: const TextStyle(fontSize: 13, color: warnAmber, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),
            Row(children: [
              const Text("Didn't get it? ", style: TextStyle(fontSize: 14, color: inkGrey)),
              _resendIn > 0
                  ? Text('Resend in ${_resendIn}s', style: const TextStyle(fontSize: 14, color: inkGrey, fontWeight: FontWeight.w600))
                  : GestureDetector(
                      onTap: _resend,
                      child: const Text('Resend code',
                          style: TextStyle(fontSize: 14, color: brandGreen, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                    ),
            ]),
            const Spacer(),
            AppButton('Verify', loading: _loading, onTap: _ctrl.text.length == _len ? _verify : null),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
