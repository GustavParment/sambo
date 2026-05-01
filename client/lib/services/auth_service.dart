import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'package:sambo/config.dart';
import 'package:sambo/core/http_exception.dart';
import 'package:sambo/models/auth_user.dart';

/// Owns the auth lifecycle: Google sign-in → backend exchange → JWT storage.
/// The current user is exposed via [user] for the UI to listen to.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'jwt';
  static const _userKey = 'auth_user';

  final _storage = const FlutterSecureStorage();

  /// Notifies listeners whenever the authenticated user changes (login / logout).
  final user = ValueNotifier<AuthUser?>(null);

  String? _token;
  String? get token => _token;

  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );

    // Restore the prior session if there is one — we trust the saved JWT until
    // the backend rejects it; in that case the API layer will trigger signOut.
    final savedToken = await _storage.read(key: _tokenKey);
    final savedUser = await _storage.read(key: _userKey);
    if (savedToken != null && savedUser != null) {
      _token = savedToken;
      user.value = AuthUser.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
    }
  }

  /// Drives the full login flow:
  ///   1. Open Google's account picker.
  ///   2. Take the resulting ID token to our backend `/api/auth/google`.
  ///   3. Persist the server-issued JWT + user record.
  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return an ID token. Did you set serverClientId? '
        'See AppConfig.googleServerClientId.',
      );
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/api/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Backend rejected Google ID token: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['accessToken'] as String;
    final u = AuthUser.fromJson(body['user'] as Map<String, dynamic>);

    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _userKey, value: jsonEncode(u.toJson()));
    user.value = u;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _token = null;
    user.value = null;
  }
}
