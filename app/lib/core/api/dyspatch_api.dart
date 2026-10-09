import 'api_client.dart';
import 'session.dart';

/// All backend calls in one place, grouped by feature.
class DyspatchApi {
  static final _c = ApiClient.instance;

  // ── App config ──
  static Map<String, dynamic>? _config;
  static Future<Map<String, dynamic>> config({bool refresh = false}) async {
    if (_config != null && !refresh) return _config!;
    return _config = Map<String, dynamic>.from(await _c.get('/config'));
  }

  // ── Auth ──
  static Future<Map<String, dynamic>> requestOtp(String phone) async =>
      Map<String, dynamic>.from(await _c.post('/auth/otp/request', {'phone': phone}));

  static Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final d = Map<String, dynamic>.from(await _c.post('/auth/otp/verify', {'phone': phone, 'code': code, 'device': 'Dyspatch app'}));
    await Session.instance.save(d['token'], Map<String, dynamic>.from(d['user']));
    return d;
  }

  static Future<Map<String, dynamic>> googleSignIn(String firebaseIdToken) async {
    final d = Map<String, dynamic>.from(await _c.post('/auth/google', {'id_token': firebaseIdToken, 'device': 'Dyspatch app'}));
    await Session.instance.save(d['token'], Map<String, dynamic>.from(d['user']));
    return d;
  }

  static Future<void> logout({String? fcmToken}) async {
    try {
      await _c.post('/auth/logout', {if (fcmToken != null) 'fcm_token': fcmToken});
    } catch (_) {}
    await Session.instance.clear();
  }

  // ── Profile ──
  static Future<Map<String, dynamic>> me() async {
    final d = Map<String, dynamic>.from(await _c.get('/me'));
    await Session.instance.updateUser(d);
    return d;
  }

  static Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async {
    final d = Map<String, dynamic>.from(await _c.put('/me', fields));
    await Session.instance.updateUser(d);
    return d;
  }

  static Future<void> changePassword(String current, String next) =>
      _c.post('/me/password', {'current_password': current, 'new_password': next});
  static Future<Map<String, dynamic>> request2fa() async => Map<String, dynamic>.from(await _c.post('/me/2fa/request'));
  static Future<void> verify2fa(String code, {bool enable = true}) => _c.post('/me/2fa/verify', {'code': code, 'enable': enable});
  static Future<void> registerDevice(String token, String platform) => _c.post('/devices', {'fcm_token': token, 'platform': platform});

  // ── Places ──
  static Future<List<Map<String, dynamic>>> searchPlaces(String q, {double? lat, double? lng}) async =>
      List<Map<String, dynamic>>.from(await _c.get('/places/search', query: {'q': q, 'lat': lat, 'lng': lng}));
  static Future<Map<String, dynamic>> reverse(double lat, double lng) async =>
      Map<String, dynamic>.from(await _c.get('/places/reverse', query: {'lat': lat, 'lng': lng}));

  // ── Orders ──
  static Future<List<Map<String, dynamic>>> orders({String status = 'all', int limit = 30}) async =>
      List<Map<String, dynamic>>.from(await _c.get('/orders', query: {'status': status, 'limit': limit}));
  static Future<Map<String, dynamic>> quote(Map<String, dynamic> body) async => Map<String, dynamic>.from(await _c.post('/orders/quote', body));
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async => Map<String, dynamic>.from(await _c.post('/orders', body));

  /// Own order (full details incl. codes). Falls back to public tracking for packages sent by others / guests.
  static Future<Map<String, dynamic>> order(String code) async {
    final c = Uri.encodeComponent(code.trim().toUpperCase());
    if (Session.instance.isLoggedIn) {
      try {
        return Map<String, dynamic>.from(await _c.get('/orders/$c'));
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }
    return Map<String, dynamic>.from(await _c.get('/track/$c'));
  }

  static Future<Map<String, dynamic>> riderLocation(String code) async =>
      Map<String, dynamic>.from(await _c.get('/orders/${Uri.encodeComponent(code)}/rider-location'));
  static Future<String> shareLink(String code) async => (await _c.post('/orders/${Uri.encodeComponent(code)}/share-link'))['url'] as String;
  static Future<void> sos(String code, double? lat, double? lng) =>
      _c.post('/orders/${Uri.encodeComponent(code)}/sos', {'user_lat': lat, 'user_lng': lng, 'message': 'User flagged a safety concern'});
  static Future<Map<String, dynamic>> cancelOrder(String code, String reason) async =>
      Map<String, dynamic>.from(await _c.post('/orders/${Uri.encodeComponent(code)}/cancel', {'reason': reason}));
  static Future<String> regenerateCode(String code) async =>
      (await _c.post('/orders/${Uri.encodeComponent(code)}/regenerate-code'))['delivery_code'] as String;
  static Future<void> rateRider(String code, int rating) => _c.post('/orders/${Uri.encodeComponent(code)}/rate', {'rating': rating});

  // ── Wallet ──
  static Future<Map<String, dynamic>> wallet() async => Map<String, dynamic>.from(await _c.get('/wallet'));
  static Future<List<Map<String, dynamic>>> transactions({String filter = 'all'}) async =>
      List<Map<String, dynamic>>.from(await _c.get('/wallet/transactions', query: {'filter': filter}));
  static Future<Map<String, dynamic>> startTopup() async => Map<String, dynamic>.from(await _c.post('/wallet/topups'));
  static Future<void> topupSent(String ref, {int? amountKobo}) =>
      _c.post('/wallet/topups/$ref/sent', {if (amountKobo != null && amountKobo > 0) 'amount': (amountKobo / 100).toStringAsFixed(2)});
  static Future<Map<String, dynamic>> withdrawalFee(int amountKobo) async =>
      Map<String, dynamic>.from(await _c.get('/wallet/withdrawal-fee', query: {'amount': (amountKobo / 100).toStringAsFixed(2)}));
  static Future<Map<String, dynamic>> withdraw(int bankAccountId, int amountKobo) async =>
      await _c.postEnvelope('/wallet/withdraw', {'bank_account_id': bankAccountId, 'amount': (amountKobo / 100).toStringAsFixed(2)});
  static Future<List<Map<String, dynamic>>> bankAccounts() async => List<Map<String, dynamic>>.from(await _c.get('/bank-accounts'));
  static Future<Map<String, dynamic>> addBankAccount(String bank, String name, String number, {String? bankCode}) async =>
      await _c.postEnvelope('/bank-accounts', {'bank_name': bank, 'account_name': name, 'account_number': number, if (bankCode != null) 'bank_code': bankCode});
  static Future<void> setDefaultBank(int id) => _c.post('/bank-accounts/$id/default');
  static Future<List<Map<String, dynamic>>> banks() async => List<Map<String, dynamic>>.from(await _c.get('/banks'));

  // ── Notifications ──
  static Future<List<Map<String, dynamic>>> notifications({String? category}) async =>
      List<Map<String, dynamic>>.from(await _c.get('/notifications', query: {'category': category}));
  static Future<void> markNotificationsRead() => _c.post('/notifications/read');

  // ── Business verification ──
  static Future<Map<String, dynamic>?> businessVerification() async {
    final d = await _c.get('/business-verification');
    return d == null ? null : Map<String, dynamic>.from(d);
  }

  static Future<Map<String, dynamic>> submitBusinessVerification(Map<String, dynamic> body) async =>
      await _c.postEnvelope('/business-verification', body);

  // ── Saved locations ──
  static Future<List<Map<String, dynamic>>> savedLocations() async => List<Map<String, dynamic>>.from(await _c.get('/saved-locations'));
  static Future<void> saveLocation(String label, String address, double? lat, double? lng, {bool defaultPickup = false}) =>
      _c.post('/saved-locations', {'label': label, 'address': address, 'lat': lat, 'lng': lng, 'is_default_pickup': defaultPickup});
  static Future<void> deleteLocation(int id) => _c.delete('/saved-locations/$id');
}
