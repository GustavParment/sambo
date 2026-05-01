import 'dart:io';

/// App-wide constants. Real values come from build-time --dart-define flags
/// once we move past local dev — see README for setup.
class AppConfig {
  AppConfig._();

  /// The WEB OAuth client ID from Google Cloud Console. The backend's
  /// `sambo.google.audiences` MUST match this — otherwise the ID token's
  /// `aud` claim won't be accepted.
  ///
  /// Web client IDs are not secret (they're extractable from any built APK/IPA);
  /// security comes from the backend's audience check + the per-platform
  /// SHA-1/bundle-ID binding registered in Google Cloud. Hardcoding the dev
  /// value here means `flutter run` works without `--dart-define`.
  ///
  /// Override per-environment with: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '422660998581-lop49vn54npfri2o5asjcqlt6elt5si0.apps.googleusercontent.com',
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
