import 'package:sambo/models/budget.dart';

/// Mirror of `OverviewDto` on the server. The dashboard payload — chore
/// activity for the household + the existing budget monthly overview — in
/// a single object so the screen can render off one fetch.
class Overview {
  /// "yyyy-MM"
  final String yearMonth;
  final ChoreSummary chores;
  final MonthlyOverview budget;

  Overview({
    required this.yearMonth,
    required this.chores,
    required this.budget,
  });

  factory Overview.fromJson(Map<String, dynamic> json) => Overview(
        yearMonth: json['yearMonth'] as String,
        chores: ChoreSummary.fromJson(json['chores'] as Map<String, dynamic>),
        budget: MonthlyOverview.fromJson(json['budget'] as Map<String, dynamic>),
      );
}

class ChoreSummary {
  final int totalCompletions;
  final int distinctChoresDone;

  /// Unordered list of users who completed at least one chore in the window.
  /// Server deliberately omits per-user counts — render this as a neutral
  /// flat list, not a leaderboard.
  final List<ChoreParticipant> participants;

  ChoreSummary({
    required this.totalCompletions,
    required this.distinctChoresDone,
    required this.participants,
  });

  factory ChoreSummary.fromJson(Map<String, dynamic> json) => ChoreSummary(
        totalCompletions: (json['totalCompletions'] as num).toInt(),
        distinctChoresDone: (json['distinctChoresDone'] as num).toInt(),
        participants: (json['participants'] as List<dynamic>? ?? const [])
            .map((e) =>
                ChoreParticipant.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChoreParticipant {
  final String userId;
  final String displayName;

  ChoreParticipant({required this.userId, required this.displayName});

  factory ChoreParticipant.fromJson(Map<String, dynamic> json) =>
      ChoreParticipant(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
      );
}
