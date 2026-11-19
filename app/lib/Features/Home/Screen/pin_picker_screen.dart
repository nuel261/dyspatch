import 'dart:async';

import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Drop a pin: the user drags the map under a fixed centre pin. Returns
/// {name, address, lat, lng, pinned: true} or null if they back out.
class PinPickerScreen extends StatefulWidget {
  final String title;
  final double? lat;
  final double? lng;
  const PinPickerScreen({super.key, this.title = 'Drop a pin', this.lat, this.lng});

  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  static const _beninCity = LatLng(6.3350, 5.6037);
  static const _green = Color(0xFF298341);
  final _map = MapController();
  late LatLng _center;
  String? _address;
  bool _looking = false;
  bool _moving = false;
  Timer? _t;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _center = widget.lat != null && widget.lng != null ? LatLng(widget.lat!, widget.lng!) : _beninCity;
    _lookup();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _lookup() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 500), () async {
      final seq = ++_seq;
      setState(() => _looking = true);
      try {
        final r = await DyspatchApi.reverse(_center.latitude, _center.longitude);
        if (mounted && seq == _seq) setState(() => _address = r['address'] as String?);
      } catch (_) {
        if (mounted && seq == _seq) setState(() => _address = null);
      } finally {
        if (mounted && seq == _seq) setState(() => _looking = false);
      }
    });
  }

  Future<void> _myLocation() async {
    try {
      final p = await LocationService.current();
      _center = LatLng(p.latitude, p.longitude);
      _map.move(_center, 17);
      _lookup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coords = '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: widget.lat != null ? 17 : 13,
            onPositionChanged: (pos, hasGesture) {
              _center = pos.center;
              if (hasGesture && !_moving) setState(() => _moving = true);
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd || e is MapEventScrollWheelZoom) {
                if (_moving) setState(() => _moving = false);
                _lookup();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.dyspatch.delivery',
              maxNativeZoom: 19,
              tileBuilder: isDark ? darkModeTileBuilder : null,
            ),
          ],
        ),
        // Fixed centre pin (its tip sits exactly on the map centre).
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _moving ? -26 : -20),
              child: const Icon(Icons.location_on, size: 44, color: _green),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 190,
          child: FloatingActionButton.small(
            heroTag: 'pin-my-loc',
            onPressed: _myLocation,
            backgroundColor: cs.surface,
            child: const Icon(Icons.my_location, color: _green),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Move the map to put the pin on the exact spot',
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _looking ? 'Finding address…' : (_address ?? 'Pinned location'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(coords, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _moving
                        ? null
                        : () => Navigator.pop(context, {
                              'name': (_address?.split(',').first.trim().isNotEmpty ?? false) ? _address!.split(',').first.trim() : 'Pinned location',
                              'address': _address ?? coords,
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'pinned': true,
                            }),
                    child: const Text('Use this location',
                        style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
