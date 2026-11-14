import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/ride_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/widget/menu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RideVerificationScreen extends StatelessWidget {
  const RideVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Ride verification",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    MenuCard(
                      // #F5F5F5 in light mode, #1A1A1A in dark mode.
                      color: Theme.of(context).colorScheme.secondary,
                      items: [
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_info.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Details",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RideDetailsScreen(),
                              ),
                            );
                          },
                        ),
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_camera.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Photos",
                          onTap: () {},
                        ),
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_file.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Documents",
                          onTap: () {},
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Register under a Fleet ───────────────────────
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            // #34A853 in both light and dark mode.
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Register under a Fleet",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
