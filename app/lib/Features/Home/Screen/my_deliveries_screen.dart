import 'package:dyspatch_app/Features/Home/Screen/delivery_card.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:dyspatch_app/Features/Home/model/delivery_model.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:flutter/material.dart';

/// Full delivery history with Active / Completed filters.
class MyDeliveriesScreen extends StatefulWidget {
  const MyDeliveriesScreen({super.key});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  String _filter = 'all';
  List<DeliveryModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _items.isEmpty);
    try {
      final rows = await DyspatchApi.orders(status: _filter, limit: 100);
      if (!mounted) return;
      setState(() {
        _items = rows.map(DeliveryModel.fromJson).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _chip(String key, String label) {
    final on = _filter == key;
    return GestureDetector(
      onTap: () {
        if (on) return;
        setState(() {
          _filter = key;
          _items = [];
        });
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF298341).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? Colors.transparent : const Color(0xFFE3E7EB)),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600, color: on ? const Color(0xFF298341) : const Color(0xFF5F6368))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(color: cs.tertiaryContainer, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const Expanded(
                  child: Center(child: Text('My deliveries', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Montserrat', fontSize: 20))),
                ),
                const SizedBox(width: 40),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [_chip('all', 'All'), const SizedBox(width: 8), _chip('active', 'Active'), const SizedBox(width: 8), _chip('completed', 'Completed')]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF298341)))
                  : RefreshIndicator(
                      color: const Color(0xFF298341),
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(_error ?? 'No deliveries here yet.',
                                    textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Montserrat', color: Color(0xFF5F6368))),
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, i) => GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(initialTrackId: _items[i].trackId))).then((_) => _load()),
                                child: DeliveryCard(delivery: _items[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
