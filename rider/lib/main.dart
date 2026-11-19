import 'dart:async';

import 'package:dyspatch_rider/Features/onboarding/screen/onboarding_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/splash_screen.dart';
import 'package:dyspatch_rider/core/api/api_client.dart';
import 'package:dyspatch_rider/core/api/session.dart';
import 'package:dyspatch_rider/core/services/push_service.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
import 'package:dyspatch_rider/core/theme/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => FlutterError.presentError(d);
  PlatformDispatcher.instance.onError = (e, s) {
    debugPrint('Uncaught: $e\n$s');
    return true;
  };
  // Only fast, local reads before the first frame: the saved sign-in and the
  // saved theme (both from SharedPreferences). Network, Firebase and location
  // start after the first frame so the logo shows immediately.
  var theme = ThemeProvider();
  await Future.wait([
    Session.instance.load().catchError((e) => debugPrint('Session load failed: $e')),
    ThemeProvider.load().then((t) => theme = t),
  ]).timeout(const Duration(seconds: 3), onTimeout: () => const []);

  // Token expired or revoked anywhere → back to the start.
  ApiClient.instance.onUnauthorized = () {
    RiderState.instance.stop();
    Session.instance.clear();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: Session.instance),
        ChangeNotifierProvider.value(value: RiderState.instance),
      ],
      child: const MyApp(),
    ),
  );

  // Firebase / notification setup off the startup path.
  WidgetsBinding.instance.addPostFrameCallback((_) => PushService.instance.init());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dyspatch Rider',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      theme: context.watch<ThemeProvider>().themeData,
    );
  }
}
