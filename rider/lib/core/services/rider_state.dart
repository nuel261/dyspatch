import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/rider_api.dart';
import '../api/session.dart';
import '../ui/format.dart';
import 'location_service.dart';
import 'push_service.dart';

/// One job offer from GET /rider/offers.
class Offer {
  final int id;
  final int orderId;
  final DateTime expiresAt;
  final int expiresIn;
  final double toPickupKm;
  final double tripKm;
  final int earningKobo;
  final int feeKobo;
  final String pickup;
  final String dropoff;
  final double pickupLat, pickupLng, dropoffLat, dropoffLng;
  final String packageType;
  final String paymentMethod;

  Offer.fromJson(Map<String, dynamic> j)
      : id = (j['offer_id'] as num).toInt(),
        orderId = (j['order_id'] as num).toInt(),
        expiresIn = (j['expires_in'] as num?)?.toInt() ?? 45,
        expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 45)),
        toPickupKm = (j['distance_to_pickup_km'] as num?)?.toDouble() ?? 0,
        tripKm = (j['trip_km'] as num?)?.toDouble() ?? 0,
        earningKobo = (j['earning_kobo'] as num?)?.toInt() ?? 0,
        feeKobo = (j['fee_kobo'] as num?)?.toInt() ?? 0,
        pickup = (j['pickup']?['address'] as String?) ?? '',
        dropoff = (j['dropoff']?['address'] as String?) ?? '',
        pickupLat = (j['pickup']?['lat'] as num?)?.toDouble() ?? 0,
        pickupLng = (j['pickup']?['lng'] as num?)?.toDouble() ?? 0,
        dropoffLat = (j['dropoff']?['lat'] as num?)?.toDouble() ?? 0,
        dropoffLng = (j['dropoff']?['lng'] as num?)?.toDouble() ?? 0,
        packageType = (j['package_type'] as String?) ?? 'small',
        paymentMethod = (j['payment_method'] as String?) ?? 'wallet';

  int get secondsLeft => expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
  bool get isCash => paymentMethod == 'cash';
}

/// App-wide rider state: online/offline, live offers, the active delivery and today's numbers.
///
/// Offers arrive two ways, so a rider never misses one:
///   1. Push (FCM) — instant, rings even when the app is closed.
///   2. Polling — every 4 s while online (the location foreground service keeps the app
///      alive in the background), which also covers phones where push isn't set up yet.
class RiderState extends ChangeNotifier with WidgetsBindingObserver {
  RiderState._();
  static final RiderState instance = RiderState._();

  static const _kOnline = 'dsr_online';

  bool online = false;
  bool busy = false;
  Map<String, dynamic>? me;
  final List<Offer> offers = [];
  final Set<int> _alerted = {};
  int? activeOrderId;
  Map<String, dynamic>? activeOrder;
  Timer? _offerTimer;
  Timer? _meTimer;
  bool _started = false;

  Offer? get currentOffer => offers.isEmpty ? null : offers.first;
  int get todayEarningsKobo => (me?['today_earnings_kobo'] as num?)?.toInt() ?? 0;
  int get todayDeliveries => (me?['today_deliveries'] as num?)?.toInt() ?? 0;
  int get walletKobo => (me?['wallet_balance_kobo'] as num?)?.toInt() ?? 0;
  double get rating => (me?['rating'] as num?)?.toDouble() ?? 0;

  /// Call once after login (and on app start when already logged in).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final push = PushService.instance;
    push.onOfferPushed = (_) => pollOffers(fromPush: true);
    push.onOfferClosed = (d) => _dropOffer(int.tryParse('${d['offer_id']}'));
    push.onUpdate = (d) {
      if (d['status'] == 'cancelled' || d['type'] == 'order') refresh();
    };
    push.onOpen = (_) => refresh();
    await refresh();
    final p = await SharedPreferences.getInstance();
    if ((p.getBool(_kOnline) ?? false) && Session.instance.canWork) {
      await goOnline(silent: true);
    } else if (activeOrderId != null) {
      await LocationService.instance.startTracking();
    }
    _meTimer = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  Future<void> stop() async {
    _offerTimer?.cancel();
    _meTimer?.cancel();
    _offerTimer = _meTimer = null;
    await LocationService.instance.stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    online = false;
    offers.clear();
    me = null;
    activeOrder = null;
    activeOrderId = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      if (online) pollOffers();
    }
  }

  /// Reloads profile, today's stats and the active delivery.
  Future<void> refresh() async {
    if (!Session.instance.isLoggedIn) return;
    try {
      me = await RiderApi.me();
      await Session.instance.updateRider(me!);
      online = me!['is_online'] == true;
      final newActive = (me!['active_order_id'] as num?)?.toInt();
      if (newActive != activeOrderId) {
        activeOrderId = newActive;
        activeOrder = null;
      }
      if (activeOrderId != null) {
        activeOrder = await RiderApi.order(activeOrderId!);
        await LocationService.instance.startTracking();
      } else if (!online) {
        await LocationService.instance.stopTracking();
      }
      notifyListeners();
    } catch (_) {/* offline — keep last state */}
  }

  Future<String?> goOnline({bool silent = false}) async {
    if (!Session.instance.canWork) return 'Your account must be verified before you can go online.';
    busy = true;
    notifyListeners();
    try {
      if (!await LocationService.instance.ensurePermission(openSettingsIfOff: true)) {
        return 'Turn on location and allow Dyspatch to use it, so we can send you nearby jobs.';
      }
      if (!silent) await PushService.instance.requestPermissionAndRegister();
      final p = await LocationService.instance.current();
      await RiderApi.setOnline(true, lat: p?.latitude, lng: p?.longitude);
      online = true;
      await LocationService.instance.startTracking();
      LocationService.instance.sendNow();
      (await SharedPreferences.getInstance()).setBool(_kOnline, true);
      _offerTimer?.cancel();
      _offerTimer = Timer.periodic(const Duration(seconds: 4), (_) => pollOffers());
      await pollOffers();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> goOffline() async {
    busy = true;
    notifyListeners();
    try {
      await RiderApi.setOnline(false);
      online = false;
      _offerTimer?.cancel();
      _offerTimer = null;
      for (final o in offers) {
        PushService.instance.cancelOfferAlert(o.id);
      }
      offers.clear();
      if (activeOrderId == null) await LocationService.instance.stopTracking();
      (await SharedPreferences.getInstance()).setBool(_kOnline, false);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool _polling = false;
  Future<void> pollOffers({bool fromPush = false}) async {
    if (_polling || !Session.instance.isLoggedIn) return;
    _polling = true;
    try {
      final list = (await RiderApi.offers()).map(Offer.fromJson).toList();
      final ids = list.map((o) => o.id).toSet();
      for (final o in offers.where((o) => !ids.contains(o.id))) {
        PushService.instance.cancelOfferAlert(o.id);
      }
      offers
        ..clear()
        ..addAll(list);
      notifyListeners();
      for (final o in list) {
        if (_alerted.add(o.id)) {
          // Ring for every new offer. A pushed offer already rang via FCM when the app was
          // in the background; in the foreground (or with no push) this local alert rings.
          try {
            await PushService.instance.showOfferAlert(o.id, 'New delivery request · ${naira(o.earningKobo)}',
                'Pickup ${km(o.toPickupKm)} away · ${o.pickup}', expiresIn: o.secondsLeft);
          } catch (_) {/* no local notifications on this platform */}
        }
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void _dropOffer(int? id) {
    if (id == null) return;
    offers.removeWhere((o) => o.id == id);
    PushService.instance.cancelOfferAlert(id);
    notifyListeners();
  }

  /// Accept → returns the order on success, or throws with the server's message
  /// (e.g. "Another rider accepted this job first").
  Future<Map<String, dynamic>> accept(Offer o) async {
    try {
      final order = await RiderApi.accept(o.id);
      activeOrderId = (order['id'] as num).toInt();
      activeOrder = order;
      for (final x in offers) {
        PushService.instance.cancelOfferAlert(x.id);
      }
      offers.clear();
      await LocationService.instance.startTracking();
      notifyListeners();
      refresh();
      return order;
    } catch (e) {
      _dropOffer(o.id);
      rethrow;
    }
  }

  Future<void> decline(Offer o) async {
    _dropOffer(o.id);
    try {
      await RiderApi.decline(o.id);
    } catch (_) {}
  }

  /// Called by the job screen after each status change.
  void setActiveOrder(Map<String, dynamic>? order) {
    final done = order == null || ['delivered', 'cancelled', 'failed'].contains(order['status']);
    activeOrder = done ? null : order;
    activeOrderId = done ? null : (order['id'] as num).toInt();
    if (done && !online) LocationService.instance.stopTracking();
    notifyListeners();
    if (done) refresh();
  }
}
