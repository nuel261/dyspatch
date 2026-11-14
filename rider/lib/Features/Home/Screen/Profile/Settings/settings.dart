import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/settings.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/edit_profile.dart';
import 'package:dyspatch_rider/Features/Home/widget/menu_card.dart';
import 'package:dyspatch_rider/Features/Home/widget/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Shared icon color so every SVG in this screen's menu cards stays in
  // sync with the icon color used elsewhere (settings.dart).
  Color _iconColor(BuildContext context) => const Color(0xFF5F6368);

  Widget _menuIcon(BuildContext context, String assetName) {
    return SvgPicture.asset(
      'assets/images/$assetName',
      colorFilter: ColorFilter.mode(_iconColor(context), BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────
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
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Profile",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    // Invisible spacer to keep title truly centred
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // ── Body content ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 100 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: const NetworkImage(
                            'https://picsum.photos/200',
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                        ),
                      ),
                    ),

                    // Name + verified badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Sophia Ada",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(width: 5),
                        SvgPicture.asset('assets/images/Verified.svg'),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: _menuIcon(context, 'ph_map-pin.svg'),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          "Airport road, Benin city",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Edit profile link
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfile(),
                            ),
                          );
                        },
                        child: const Text(
                          "Edit Profile",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Montserrat",
                            color: Color(0xFF1D5E2E),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF1D5E3E),
                            decorationThickness: 1.5,
                            decorationStyle: TextDecorationStyle.solid,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── OPERATIONS section ─────────────────────────────
                    const SectionLabel(label: "OPERATIONS"),
                    const SizedBox(height: 8),
                    MenuCard(
                      items: [
                        MenuItem(
                          icon: _menuIcon(context, 'ph_crosshair.svg'),
                          label: "Default pickup location",
                          onTap: () {},
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'ph_truck.svg'),
                          label: "My deliveries",
                          onTap: () {},
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'ph_bookmark-simple.svg'),
                          label: "Saved locations",
                          onTap: () {},
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── SYSTEM section ─────────────────────────────────
                    const SectionLabel(label: "SYSTEM"),
                    const SizedBox(height: 8),
                    MenuCard(
                      items: [
                        MenuItem(
                          icon: _menuIcon(context, 'ph_gear.svg'),
                          label: "Settings",
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => Settings(),
                            //   ),
                            // );
                          },
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
