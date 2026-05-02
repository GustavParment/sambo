import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sambo/services/auth_service.dart';

/// Orchestrates app startup. Anything that must complete before the first
/// frame paints goes here — auth restoration, error reporters, remote config,
/// analytics handles, etc.
///
/// Keep this idempotent: tests and hot-restart may call [run] more than once.
class AppInitService {
  AppInitService._();
  static final AppInitService instance = AppInitService._();

  bool _initialized = false;

  Future<void> run() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Portrait-only — chore + budget + calendar layouts assume a tall canvas.
    // Native side (Info.plist + AndroidManifest) also restricts orientation,
    // so iOS doesn't even draw a landscape splash screen on rotate.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 1. Auth — restores prior session (JWT + AuthUser) from secure storage,
    //    initialises Google Sign-In with our server client id.
    await AuthService.instance.initialize();

    // Future hooks (uncomment as we add them):
    //   FlutterError.onError = …;          // crash reporting
    //   await RemoteConfigService.instance.refresh();
    //   await AnalyticsService.instance.start();

    _initialized = true;
  }
}
