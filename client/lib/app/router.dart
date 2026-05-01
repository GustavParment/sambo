import 'package:go_router/go_router.dart';
import 'package:sambo/screens/home_shell.dart';
import 'package:sambo/screens/login_screen.dart';
import 'package:sambo/services/auth_service.dart';

/// All routes for the app. Auth state drives whether `/login` or `/` is shown
/// — `redirect` is re-evaluated whenever [AuthService.user] changes.
class SamboRouter {
  SamboRouter._();

  static const String login = '/login';
  static const String home = '/';

  static final GoRouter config = GoRouter(
    initialLocation: home,

    // Re-run [redirect] every time the auth state flips (login / logout).
    refreshListenable: AuthService.instance.user,

    redirect: (context, state) {
      final isAuthed = AuthService.instance.user.value != null;
      final goingToLogin = state.matchedLocation == login;

      if (!isAuthed && !goingToLogin) return login;
      if (isAuthed && goingToLogin) return home;
      return null;
    },

    routes: [
      GoRoute(
        path: login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: home,
        // Safe to `!` because the redirect above ensures we only land here
        // when there *is* an authenticated user.
        builder: (_, _) => HomeShell(user: AuthService.instance.user.value!),
      ),
    ],
  );
}
