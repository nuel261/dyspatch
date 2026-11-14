import 'package:dyspatch_rider/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_rider/core/services/app_router.dart';
import 'package:dyspatch_rider/core/services/push_service.dart';
import 'package:dyspatch_rider/core/utils/button_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';

class EnableNotification extends StatelessWidget {
  const EnableNotification({super.key});

  // Turns location ON (or asks the user to). Either way, we move on to
  // Home — but we tell Home whether location actually ended up enabled
  // so it can show the "Access to location required" banner if not.
  Future<void> _enableLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // Takes the user to the device's location settings toggle.
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final bool granted =
        serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);

    // Job offers ring as notifications, so ask for that too.
    await PushService.instance.requestPermissionAndRegister();

    if (!context.mounted) return;
    AppRouter.goTo(context, HomeScreen(locationEnabled: granted));
  }

  // User skipped — go to Home, but location is definitely not confirmed,
  // so the banner should show there.
  void _maybeLater(BuildContext context) {
    AppRouter.goTo(context, HomeScreen(locationEnabled: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                // Keeps content centered on tall screens, but lets it
                // scroll instead of overflowing on smaller/short screens.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Constrain the illustration so it scales with the
                      // screen instead of rendering at its raw SVG size.
                      SvgPicture.asset(
                        "assets/images/amico.svg",
                        height: constraints.maxHeight * 0.32,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "Enable location access",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 32 / 24, // 1.3333
                          letterSpacing: 0.0,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "We use your location to set precise pickup points and improve your delivery experience.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 22 / 14, // 1.5714
                          letterSpacing: 0.0,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 32),

                      ButtonContainer(
                        onTap: () => _enableLocation(context),
                        text_color: Color(0xFFFFFFFF),
                        button_text: "Enable location access",
                        color: Color(0xFF34A853),
                      ),

                      SizedBox(height: 12),

                      ButtonContainer(
                        onTap: () => _maybeLater(context),
                        button_text: "Maybe Later",
                        text_color: Color(0xFF34A853),
                        color: Color(0xFF34A853).withOpacity(0.1),
                      ),

                      // Bottom breathing room so the last button never
                      // sits flush against the screen edge when scrolled.
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
