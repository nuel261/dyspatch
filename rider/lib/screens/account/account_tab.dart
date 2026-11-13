import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/rider_api.dart';
import '../../core/api/session.dart';
import '../../core/services/push_service.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../earnings/bank_accounts_screen.dart';
import '../onboarding/profile_setup_screen.dart';
import '../onboarding/verification_screen.dart';
import '../onboarding/welcome_screen.dart';
import 'notifications_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  Future<void> _support(BuildContext context, bool call) async {
    try {
      final c = await RiderApi.config();
      final v = (call ? c['support_phone'] : c['support_email']) as String?;
      if (v == null || v.isEmpty) throw 'Support contact not set yet';
      await launchUrl(Uri.parse(call ? 'tel:$v' : 'mailto:$v?subject=Rider support'));
    } catch (e) {
      if (context.mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll go offline and stop receiving delivery requests."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out', style: TextStyle(color: dangerRed))),
        ],
      ),
    );
    if (ok != true) return;
    if (RiderState.instance.online) await RiderState.instance.goOffline();
    await RiderApi.logout(fcmToken: await PushService.instance.currentToken());
    await RiderState.instance.stop();
    await Session.instance.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final r = s.rider ?? {};
    final photo = r['photo'] as String?;
    final kyc = s.kycStatus;
    final (kycLabel, kycColor) = switch (kyc) {
      'verified' => ('Verified', brandGreen),
      'submitted' => ('In review', warnAmber),
      'rejected' => ('Action needed', dangerRed),
      _ => ('Not started', inkGrey),
    };
    final theme = context.watch<ThemeProvider>();
    Widget tile(IconData i, String t, {String? sub, Widget? trailing, VoidCallback? onTap, Color? color}) => ListTile(
          leading: Icon(i, color: color ?? context.ink),
          title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: color ?? context.ink)),
          subtitle: sub != null ? Text(sub, style: const TextStyle(fontSize: 12.5, color: inkGrey)) : null,
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: inkGrey) : null),
          onTap: onTap,
        );
    Widget group(List<Widget> children) => AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children));

    return Scaffold(
      appBar: appBar(context, 'Account'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        AppCard(
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: brandGreen.withValues(alpha: 0.12),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null ? Text(s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, color: brandGreen, fontWeight: FontWeight.w700)) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.fullName.isEmpty ? 'Rider' : s.fullName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 2),
                Text(r['phone'] as String? ?? '', style: const TextStyle(color: inkGrey, fontSize: 13)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B400)),
                  Text(' ${((r['rating'] as num?) ?? 0) > 0 ? (r['rating'] as num).toStringAsFixed(1) : 'New'}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.ink)),
                  const SizedBox(width: 10),
                  StatusPill(kycLabel, color: kycColor),
                ]),
              ]),
            ),
          ]),
        ),
        const SectionLabel('Work'),
        group([
          tile(Icons.badge_outlined, 'Verification', sub: kycLabel,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen(fromAccount: true)))),
          tile(Icons.two_wheeler, 'Profile & vehicle', sub: '${vehicleTypes[r['vehicle_type']]?.$1 ?? 'Not set'}${(r['plate'] as String? ?? '').isNotEmpty ? ' · ${r['plate']}' : ''}',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen(editing: true)))),
          tile(Icons.account_balance_outlined, 'Bank accounts', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen()))),
        ]),
        const SectionLabel('App'),
        group([
          tile(Icons.notifications_outlined, 'Notifications', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          tile(Icons.volume_up_outlined, 'Test the job alert', sub: PushService.instance.fcmReady ? 'Push notifications are on' : 'Offers arrive while you are online',
              onTap: () => PushService.instance.showOfferAlert(0, 'Test · New delivery request', 'This is how a new job will sound.', expiresIn: 10)),
          tile(Icons.dark_mode_outlined, 'Dark mode', trailing: Switch(value: theme.isDarkMode, activeThumbColor: brandGreen, onChanged: (_) => theme.toggleTheme())),
        ]),
        const SectionLabel('Help'),
        group([
          tile(Icons.call_outlined, 'Call rider support', onTap: () => _support(context, true)),
          tile(Icons.mail_outline, 'Email support', onTap: () => _support(context, false)),
          tile(Icons.description_outlined, 'Rider terms & privacy',
              onTap: () => launchUrl(Uri.parse('https://dyspatch.com.ng/privacy-terms'), mode: LaunchMode.externalApplication)),
        ]),
        const SizedBox(height: 16),
        group([tile(Icons.logout, 'Sign out', color: dangerRed, onTap: () => _logout(context))]),
        const SizedBox(height: 16),
        const Center(child: Text('Dyspatch Rider 1.0.0', style: TextStyle(color: inkGrey, fontSize: 12))),
      ]),
    );
  }
}
