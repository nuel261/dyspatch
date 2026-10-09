import 'dart:async';

import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

/// Saved places (home, shop, office…) and the default pickup location.
class SavedLocationsScreen extends StatefulWidget {
  /// Opened from "Default pickup location": new places are saved as the default.
  final bool pickDefault;
  const SavedLocationsScreen({super.key, this.pickDefault = false});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DyspatchApi.savedLocations();
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final place = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PlaceSearchSheet(),
    );
    if (place == null || !mounted) return;
    final labelCtl = TextEditingController(text: widget.pickDefault ? 'Pickup' : 'Home');
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this place', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17)),
        content: TextField(controller: labelCtl, decoration: const InputDecoration(hintText: 'e.g. Home, Shop, Office')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, labelCtl.text.trim()), child: const Text('Save', style: TextStyle(color: Color(0xFF298341)))),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    try {
      await DyspatchApi.saveLocation(label, place['label'] as String, (place['lat'] as num).toDouble(), (place['lng'] as num).toDouble(),
          defaultPickup: widget.pickDefault);
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await DyspatchApi.deleteLocation(id);
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFF298341),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(widget.pickDefault ? 'Set pickup location' : 'Add place', style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(children: [
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
              Expanded(
                child: Center(
                  child: Text(widget.pickDefault ? 'Default pickup' : 'Saved locations',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Montserrat', fontSize: 20)),
                ),
              ),
              const SizedBox(width: 40),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF298341)))
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Save places you send from often to fill pickup faster.',
                              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF5F6368))),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: _items
                            .map((l) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
                                  child: ListTile(
                                    leading: Icon(l['is_default_pickup'] == true ? Icons.star_rounded : Icons.place_outlined, color: const Color(0xFF298341)),
                                    title: Text((l['label'] ?? '') as String, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${l['address']}${l['is_default_pickup'] == true ? '\nDefault pickup' : ''}',
                                      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                                    ),
                                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete((l['id'] as num).toInt())),
                                  ),
                                ))
                            .toList(),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet();
  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  Timer? _t;
  List<Map<String, dynamic>> _results = [];
  bool _busy = false;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _search(String q) {
    _t?.cancel();
    if (q.trim().length < 3) return;
    _t = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _busy = true);
      try {
        final r = await DyspatchApi.searchPlaces(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search address',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(color: Color(0xFF298341), minHeight: 2),
          Expanded(
            child: ListView(
              children: _results.map((p) {
                final name = (p['name'] ?? '') as String;
                final addr = (p['address'] ?? '') as String;
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(name, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                  subtitle: Text(addr, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                  onTap: () => Navigator.pop(context, {...p, 'label': addr.isNotEmpty && addr != name ? '$name, $addr' : name}),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}
