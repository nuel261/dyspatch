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
  // Never let startup work keep the first screen from appearing.
  try {
    await Session.instance.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Session load failed: $e');
  }
  try {
    await PushService.instance.init().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Push init skipped: $e');
  }

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
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider.value(value: Session.instance),
        ChangeNotifierProvider.value(value: RiderState.instance),
      ],
      child: const MyApp(),
    ),
  );
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
      theme: Provider.of<ThemeProvider>(context).themeData,
    );
  }
}
