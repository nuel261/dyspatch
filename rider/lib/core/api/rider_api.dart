import 'dart:convert';
import 'dart:typed_data';

import 'api_client.dart';

/// Every backend call the rider app makes (see backend/api/index.php → "Rider app").
class RiderApi {
  RiderApi._();
  static final _c = ApiClient.instance;
  static Map<String, dynamic>? _config;

  static Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);
  static List<Map<String, dynamic>> _list(dynamic d) => (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  /// Image bytes → data URI the backend's upload handler accepts.
  static String dataUri(Uint8List bytes, {String mime = 'image/jpeg'}) => 'data:$mime;base64,${base64Encode(bytes)}';

  // ── Config ──
  static Future<Map<String, dynamic>> config({bool refresh = false}) async {
    if (_config != null && !refresh) return _config!;
    return _config = _map(await _c.get('/config'));
  }

  // ── Auth (same OTP flow as customers, with role = rider) ──
  static Future<Map<String, dynamic>> requestOtp(String phone) async =>
      _map(await _c.post('/auth/otp/request', {'phone': phone, 'role': 'rider'}));

  static Future<Map<String, dynamic>> verifyOtp(String phone, String code, {String? firstName, String? lastName}) async =>
      _map(await _c.post('/auth/otp/verify', {
        'phone': phone, 'code': code, 'role': 'rider', 'device': 'Dyspatch Rider app',
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      }));

  static Future<void> logout({String? fcmToken}) async {
    try {
      await _c.post('/auth/logout', {if (fcmToken != null) 'fcm_token': fcmToken});
    } catch (_) {}
  }

  static Future<void> registerDevice(String token, String platform) => _c.post('/devices', {'fcm_token': token, 'platform': platform});

  // ── Profile & verification ──
  static Future<Map<String, dynamic>> me() async => _map(await _c.get('/rider/me'));

  static Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async => _map(await _c.put('/rider/me', fields));

  static Future<Map<String, dynamic>> submitKyc({required String idType, required String idNumber, String? documentDataUri}) async =>
      _map(await _c.postEnvelope('/rider/kyc', {'id_type': idType, 'id_number': idNumber, if (documentDataUri != null) 'id_document': documentDataUri}));

  // ── Availability & location ──
  static Future<void> setOnline(bool online, {double? lat, double? lng}) =>
      _c.post('/rider/online', {'online': online, if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});

  static Future<Map<String, dynamic>> sendLocation(double lat, double lng, {double? heading, double? speed}) async =>
      _map(await _c.post('/rider/location', {'lat': lat, 'lng': lng, if (heading != null) 'heading': heading, if (speed != null) 'speed': speed}));

  // ── Job offers ──
  static Future<List<Map<String, dynamic>>> offers() async => _list(await _c.get('/rider/offers'));
  static Future<Map<String, dynamic>> accept(int offerId) async => _map(await _c.post('/rider/offers/$offerId/accept'));
  static Future<void> decline(int offerId) => _c.post('/rider/offers/$offerId/decline');

  // ── Deliveries ──
  static Future<List<Map<String, dynamic>>> orders({String status = 'all'}) async => _list(await _c.get('/rider/orders', query: {'status': status}));
  static Future<Map<String, dynamic>> order(int id) async => _map(await _c.get('/rider/orders/$id'));

  static Map<String, dynamic> _at(double? lat, double? lng) => {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng};

  static Future<Map<String, dynamic>> pickup(int id, String code, {double? lat, double? lng}) async =>
      _map(await _c.post('/rider/orders/$id/pickup', {'code': code, ..._at(lat, lng)}));
  static Future<Map<String, dynamic>> enRoute(int id, {double? lat, double? lng}) async => _map(await _c.post('/rider/orders/$id/en-route', _at(lat, lng)));
  static Future<Map<String, dynamic>> arrived(int id, {double? lat, double? lng}) async => _map(await _c.post('/rider/orders/$id/arrived', _at(lat, lng)));
  static Future<Map<String, dynamic>> deliver(int id, String code, {String? photoDataUri, double? lat, double? lng}) async =>
      _map(await _c.post('/rider/orders/$id/deliver', {'code': code, if (photoDataUri != null) 'photo': photoDataUri, ..._at(lat, lng)}));
  static Future<Map<String, dynamic>> fail(int id, String reason) async => _map(await _c.post('/rider/orders/$id/fail', {'reason': reason}));

  static Future<void> reportIssue(int id, String reason, {String? note}) =>
      _c.post('/rider/orders/$id/issue', {'reason': reason, if (note != null) 'note': note});
  static Future<void> sos(String message) => _c.post('/rider/sos', {'message': message});

  // ── Wallet & payouts ──
  static Future<Map<String, dynamic>> wallet() async => _map(await _c.get('/wallet'));
  static Future<List<Map<String, dynamic>>> transactions({String filter = 'all'}) async => _list(await _c.get('/wallet/transactions', query: {'filter': filter}));
  static Future<Map<String, dynamic>> withdrawalFee(String amount) async => _map(await _c.get('/wallet/withdrawal-fee', query: {'amount': amount}));
  static Future<Map<String, dynamic>> withdraw(String amount, {int? bankAccountId}) async =>
      _c.postEnvelope('/wallet/withdraw', {'amount': amount, if (bankAccountId != null) 'bank_account_id': bankAccountId});
  static Future<List<Map<String, dynamic>>> withdrawals() async => _list(await _c.get('/withdrawals'));
  static Future<List<Map<String, dynamic>>> banks() async => _list(await _c.get('/banks'));
  static Future<Map<String, dynamic>> addBankAccount({required String bankName, String? bankCode, required String accountNumber, required String accountName}) async =>
      _c.postEnvelope('/bank-accounts', {'bank_name': bankName, if (bankCode != null) 'bank_code': bankCode, 'account_number': accountNumber, 'account_name': accountName});
  static Future<void> removeBankAccount(int id) => _c.delete('/bank-accounts/$id');

  // ── Notifications ──
  static Future<List<Map<String, dynamic>>> notifications() async => _list(await _c.get('/notifications'));
  static Future<void> markAllRead() => _c.post('/notifications/read');
}
