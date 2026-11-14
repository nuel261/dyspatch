import 'package:dyspatch_rider/core/services/app_router.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:dyspatch_rider/Features/Home/Screen/enable_notification.dart';
import 'package:dyspatch_rider/Features/Home/Screen/home_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

class VerficationSucess extends StatefulWidget {
  const VerficationSucess({super.key});

  @override
  State<VerficationSucess> createState() => _VerficationSucessState();
}

class _VerficationSucessState extends State<VerficationSucess> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    // Fire as soon as the screen lands.
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Checks whether location services are actually on AND the app has
  // permission. If either is missing, we send the user to the
  // EnableNotification (enable-location) screen instead of straight home.
  Future<void> _handleGoToHome(BuildContext context) async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EnableNotification()),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EnableNotification()),
      );
      return;
    }

    // Location is on and permitted — go straight home.
    if (!context.mounted) return;
    AppRouter.goTo(context, const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        // Stack lets the confetti overlay the whole screen without
        // affecting the layout underneath.
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    // Fills the screen on tall phones, scrolls instead of
                    // overflowing on short ones.
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: SvgPicture.asset(
                                'assets/images/Notification.svg',
                                width: 50,
                                height: 50,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Center(
                            child: Text(
                              "VERIFICATION SUCCESSFUL",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                height: 28 / 20, // 1.4
                                letterSpacing: 0,
                                color: Theme.of(
                                  context,
                                ).colorScheme.inversePrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          Center(
                            child: SvgPicture.asset(
                              "assets/images/success.svg",
                              height: min(160, constraints.maxHeight * 0.22),
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Center(
                            child: Text(
                              "Your Identity has been confirmed",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5A5858),
                                height: 20 / 14, // 1.429
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 75,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () => _handleGoToHome(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF34A853),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Go to home",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 20 / 14, // 1.429
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Confetti — falls from the top across the full width ──
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                blastDirection: pi / 2, // downward
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                maxBlastForce: 20,
                minBlastForce: 8,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [
                  Color(0xFF34A853),
                  Color(0xFF1A6B3C),
                  Color(0xFF298341),
                  Color(0xFFFFC107),
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
