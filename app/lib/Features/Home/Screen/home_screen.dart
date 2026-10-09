import 'package:dyspatch_app/Features/Home/Screen/home_content.dart';
import 'package:dyspatch_app/Features/Home/Screen/wallet_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/profile_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      // ← initialized once
      HomeContent(onSwitchTab: (i) => setState(() => _selectedIndex = i)),
      TrackScreen(onBack: () => setState(() => _selectedIndex = 0)),
      WalletScreen(onBack: () => setState(() => _selectedIndex = 0)),
      ProfileScreen(onBack: () => setState(() => _selectedIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.primary,

      body: Stack(
        children: [
          // ── Page content ──
          SafeArea(bottom: false, child: _pages[_selectedIndex]),

          // ── Blurred floating nav bar ──
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: GNav(
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    color: Colors.grey,
                    activeColor: const Color(0xFF298341),
                    tabBackgroundColor: const Color(
                      0xFF298341,
                    ).withOpacity(0.12),
                    gap: 6,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    tabs: const [
                      GButton(icon: Icons.home_rounded, text: 'Home'),
                      GButton(icon: Icons.map_outlined, text: 'Track'),
                      GButton(icon: Icons.wallet_outlined, text: 'Wallet'),
                      GButton(icon: Icons.person_outline, text: 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── FAB ──
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {},
      //   backgroundColor: const Color(0xFF298341),
      //   shape: const CircleBorder(),
      //   child: const Icon(Icons.add, color: Colors.white, size: 28),
      // ),
    );
  }
}
