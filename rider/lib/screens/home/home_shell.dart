import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/rider_state.dart';
import '../../core/ui/theme.dart';
import '../account/account_tab.dart';
import '../earnings/earnings_tab.dart';
import '../job/jobs_tab.dart';
import '../job/offer_screen.dart';
import 'home_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int? _showingOffer;

  @override
  void initState() {
    super.initState();
    RiderState.instance.start();
    RiderState.instance.addListener(_maybeShowOffer);
  }

  @override
  void dispose() {
    RiderState.instance.removeListener(_maybeShowOffer);
    super.dispose();
  }

  /// A new offer pops up full screen wherever the rider is in the app.
  void _maybeShowOffer() {
    final o = RiderState.instance.currentOffer;
    if (o == null || _showingOffer != null || !mounted) return;
    _showingOffer = o.id;
    Navigator.of(context)
        .push(PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black54,
          pageBuilder: (_, __, ___) => OfferScreen(offer: o),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ))
        .then((accepted) {
      _showingOffer = null;
      if (accepted == true && mounted) setState(() => _tab = 0);
      Future.microtask(_maybeShowOffer); // another offer may be waiting
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasJob = context.watch<RiderState>().activeOrderId != null;
    final pages = [
      HomeTab(onOpenTab: (i) => setState(() => _tab = i)),
      const JobsTab(),
      const EarningsTab(),
      const AccountTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: context.card,
          indicatorColor: brandGreen.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
                color: s.contains(WidgetState.selected) ? brandGreen : inkGrey)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? brandGreen : inkGrey)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          height: 66,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
              icon: Badge(isLabelVisible: hasJob, backgroundColor: brandGreen, smallSize: 8, child: const Icon(Icons.inventory_2_outlined)),
              selectedIcon: const Icon(Icons.inventory_2_rounded),
              label: 'Jobs',
            ),
            const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
          ],
        ),
      ),
    );
  }
}
