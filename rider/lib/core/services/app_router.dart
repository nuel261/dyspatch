import 'package:flutter/material.dart';

import '../../Features/Home/Screen/home_screen.dart';
import '../../Features/onboarding/screen/onboarding_screen.dart';
import '../api/rider_api.dart';
import '../api/session.dart';
import '../utils/rider_session.dart';
import 'push_service.dart';
import 'rider_state.dart';

/// Where a rider lands after the splash screen or after signing in.
class AppRouter {
  /// Logged in → home (and start the live rider state); otherwise onboarding.
  static Future<Widget> startScreen() async {
    final s = Session.instance;
    if (!s.isLoggedIn) return const OnboardingScreen();
    if (s.rider != null) {
      // Open straight away with the saved profile; refresh it in the background.
      RiderSession.syncFrom(s.rider);
      RiderApi.me().then((r) async {
        await s.updateRider(r);
        RiderSession.syncFrom(s.rider);
      }).catchError((_) {/* offline: keep the saved profile */});
    } else {
      try {
        await s.updateRider(await RiderApi.me()).timeout(const Duration(seconds: 6));
      } catch (_) {}
      RiderSession.syncFrom(s.rider);
    }
    RiderState.instance.start();
    PushService.instance.syncToken();
    return const HomeScreen();
  }

  /// Replace the whole stack with [screen].
  static void goTo(BuildContext context, Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  /// Signed out (or token rejected): clear everything and go back to onboarding.
  static Future<void> signOut(BuildContext context) async {
    await RiderState.instance.stop();
    try {
      await RiderApi.logout();
    } catch (_) {}
    await Session.instance.clear();
    if (context.mounted) goTo(context, const OnboardingScreen());
  }
}
