import 'dart:io';

/// App-wide constants. Real values come from build-time --dart-define flags
/// once we move past local dev — see README for setup.
class AppConfig {
  AppConfig._();

  /// The WEB OAuth client ID from Google Cloud Console. The backend's
  /// `sambo.google.audiences` MUST match this — otherwise the ID token's
  /// `aud` claim won't be accepted.
  ///
  /// Override with: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'PASTE_WEB_CLIENT_ID.apps.googleusercontent.com',
  );

  /// Backend base URL. Android emulator can't reach the host's `localhost` —
  /// `10.0.2.2` is the magic alias that maps to it. iOS Simulator and
  /// physical devices on the same Wi-Fi use the actual address.
  ///
  /// Override with: `--dart-define=BACKEND_BASE_URL=https://...`
  static String get backendBaseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }
}
