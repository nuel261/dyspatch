import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/api/session.dart';
import 'package:dyspatch_rider/core/services/app_router.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/authentication.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/terms_and_privacy.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/change_password_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/edit_profile.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/rider_verification_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/notification_screen.dart';
import 'package:dyspatch_rider/Features/Home/widget/menu_card.dart';
import 'package:dyspatch_rider/Features/Home/widget/section_label.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/login.dart';
import 'package:dyspatch_rider/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  /// Set when shown as a Home tab: back goes to the Home tab.
  final VoidCallback? onBack;
  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Color _iconColor(BuildContext context) => const Color(0xFF5F6368);

  Future<void> _handleLogout() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Log Out',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Logs out on the server, stops live tracking and clears the stack.
    await AppRouter.signOut(context);
  }

  String? get _photo {
    final p = Session.instance.rider?['photo'] as String?;
    return p == null || p.isEmpty ? null : p;
  }

  Future<void> _support({required bool email}) async {
    Map<String, dynamic> cfg = const {};
    try {
      cfg = await RiderApi.config();
    } catch (_) {}
    final phone = (cfg['support_phone'] as String?) ?? '';
    final mail = (cfg['support_email'] as String?) ?? 'support@dyspatch.com.ng';
    final uri = email || phone.isEmpty
        ? Uri(scheme: 'mailto', path: mail, query: 'subject=Dyspatch Rider help')
        : Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) showSnack(context, email ? mail : phone);
  }

  Widget _menuIcon(BuildContext context, String assetName) {
    return SvgPicture.asset(
      'assets/images/$assetName',
      colorFilter: ColorFilter.mode(_iconColor(context), BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final themeProvider = context.watch<ThemeProvider>();
    final isLightMode = !themeProvider.isDarkMode;
    final cardColor = isLightMode
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF23262B);

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
                          "Settings",
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
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          backgroundImage: _photo == null ? null : NetworkImage(_photo!),
                          child: _photo != null
                              ? null
                              : Icon(
                                  Icons.person_outline,
                                  size: 50,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      ),
                    ),

                    // Name + verified badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          session.fullName.isEmpty ? 'Rider' : session.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            fontSize: 20,
                          ),
                        ),
                        if (session.kycStatus == 'verified') ...[
                          const SizedBox(width: 5),
                          SvgPicture.asset('assets/images/Verified.svg'),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Rating + trips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                        SizedBox(width: 4),
                        Text(
                          ((session.rider?['rating'] as num?) ?? 5).toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "•",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "${RiderState.instance.me?['total_deliveries'] ?? 0} Trips",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Montserrat",
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

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

                    // ── SECURITY & VERIFICATION ────────────────────────
                    const SectionLabel(label: "SECURITY & VERIFICATION"),
                    const SizedBox(height: 8),
                    MenuCard(
                      color: cardColor,
                      items: [
                        MenuItem(
                          icon: _menuIcon(context, 'ph_verified.svg'),
                          label: "Ride Verification",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RideVerificationScreen(),
                              ),
                            );
                          },
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── PREFERENCES ─────────────────────────────────────
                    const SectionLabel(label: "PREFERENCES"),
                    const SizedBox(height: 8),
                    MenuCard(
                      color: cardColor,
                      items: [
                        MenuItem(
                          icon: _menuIcon(
                            context,
                            isLightMode ? 'ph_sun.svg' : 'ph_moon.svg',
                          ),
                          label: isLightMode ? "Light Mode" : "Dark Mode",
                          onTap: () {
                            themeProvider.toggleTheme();
                          },
                          trailing: _ThemeToggle(
                            isLightMode: isLightMode,
                            onTap: themeProvider.toggleTheme,
                          ),
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'notification_alert.svg'),
                          label: "Notification",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'ph_translate.svg'),
                          label: "Language",
                          onTap: () {},
                          showDivider: false,
                          trailing: const Text(
                            "EN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Montserrat",
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── SUPPORT & LEGAL ─────────────────────────────────
                    const SectionLabel(label: "SUPPORT & LEGAL"),
                    const SizedBox(height: 8),
                    MenuCard(
                      color: cardColor,
                      items: [
                        MenuItem(
                          icon: _menuIcon(context, 'ph_question.svg'),
                          label: "Help Center",
                          onTap: () => _support(email: true),
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'ph_headset.svg'),
                          label: "Contact Support",
                          onTap: () => _support(email: false),
                        ),
                        MenuItem(
                          icon: _menuIcon(context, 'ph_file-text.svg'),
                          label: "Terms & Privacy",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsAndPrivacyScreen(),
                            ),
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Log Out ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: ElevatedButton(
                            onPressed: _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDE7E9),
                              foregroundColor: const Color(0xFFD32F2F),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Log Out",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Montserrat",
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Light/dark switch whose thumb shows the sun (light, left) or moon
/// (dark, right). Flutter's Switch only takes IconData for the thumb, so
/// this is drawn by hand to use the project's SVGs.
class _ThemeToggle extends StatelessWidget {
  final bool isLightMode;
  final VoidCallback onTap;

  const _ThemeToggle({required this.isLightMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        width: 48,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          // Dark mode: a track darker than the #23262B card, no outline.
          color: isLightMode
              ? const Color(0xFFE3E7EB)
              : const Color(0xFF181B1F),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isLightMode ? Colors.grey.shade400 : const Color(0xFF181B1F),
            width: 0.5,
          ),
        ),
        child: AnimatedAlign(
          duration: kThemeAnimationDuration,
          curve: Curves.easeInOut,
          alignment: isLightMode
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Container(
            width: 20,
            height: 20,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              child: SvgPicture.asset(
                isLightMode
                    ? 'assets/images/ph_sun.svg'
                    : 'assets/images/ph_moon.svg',
                key: ValueKey(isLightMode),
                colorFilter: const ColorFilter.mode(
                  Color(0xFF5F6368),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
