import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api/rider_api.dart';
import '../../core/api/session.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/theme.dart';
import '../home/home_shell.dart';
import 'profile_setup_screen.dart';
import 'verification_screen.dart';
import 'welcome_screen.dart';

/// Decides where a rider lands: welcome → profile → verification → home.
Widget nextScreenFor(Session s) {
  if (!s.isLoggedIn) return const WelcomeScreen();
  if (!s.profileComplete) return const ProfileSetupScreen();
  if (s.kycStatus == 'none' || s.kycStatus == 'rejected') return const VerificationScreen();
  return const HomeShell();
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final s = Session.instance;
    final wait = Future.delayed(const Duration(milliseconds: 1200));
    if (s.isLoggedIn) {
      try {
        await Session.instance.updateRider(await RiderApi.me());
      } catch (_) {/* offline: use the saved profile */}
    }
    await wait;
    if (!mounted) return;
    if (s.isLoggedIn && s.profileComplete) RiderState.instance.start();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => nextScreenFor(s),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGreen,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.all(18),
            child: SvgPicture.asset('assets/images/Logo.svg'),
          ),
          const SizedBox(height: 18),
          const Text('Dyspatch Rider', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Deliver. Earn. Repeat.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
        ]),
      ),
    );
  }
}
