import 'package:sambo/models/auth_user.dart';
import 'package:sambo/services/api_client.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  Future<AuthUser> patchAvatarColor(String? hex) async {
    final json = await ApiClient.instance.patchJson(
      '/api/user/me',
      body: {'avatarColor': hex},
    );
    return AuthUser.fromJson(json);
  }
}
