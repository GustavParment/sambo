import 'package:sambo/core/cache.dart';
import 'package:sambo/models/leaderboard.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const _ttl = Duration(minutes: 5);

  String? _key(String period) {
    final hh = AuthService.instance.user.value?.householdId;
    return hh == null ? null : Cache.householdKey(hh, 'leaderboard:$period');
  }

  List<LeaderboardEntry>? cached(String period) {
    final key = _key(period);
    if (key == null) return null;
    final raw = Cache.read<List<dynamic>>(
      key,
      (j) => j as List<dynamic>,
      maxAge: _ttl,
    );
    if (raw == null) return null;
    return raw
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaderboardEntry>> fetch(String period) async {
    final res = await ApiClient.instance
        .getJsonList('/api/chores/leaderboard?period=$period');
    final key = _key(period);
    if (key != null) await Cache.write(key, res);
    return res
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
