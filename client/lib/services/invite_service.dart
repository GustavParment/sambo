import 'package:sambo/models/auth_user.dart';
import 'package:sambo/models/invite.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  /// ADMIN-only — backend rejects with 403 otherwise.
  Future<Invite> generate() async {
    final json = await ApiClient.instance.postJson('/api/invites');
    return Invite.fromJson(json);
  }

  /// Move the current user into the inviter's household. Backend returns a
  /// fresh JWT (the old one carries the wrong householdId/role) — we swap it
  /// in via [AuthService.setSession] so subsequent requests use the new token.
  Future<void> accept(String code) async {
    final json = await ApiClient.instance
        .postJson('/api/invites/accept', body: {'code': code});
    final newToken = json['accessToken'] as String;
    final newUser = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    await AuthService.instance.setSession(newToken, newUser);
  }
}
