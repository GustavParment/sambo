/// Mirror of `ChoreDto` on the server.
///
/// `daysSinceCompleted` is computed by the backend so the client can render
/// "X dagar sedan" without doing date math itself.
class Chore {
  final String id;
  final String name;
  final DateTime? lastCompletedAt;
  final UserSummary? lastCompletedBy;
  final int? daysSinceCompleted;

  Chore({
    required this.id,
    required this.name,
    this.lastCompletedAt,
    this.lastCompletedBy,
    this.daysSinceCompleted,
  });

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        name: json['name'] as String,
        lastCompletedAt: json['lastCompletedAt'] != null
            ? DateTime.parse(json['lastCompletedAt'] as String)
            : null,
        lastCompletedBy: json['lastCompletedBy'] != null
            ? UserSummary.fromJson(
                json['lastCompletedBy'] as Map<String, dynamic>)
            : null,
        daysSinceCompleted: (json['daysSinceCompleted'] as num?)?.toInt(),
      );
}

class UserSummary {
  final String id;
  final String displayName;

  UserSummary({required this.id, required this.displayName});

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
      );
}
