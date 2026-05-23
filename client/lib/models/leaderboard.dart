class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarColor;
  final int count;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarColor,
    required this.count,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarColor: json['avatarColor'] as String?,
        count: (json['count'] as num).toInt(),
      );
}
