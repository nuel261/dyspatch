import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/api/session.dart';
import 'core/services/push_service.dart';
import 'core/services/rider_state.dart';
import 'core/ui/theme.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/welcome_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => FlutterError.presentError(d);
  PlatformDispatcher.instance.onError = (e, s) {
    debugPrint('Uncaught: $e\n$s');
    return true;
  };
  try {
    await Session.instance.load();
  } catch (e) {
    debugPrint('Session load failed: $e');
  }
  await PushService.instance.init();

  // Token expired / revoked anywhere → back to the welcome screen.
  ApiClient.instance.onUnauthorized = () {
    RiderState.instance.stop();
    navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
  };

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider.value(value: Session.instance),
      ChangeNotifierProvider.value(value: RiderState.instance),
    ],
    child: const RiderApp(),
  ));
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dyspatch Rider',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: context.watch<ThemeProvider>().themeData,
      home: const SplashScreen(),
    );
  }
}
