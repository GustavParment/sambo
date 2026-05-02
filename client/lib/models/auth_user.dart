/// The authenticated user as returned by the backend. Mirrors `AuthUserDto`
/// on the server.
///
/// [householdId] and [role] follow the user's *active* household and become
/// null when the user has left every household — UI is expected to redirect
/// to a "create or join" empty state in that case.
class AuthUser {
  final String id;
  final String? householdId;
  final String email;
  final String displayName;
  final String? role;

  AuthUser({
    required this.id,
    required this.householdId,
    required this.email,
    required this.displayName,
    required this.role,
  });

  /// True when the user has an active household — most screens require this.
  bool get hasActiveHousehold => householdId != null;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        householdId: json['householdId'] as String?,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'email': email,
        'displayName': displayName,
        'role': role,
      };
}
