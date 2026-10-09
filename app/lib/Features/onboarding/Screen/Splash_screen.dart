import 'package:dyspatch_app/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/onboarding_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      await _controller.reverse();
      if (!mounted) return;
      final session = Session.instance;
      final Widget next = session.isLoggedIn
          ? const HomeScreen()
          : (session.onboarded ? const Login() : const OnboardingScreen());
      if (session.isLoggedIn) {
        // Refresh profile and push token in the background.
        DyspatchApi.me().catchError((_) => <String, dynamic>{});
        // Asks once on Android 13+/iOS (no-op if already decided), then registers the device.
        PushService.instance.requestPermissionAndRegister();
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => next));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: SvgPicture.asset(
              'assets/images/Logo.svg',
              width: 60,
              height: 60,
            ),
          ),
        ),
      ),
    );
  }
}
