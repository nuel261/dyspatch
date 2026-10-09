import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the API token and the signed-in user's profile.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  static const _kToken = 'dsp_token';
  static const _kUser = 'dsp_user';
  static const _kOnboarded = 'dsp_onboarded';

  String? token;
  Map<String, dynamic>? user;
  bool onboarded = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  String get firstName {
    final n = (user?['first_name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? 'there' : n;
  }

  String get fullName => ((user?['name'] as String?) ?? '').trim();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    onboarded = p.getBool(_kOnboarded) ?? false;
    final u = p.getString(_kUser);
    if (u != null) {
      try {
        user = jsonDecode(u) as Map<String, dynamic>;
      } catch (_) {}
    }
  }

  Future<void> save(String newToken, Map<String, dynamic> newUser) async {
    token = newToken;
    user = newUser;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, newToken);
    await p.setString(_kUser, jsonEncode(newUser));
    notifyListeners();
  }

  Future<void> updateUser(Map<String, dynamic> newUser) async {
    user = {...?user, ...newUser};
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, jsonEncode(user));
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, true);
  }

  Future<void> clear() async {
    token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    notifyListeners();
  }
}
