import 'dart:ui' show ImageFilter;

import 'package:dyspatch_rider/Features/Home/Screen/Earning/earning_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/profile_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Track/track_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/activity_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/home_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  // Passed in from EnableNotification: whether location was actually
  // granted before landing on Home. Defaults to true so existing call
  // sites (e.g. `HomeScreen()` with no args) keep working unchanged.
  final bool locationEnabled;

  const HomeScreen({super.key, this.locationEnabled = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  static const _activeColor = Color(0xFF298341);
  static const _inactiveColor = Color(0xFF9E9E9E);
  static const _pillColor = Color(0xFFEFEFEF);

  final List<_NavItem> _navItems = const [
    _NavItem(iconAsset: 'assets/images/Icon.svg', label: 'Home'),
    _NavItem(iconAsset: 'assets/images/Icon1.svg', label: 'Wallet'),
    _NavItem(iconAsset: 'assets/images/ph_clock-user.svg', label: 'Activity'),
    _NavItem(iconAsset: 'assets/images/ph_user.svg', label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeContent(onFindNewOrders: () => setState(() => _selectedIndex = 2)),
      const EarningScreen(),
      ActivityScreen(onGoHome: () => setState(() => _selectedIndex = 0)),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── Page content ──
            SafeArea(bottom: false, child: _pages[_selectedIndex]),

            // ── FAB: sits clear above the floating nav bar (which spans
            // bottom 32→132) so it can never be shadowed by it. Only shown
            // on the Home tab. ──
            if (_selectedIndex == 0 || _selectedIndex == 2)
              Positioned(
                right: 16,
                bottom: 150,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: FloatingActionButton(
                    heroTag: 'mapFab',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TrackScreen(),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFF298341),
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.map_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),

            // ── Blur behind the nav bar: content scrolling under it is
            // frosted from the bar's middle down to the screen edge. ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 32 + 50 + MediaQuery.of(context).padding.bottom,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // ── Floating nav bar ──
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                height: 100,
                padding: const EdgeInsets.only(
                  top: 12,
                  right: 16,
                  bottom: 12,
                  left: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1000),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer, // ~#E3E7EB in light mode
                    width: 1,
                  ), // boxShadow: [
                  //   BoxShadow(
                  //     color: Theme.of(context).colorScheme.shadow,
                  //     blurRadius: 24,
                  //     offset: const Offset(0, 5),
                  //   ),
                  // ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_navItems.length, (index) {
                    final item = _navItems[index];
                    final isActive = _selectedIndex == index;

                    // Narrow phones (< 360dp) get slimmer pills so all four
                    // fit. Icon-only pills keep their size (flex 0); only the
                    // active pill's label may shrink/ellipsise.
                    final narrow = MediaQuery.sizeOf(context).width < 360;
                    return Flexible(
                      flex: isActive ? 1 : 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedIndex = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.symmetric(
                            horizontal: narrow ? 12 : 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                item.iconAsset,
                                width: 22,
                                height: 22,
                                colorFilter: ColorFilter.mode(
                                  isActive ? _activeColor : _inactiveColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.w600, // SemiBold
                                      fontSize: 14,
                                      height: 20 / 14, // Line height: 20px
                                      letterSpacing: 0, // 0%
                                      color: _activeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String iconAsset;
  final String label;
  const _NavItem({required this.iconAsset, required this.label});
}
