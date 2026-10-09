import 'package:dyspatch_app/Features/Home/Screen/create_delivery.dart';
import 'package:dyspatch_app/Features/Home/Screen/delivery_card.dart';
import 'package:dyspatch_app/Features/Home/Screen/notification_screen.dart';
import 'package:dyspatch_app/Features/Home/model/delivery_model.dart';
import 'package:dyspatch_app/Features/Home/widget/truck_card.dart';
import 'package:dyspatch_app/Features/Home/Screen/my_deliveries_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeContent extends StatefulWidget {
  /// Switches the bottom-nav tab (e.g. 1 = Track) when embedded in HomeScreen.
  final void Function(int tab)? onSwitchTab;
  const HomeContent({super.key, this.onSwitchTab});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<DeliveryModel> _deliveries = [];
  bool _loading = true;
  String? _error;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        DyspatchApi.orders(limit: 5),
        DyspatchApi.me(),
      ]);
      if (!mounted) return;
      setState(() {
        _deliveries = (results[0] as List<Map<String, dynamic>>).map(DeliveryModel.fromJson).toList();
        _unread = ((results[1] as Map)['unread_notifications'] as num?)?.toInt() ?? 0;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateDelivery()));
    _load();
  }

  void _openTrack([String? trackId]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(initialTrackId: trackId))).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ wrap with Scaffold
      backgroundColor: Theme.of(context).colorScheme.primary,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          // ✅ moved here
          onPressed: _openCreate,
          backgroundColor: const Color(0xFF298341),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF298341),
        onRefresh: _load,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Top Bar ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hello ${context.watch<Session>().firstName} ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF5F6368),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _shortAddress(context.watch<Session>().user?['address'] as String?),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5F6368),
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Handle notification tap
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        ).then((_) => _load());
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    if (_unread > 0) Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Search Bar ──
            GestureDetector(
              onTap: () => widget.onSwitchTab != null ? widget.onSwitchTab!(1) : _openTrack(),
              child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Color(0xFF5f6368), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Where's your package? Input track ID",
                      style: TextStyle(
                        color: Color(0xFF8A8F98),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.qr_code_scanner,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 40),

            // ── Loading / error / empty state OR deliveries ──
            if (_loading) ...[
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator(color: Color(0xFF298341))),
            ] else if (_error != null && _deliveries.isEmpty) ...[
              const SizedBox(height: 60),
              Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Montserrat', color: Color(0xFF5F6368)))),
              const SizedBox(height: 16),
              Center(child: TextButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Try again', style: TextStyle(color: Color(0xFF298341), fontWeight: FontWeight.w600)))),
            ] else if (_deliveries.isEmpty) ...[
              const SizedBox(height: 40),
              Center(
                child: SvgPicture.asset(
                  'assets/images/pana_4.svg',
                  height: 200,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'No deliveries yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Create your first delivery and we'll handle the rest\nfrom pickup to drop-off.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontFamily: 'Montserrat',
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF298341),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Delivery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ── Recent Deliveries Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Deliveries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  GestureDetector(
                    onTap: _openAll,
                    child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F6F73).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2F6F73),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  )),
                ],
              ),

              const SizedBox(height: 24),

              // ── Delivery Cards ──
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _deliveries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: GestureDetector(
                      onTap: () => _openTrack(_deliveries[index].trackId),
                      child: DeliveryCard(delivery: _deliveries[index]),
                    ),
                  );
                },
              ),

              Center(
                child: GestureDetector(
                  onTap: _openAll,
                  child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6F73).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F6F73),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                )),
              ),

              const SizedBox(height: 40),
              const TruckCard(),
              const SizedBox(height: 25),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _openAll() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDeliveriesScreen())).then((_) => _load());
  }

  String _shortAddress(String? a) {
    if (a == null || a.trim().isEmpty) return 'Set your address';
    return a.length > 22 ? '${a.substring(0, 20)}...' : a;
  }
}
