import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sambo/config.dart';
import 'package:sambo/core/http_exception.dart';
import 'package:sambo/services/auth_service.dart';

/// Single entry point for every authenticated HTTP call to the Sambo backend.
///
/// Handles:
/// - Base URL prefix (`AppConfig.backendBaseUrl`).
/// - JSON content type.
/// - `Authorization: Bearer <jwt>` injected from [AuthService].
/// - **Auto sign-out on 401** — if the server says our token is bad,
///   the client clears local session and the router redirects to `/login`.
///
/// Pre-auth calls (e.g. `POST /api/auth/google`) intentionally bypass this
/// client — they're handled by [AuthService] directly.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await _send('GET', path);
    return _decodeObject(res);
  }

  /// Use when the endpoint returns a JSON array, e.g. `[ {...}, {...} ]`.
  Future<List<dynamic>> getJsonList(String path) async {
    final res = await _send('GET', path);
    return _decodeArray(res);
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final res = await _send('POST', path, body: body);
    return _decodeObject(res);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final res = await _send('DELETE', path);
    return res.body.isEmpty ? const {} : _decodeObject(res);
  }

  Future<http.Response> _send(String method, String path, {Object? body}) async {
    final token = AuthService.instance.token;
    if (token == null) {
      throw HttpException('Not signed in', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.backendBaseUrl}$path');
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401) {
      // Backend says our JWT is invalid (expired, revoked, secret rotated).
      // Tear down local session — the router will redirect to /login.
      debugPrint('[ApiClient] 401 on $method $path — signing out');
      await AuthService.instance.signOut();
      throw HttpException('Session expired', statusCode: 401);
    }

    if (res.statusCode >= 400) {
      throw HttpException(res.body, statusCode: res.statusCode);
    }
    return res;
  }

  Map<String, dynamic> _decodeObject(http.Response res) {
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  List<dynamic> _decodeArray(http.Response res) {
    if (res.body.isEmpty) return const [];
    return jsonDecode(res.body) as List<dynamic>;
  }
}
