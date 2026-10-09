import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session.dart';

/// Error thrown for any non-2xx API response, with the server's message.
class ApiException implements Exception {
  final String message;
  final int status;
  final Map<String, dynamic> errors;
  ApiException(this.message, {this.status = 0, this.errors = const {}});
  bool get isUnauthorized => status == 401;
  @override
  String toString() => message;
}

/// Thin JSON client. Every response is {success, message, data}.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Called when the server says the token is no longer valid.
  void Function()? onUnauthorized;

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'DyspatchApp/1.0 (${Platform.operatingSystem})',
        if (Session.instance.token != null) 'Authorization': 'Bearer ${Session.instance.token}',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query?.map((k, v) => MapEntry(k, v?.toString() ?? ''))
      ?..removeWhere((k, v) => v.isEmpty);
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: (q == null || q.isEmpty) ? null : q);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.delete(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  /// Returns the full envelope (data + message), for screens that show the server message.
  Future<Map<String, dynamic>> postEnvelope(String path, [Map<String, dynamic>? body]) async {
    final res = await _raw(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
    return res;
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async => (await _raw(call))['data'];

  Future<Map<String, dynamic>> _raw(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(ApiConfig.timeout);
    } on SocketException {
      throw ApiException('No internet connection. Check your network and try again.');
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } on HandshakeException {
      throw ApiException('Secure connection failed. Please try again.');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${res.statusCode}).', status: res.statusCode);
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) return body;
    final err = ApiException(
      (body['message'] as String?) ?? 'Something went wrong (${res.statusCode}).',
      status: res.statusCode,
      errors: (body['errors'] is Map) ? Map<String, dynamic>.from(body['errors']) : const {},
    );
    if (err.isUnauthorized && Session.instance.isLoggedIn) {
      await Session.instance.clear();
      onUnauthorized?.call();
    }
    throw err;
  }
}
