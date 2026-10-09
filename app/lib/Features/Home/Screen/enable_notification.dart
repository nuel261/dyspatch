import 'package:dyspatch_app/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_app/Features/onboarding/utils/button.dart';
import 'package:dyspatch_app/core/utils/button_container.dart';
import 'package:dyspatch_app/core/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:location/location.dart';

/// After sign-up: asks for location (precise pickup points) and notification permission.
class EnableNotification extends StatefulWidget {
  const EnableNotification({super.key});

  @override
  State<EnableNotification> createState() => _EnableNotificationState();
}

class _EnableNotificationState extends State<EnableNotification> {
  bool _busy = false;

  void _goHome() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final loc = Location();
      var on = await loc.serviceEnabled();
      if (!on) on = await loc.requestService();
      if (on) {
        final p = await loc.hasPermission();
        if (p == PermissionStatus.denied) await loc.requestPermission();
      }
    } catch (_) {}
    await PushService.instance.requestPermissionAndRegister();
    if (mounted) _goHome();
  }

  Future<void> _later() async {
    // Still ask for notifications — delivery updates depend on them.
    await PushService.instance.requestPermissionAndRegister();
    if (mounted) _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset("assets/images/amico.svg"),

                SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Enable location access",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Montserrat",
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Center(
                    child: Text(
                      "We use your location to set precise pickup points ",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: "Montserrat",
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Center(
                    child: Text(
                      "and improve your delivery experience.",
                      style: TextStyle(
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                        fontFamily: "Montserrat",
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 100),

                ButtonContainer(
                  onTap: _enable,
                  text_color: Color(0xFFFFFFFF),
                  button_text: _busy ? "Please wait…" : "Enable Location access",
                  color: Color(0xFF34A853),
                ),

                SizedBox(height: 20),

                ButtonContainer(
                  onTap: _later,
                  button_text: "Maybe Later",
                  text_color: Color(0xFF34A853),
                  color: Color(0xFF34A853).withOpacity(0.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
