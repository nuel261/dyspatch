import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the rider's API token and profile.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  static const _kToken = 'dsr_token';
  static const _kRider = 'dsr_rider';
  static const _kOnboarded = 'dsr_onboarded';

  String? token;
  Map<String, dynamic>? rider;
  bool onboarded = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  String get firstName {
    final n = (rider?['first_name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? 'there' : n;
  }

  String get fullName => ((rider?['name'] as String?) ?? '').trim();
  String get kycStatus => (rider?['kyc_status'] as String?) ?? 'none';
  String get status => (rider?['status'] as String?) ?? 'pending';

  /// Verified and active: allowed to go online.
  bool get canWork => kycStatus == 'verified' && status == 'active';

  /// Name and vehicle filled in.
  bool get profileComplete =>
      ((rider?['first_name'] as String?) ?? '').trim().isNotEmpty &&
      ((rider?['vehicle_type'] as String?) ?? '').isNotEmpty;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    onboarded = p.getBool(_kOnboarded) ?? false;
    final r = p.getString(_kRider);
    if (r != null) {
      try {
        rider = jsonDecode(r) as Map<String, dynamic>;
      } catch (_) {}
    }
  }

  Future<void> save(String newToken, Map<String, dynamic> newRider) async {
    token = newToken;
    rider = newRider;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, newToken);
    await p.setString(_kRider, jsonEncode(newRider));
    notifyListeners();
  }

  Future<void> updateRider(Map<String, dynamic> newRider) async {
    rider = {...?rider, ...newRider};
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRider, jsonEncode(rider));
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, true);
  }

  Future<void> clear() async {
    token = null;
    rider = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kRider);
    notifyListeners();
  }
}
