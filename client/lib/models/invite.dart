/// Mirrors `InviteDto` on the server. Returned when an ADMIN generates a code.
class Invite {
  final String id;
  final String code;
  final DateTime expiresAt;

  Invite({required this.id, required this.code, required this.expiresAt});

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        id: json['id'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
