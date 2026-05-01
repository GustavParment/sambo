import 'package:sambo/models/chore.dart';
import 'package:sambo/models/household.dart';
import 'package:sambo/services/api_client.dart';

class HouseholdService {
  HouseholdService._();
  static final HouseholdService instance = HouseholdService._();

  Future<Household> get() async {
    final json = await ApiClient.instance.getJson('/api/household');
    return Household.fromJson(json);
  }

  Future<Household> rename(String name) async {
    await ApiClient.instance.putJson('/api/household', body: {'name': name});
    return get();
  }

  Future<List<UserSummary>> members() async {
    final res = await ApiClient.instance.getJsonList('/api/household/members');
    return res
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
