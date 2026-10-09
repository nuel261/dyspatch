import 'package:dyspatch_app/Features/Home/Screen/autehtication.dart';
import 'package:dyspatch_app/Features/Home/Screen/business_verification_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/change_password_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/delivery_type_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/terms_and_privacy_screen.dart';
import 'package:dyspatch_app/Features/Home/widget/menu_card.dart';
import 'package:dyspatch_app/Features/Home/widget/section_label.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/services/push_service.dart';
import 'package:dyspatch_app/core/theme/theme_provider.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _autoAssignRiders = Session.instance.user?['auto_assign'] != false;

  Future<void> _setAutoAssign(bool v) async {
    setState(() => _autoAssignRiders = v);
    try {
      await DyspatchApi.updateMe({'auto_assign': v});
    } catch (e) {
      if (mounted) {
        setState(() => _autoAssignRiders = !v);
        toast(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _contactSupport() async {
    Map<String, dynamic> cfg = const {};
    try {
      cfg = await DyspatchApi.config();
    } catch (_) {}
    if (!mounted) return;
    final phone = cfg['support_phone'] as String?;
    final email = cfg['support_email'] as String?;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (phone != null)
            ListTile(leading: const Icon(Icons.call_outlined), title: Text(phone), onTap: () => launchUrl(Uri(scheme: 'tel', path: phone))),
          if (phone != null)
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => launchUrl(Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication),
            ),
          if (email != null)
            ListTile(leading: const Icon(Icons.mail_outline), title: Text(email), onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
        ]),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out', style: TextStyle(color: Color(0xFFD32F2F)))),
        ],
      ),
    );
    if (ok != true) return;
    await DyspatchApi.logout(fcmToken: PushService.instance.token);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

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

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── ACCOUNT ───────────────────────────────────────
                    const SectionLabel(label: "ACCOUNT"),
                    const SizedBox(height: 8),
                    MenuCard(
                      items: [
                        MenuItem(
                          icon: Icons.lock_reset_outlined,
                          label: "Change Password",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          ),
                        ),
                        MenuItem(
                          icon: Icons.verified_user_outlined,
                          label: "Two-Factor Authentification",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Autehtication(),
                            ),
                          ),
                        ),
                        MenuItem(
                          icon: Icons.business_center_outlined,
                          label: "Business Verification",
                          showDivider: false,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BusinessVerificationScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── PREFERENCES ───────────────────────────────────
                    const SectionLabel(label: "PREFERENCES"),
                    const SizedBox(height: 8),
                    _PreferencesCard(
                      lightMode: !themeProvider.isDarkMode,
                      autoAssignRiders: _autoAssignRiders,
                      onLightModeChanged: (val) {
                        themeProvider.toggleTheme();
                      },
                      onAutoAssignChanged: _setAutoAssign,
                      onDeliveryTypeTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryTypeScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── SUPPORT & LEGAL ───────────────────────────────
                    const SectionLabel(label: "SUPPORT & LEGAL"),
                    const SizedBox(height: 8),
                    MenuCard(
                      items: [
                        MenuItem(
                          icon: Icons.help_outline,
                          label: "Help Center",
                          onTap: () => launchUrl(Uri.parse('https://www.dyspatch.com.ng/#faq'), mode: LaunchMode.externalApplication),
                        ),
                        MenuItem(
                          icon: Icons.headset_mic_outlined,
                          label: "Contact Support",
                          onTap: _contactSupport,
                        ),
                        MenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: "Terms & Privacy",
                          showDivider: false,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsAndPrivacyScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Log out ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(
                            color: Color(0xFFFFCDD2),
                            width: 1.5,
                          ),
                          backgroundColor: const Color(0xFFFFF5F5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            color: Color(0xFFD32F2F),
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

// ─────────────────────────────────────────────────────────────────────────────
// Preferences card — has toggles + a nav row, so can't use plain MenuCard
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final bool lightMode;
  final bool autoAssignRiders;
  final ValueChanged<bool> onLightModeChanged;
  final ValueChanged<bool> onAutoAssignChanged;
  final VoidCallback onDeliveryTypeTap;

  const _PreferencesCard({
    required this.lightMode,
    required this.autoAssignRiders,
    required this.onLightModeChanged,
    required this.onAutoAssignChanged,
    required this.onDeliveryTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      child: Column(
        children: [
          // Light Mode toggle
          _ToggleRow(
            icon: Icons.wb_sunny_outlined,
            label: "Light Mode",
            value: lightMode,
            onChanged: onLightModeChanged,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 50,
            endIndent: 16,
            color: Colors.grey.shade400,
          ),

          // Language
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                 Icon(
                  Icons.language_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "Language",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                Text(
                  "EN",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 50,
            endIndent: 16,
            color: Colors.grey.shade400,
          ),

          // Default Delivery Type
          InkWell(
            onTap: onDeliveryTypeTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Default Delivery Type",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onTertiaryContainer),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 50,
            endIndent: 16,
            color: Colors.grey.shade400,
          ),

          // Auto-Assign Riders toggle
          _ToggleRow(
            icon: Icons.people_outline,
            label: "Auto-Assign Riders",
            value: autoAssignRiders,
            onChanged: onAutoAssignChanged,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onTertiaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style:  TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF1D5E2E),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE0E0E0),
            ),
          ),
        ],
      ),
    );
  }
}