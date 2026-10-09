import 'package:dyspatch_app/Features/Home/Screen/edit_profile.dart';
import 'package:dyspatch_app/Features/Home/Screen/my_deliveries_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/saved_locations_screen.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:provider/provider.dart';
import 'package:dyspatch_app/Features/Home/Screen/settings.dart';
import 'package:dyspatch_app/Features/Home/widget/menu_card.dart';
import 'package:dyspatch_app/Features/Home/widget/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user ?? const <String, dynamic>{};
    final name = ((user['name'] as String?) ?? '').trim();
    final avatar = user['avatar'] as String?;
    final address = (user['address'] as String?)?.trim();
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
                      onTap: () => widget.onBack != null ? widget.onBack!() : Navigator.maybePop(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
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
                padding:  EdgeInsets.only(
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
                          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          child: avatar == null || avatar.isEmpty
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFF298341)))
                              : null,
                        ),
                      ),
                    ),

                    // Name + verified badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name.isEmpty ? (user['phone'] as String? ?? 'Your profile') : name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            fontSize: 20,
                          ),
                        ),
                        if (user['business_verified'] == true) ...[
                          const SizedBox(width: 5),
                          SvgPicture.asset('assets/images/Verified.svg'),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          address == null || address.isEmpty ? "Add your address in Edit Profile" : address,
                          style: const TextStyle(
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
                          icon: Icons.location_searching_outlined,
                          label: "Default pickup location",
                          onTap: () => _open(const SavedLocationsScreen(pickDefault: true)),
                        ),
                        MenuItem(
                          icon: Icons.local_shipping_outlined,
                          label: "My deliveries",
                          onTap: () => _open(const MyDeliveriesScreen()),
                        ),
                        MenuItem(
                          icon: Icons.bookmark_border_outlined,
                          label: "Saved locations",
                          onTap: () => _open(const SavedLocationsScreen()),
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
                          icon: Icons.settings_outlined,
                          label: "Settings",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Settings(),
                              ),
                            );
                          },
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