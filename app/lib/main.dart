import 'package:dyspatch_app/Features/Home/Screen/notification_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/Splash_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/core/api/api_client.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/services/push_service.dart';
import 'package:dyspatch_app/core/theme/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lets services (push taps, expired sessions) navigate without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.load();
  try {
    // Uses android/app/google-services.json and ios/Runner/GoogleService-Info.plist
    // from the Firebase project "dyspatch-bc9cc".
    await Firebase.initializeApp();
    await PushService.instance.init();
  } catch (e) {
    debugPrint('Firebase init failed (add the config files): $e');
  }

  PushService.instance.onOpen = (data) {
    final nav = navigatorKey.currentState;
    if (nav == null || !Session.instance.isLoggedIn) return;
    final trackId = data['track_id'];
    if (trackId is String && trackId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => TrackScreen(initialTrackId: trackId)));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  };

  ApiClient.instance.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Login()), (_) => false);
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider.value(value: Session.instance),
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Dyspatch',
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: const SplashScreen(),
    );
  }
}
