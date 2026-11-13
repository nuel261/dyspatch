import 'package:flutter/material.dart';

import '../../core/api/rider_api.dart';
import '../../core/ui/format.dart';
import '../../core/ui/phone_input.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'otp_screen.dart';

/// One screen for sign-up and login: new numbers are registered after the code is verified.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  String _phone = '';
  bool _valid = false;
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final r = await RiderApi.requestOtp(_phone);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: r['phone'] as String? ?? _phone, start: r)));
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            Text('Your phone number', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 8),
            const Text("We'll text you a code. New here? Your rider account is created when you confirm it.",
                style: TextStyle(fontSize: 14, color: inkGrey, height: 1.5)),
            const SizedBox(height: 32),
            CustomPhoneInput(onPhoneChanged: (p, v) => setState(() {
                  _phone = p;
                  _valid = v;
                })),
            const Spacer(),
            AppButton('Continue', loading: _loading, onTap: _valid ? _continue : null),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
