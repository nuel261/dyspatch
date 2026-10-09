import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shown after the user taps "I've sent the money" on the TopUpScreen.
///
/// NOTE: Replace `_illustrationAsset` below with the actual path to the
/// SVG you already have in your project (and make sure it's registered
/// under `assets:` in pubspec.yaml). `flutter_svg` must be in
/// pubspec.yaml as a dependency.
class PendingConfirmationScreen extends StatelessWidget {
  final String? reference;
  const PendingConfirmationScreen({super.key, this.reference});

  static const String _illustrationAsset =
      "assets/images/pending_confirmation.svg";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Top bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F4),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.arrow_back, size: 20),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Top-up",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: "Montserrat",
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ── Scrollable content ───────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Illustration
                        SizedBox(
                          height: 220,
                          child: SvgPicture.asset(
                            'assets/images/time_glass.svg',
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 32),

                        const Text(
                          "PENDING CONFIRMATION",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Note: Top-up confirmation typically takes 5 - 10 minutes.${reference != null ? ' Reference $reference.' : ''} We'll notify you as soon as your wallet is credited.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 36),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF298341),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Go to home",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Montserrat",
                              ),
                            ),
                          ),
                        ),

                        // Leaves room so content doesn't sit under the
                        // floating bottom nav bar.
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating bottom nav bar ────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: _BottomNavBar(activeIndex: 2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Floating pill-shaped bottom nav bar — home / map / wallet / profile.
// activeIndex controls which item is shown highlighted (green, with label).
// ─────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int activeIndex;

  const _BottomNavBar({required this.activeIndex});

  static const _items = [
    (icon: Icons.home_outlined, label: "Home"),
    (icon: Icons.map_outlined, label: "Map"),
    (icon: Icons.account_balance_wallet_outlined, label: "Wallet"),
    (icon: Icons.person_outline, label: "Profile"),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_items.length, (i) {
          final isActive = i == activeIndex;
          final item = _items[i];

          if (isActive) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF298341).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(item.icon, size: 20, color: const Color(0xFF298341)),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF298341),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(item.icon, size: 22, color: Colors.grey.shade500),
          );
        }),
      ),
    );
  }
}
