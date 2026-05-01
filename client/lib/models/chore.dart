/// Mirror of `ChoreDto` on the server.
class Chore {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastCompletedAt;
  final DateTime? scheduledFor;
  final DateTime? archivedAt;
  final List<UserSummary> lastCompletedBy;
  final int? daysSinceCompleted;

  Chore({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastCompletedAt,
    this.scheduledFor,
    this.archivedAt,
    this.lastCompletedBy = const [],
    this.daysSinceCompleted,
  });

  bool get isArchived => archivedAt != null;

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastCompletedAt: json['lastCompletedAt'] != null
            ? DateTime.parse(json['lastCompletedAt'] as String)
            : null,
        scheduledFor: json['scheduledFor'] != null
            ? DateTime.parse(json['scheduledFor'] as String)
            : null,
        archivedAt: json['archivedAt'] != null
            ? DateTime.parse(json['archivedAt'] as String)
            : null,
        lastCompletedBy: (json['lastCompletedBy'] as List<dynamic>? ?? const [])
            .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
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
