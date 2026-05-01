/// The authenticated user as returned by the backend. Mirrors `AuthUserDto`
/// on the server.
///
/// Lives separately from `AuthService` so it can be passed around (screens,
/// API clients, tests) without dragging the singleton service along.
class AuthUser {
  final String id;
  final String householdId;
  final String email;
  final String displayName;
  final String role;

  AuthUser({
    required this.id,
    required this.householdId,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'email': email,
        'displayName': displayName,
        'role': role,
      };
}
