import 'package:dyspatch_rider/Features/Home/widget/ride_tabs.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Earning/add_account_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Earning/wallet_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _EarningTab {
  final String label;
  final String balance;
  final int ordersReceived;
  final int ordersDelivered;

  const _EarningTab({
    required this.label,
    required this.balance,
    required this.ordersReceived,
    required this.ordersDelivered,
  });
}

class EarningScreen extends StatefulWidget {
  const EarningScreen({super.key});

  @override
  State<EarningScreen> createState() => _EarningScreenState();
}

class _EarningScreenState extends State<EarningScreen> {
  bool _balanceVisible = true;
  int _selectedTab = 0;

  final List<_EarningTab> _tabs = const [
    _EarningTab(
      label: 'Total',
      balance: '₦180,000.00',
      ordersReceived: 2200,
      ordersDelivered: 1728,
    ),
    _EarningTab(
      label: 'Ride 1',
      balance: '₦34,800.00',
      ordersReceived: 200,
      ordersDelivered: 128,
    ),
    _EarningTab(
      label: 'Ride 2',
      balance: '₦28,400.00',
      ordersReceived: 180,
      ordersDelivered: 140,
    ),
    _EarningTab(
      label: 'Ride 3',
      balance: '₦41,200.00',
      ordersReceived: 250,
      ordersDelivered: 210,
    ),
    _EarningTab(
      label: 'Ride 4',
      balance: '₦19,600.00',
      ordersReceived: 130,
      ordersDelivered: 90,
    ),
    _EarningTab(
      label: 'Ride 5',
      balance: '₦56,000.00',
      ordersReceived: 1440,
      ordersDelivered: 1160,
    ),
  ];

  // Riders who aren't fleet owners only have their own total.
  _EarningTab get _current =>
      _tabs[RiderSession.isFleetOwner ? _selectedTab : 0];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Wallet",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // refresh action, wire to real refresh logic
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalletHistoryScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ),
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
                    // Fleet owners: Total, then one tab per ride.
                    if (RiderSession.isFleetOwner) ...[
                      RideTabs(
                        labels: [for (final t in _tabs) t.label],
                        selected: _selectedTab,
                        onSelected: (i) => setState(() => _selectedTab = i),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Balance ───────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "CURRENT BALANCE",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F6368),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _balanceVisible ? _current.balance : "₦ ••••••",
                                style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _balanceVisible = !_balanceVisible,
                                ),
                                child: Icon(
                                  _balanceVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // ── Orders Received / Delivered ──
                          Text(
                            "Order Received: ${_current.ordersReceived}  •  Order Delivered: ${_current.ordersDelivered}",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Account label ────────────────────────────────
                    const Text(
                      "Account 1",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Bank card ────────────────────────────────────
                    const _BankCard(),

                    const SizedBox(height: 20),

                    // ── Change Account / Add ────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF298341,
                              ).withOpacity(0.10),
                              foregroundColor: const Color(0xFF298341),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Change Account",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddAccountScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              "Add",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF298341),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
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
// Bank card
// ─────────────────────────────────────────────────────────────────────────────

class _BankCard extends StatelessWidget {
  const _BankCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CA661), Color(0xFF0E2E18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "GT Bank",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            "DAN-JOHN CHIBUZOR DANIEL",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: '3124209490'));
            },
            child: const Text(
              "312  4209  490",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
