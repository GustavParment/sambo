import 'package:sambo/core/cache.dart';
import 'package:sambo/models/overview.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

class OverviewService {
  OverviewService._();
  static final OverviewService instance = OverviewService._();

  String? _key(String yearMonth) {
    final hh = AuthService.instance.user.value?.householdId;
    if (hh == null) return null;
    return Cache.householdKey(hh, 'overview:$yearMonth');
  }

  Overview? cachedOverview(String yearMonth) {
    final key = _key(yearMonth);
    if (key == null) return null;
    final raw = Cache.read<Map<String, dynamic>>(
      key,
      (j) => j as Map<String, dynamic>,
    );
    if (raw == null) return null;
    return Overview.fromJson(raw);
  }

  Future<Overview> getOverview(String yearMonth) async {
    final json = await ApiClient.instance.getJson('/api/overview/$yearMonth');
    final key = _key(yearMonth);
    if (key != null) await Cache.write(key, json);
    return Overview.fromJson(json);
  }
}
