import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'phone_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget point(IconData i, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: brandGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(i, color: brandGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 3),
                Text(s, style: const TextStyle(fontSize: 13, color: inkGrey, height: 1.4)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      backgroundColor: context.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: brandGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('DYSPATCH RIDER', style: TextStyle(color: brandGreen, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ),
            const SizedBox(height: 18),
            Text('Turn your ride\ninto steady income.', style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 12),
            const Text('Bike, bicycle, car or truck — get delivery requests near you and get paid to your wallet after every drop-off.',
                style: TextStyle(fontSize: 14, color: inkGrey, height: 1.5)),
            const SizedBox(height: 32),
            point(Icons.notifications_active_outlined, 'Jobs come to you', 'Go online and nearby requests ring on your phone.'),
            point(Icons.verified_user_outlined, 'Safe handovers', 'Pickup and delivery are confirmed with one-time codes.'),
            point(Icons.account_balance_wallet_outlined, 'Paid after every trip', 'Earnings land in your wallet. Withdraw to any Nigerian bank.'),
            const Spacer(),
            AppButton('Get started', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneScreen()))),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://dyspatch.com.ng/privacy-terms'), mode: LaunchMode.externalApplication),
                child: const Text.rich(
                  TextSpan(text: 'By continuing you agree to our ', style: TextStyle(fontSize: 12, color: inkGrey), children: [
                    TextSpan(text: 'Rider Terms & Privacy Policy', style: TextStyle(color: brandGreen, decoration: TextDecoration.underline)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
