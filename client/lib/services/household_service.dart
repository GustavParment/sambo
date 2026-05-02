import 'package:sambo/models/auth_user.dart';
import 'package:sambo/models/chore.dart';
import 'package:sambo/models/household.dart';
import 'package:sambo/models/household_membership.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

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

  Future<List<HouseholdMembership>> memberships() async {
    final res =
        await ApiClient.instance.getJsonList('/api/household/memberships');
    return res
        .map((e) => HouseholdMembership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Switch the active household. Backend mints a fresh JWT; we swap it in so
  /// every subsequent request scopes to the new tenant.
  Future<void> switchActive(String householdId) async {
    final json = await ApiClient.instance
        .postJson('/api/household/switch', body: {'householdId': householdId});
    await _applySession(json);
  }

  /// Leave a household. If it was the active one and the user has another
  /// household, the response carries a fresh JWT for the fallback. If they
  /// just left their last household, the server returns no token — we sign
  /// out so the user lands back on the login screen.
  Future<void> leave(String householdId) async {
    final json = await ApiClient.instance
        .postJson('/api/household/leave', body: {'householdId': householdId});
    final token = json['accessToken'] as String?;
    if (token == null) {
      await AuthService.instance.signOut();
      return;
    }
    await _applySession(json);
  }

  /// Create a new household with the caller as ADMIN, automatically becoming
  /// the new active household.
  Future<void> create(String name) async {
    final json =
        await ApiClient.instance.postJson('/api/household', body: {'name': name});
    await _applySession(json);
  }

  Future<void> _applySession(Map<String, dynamic> json) async {
    final token = json['accessToken'] as String;
    final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    await AuthService.instance.setSession(token, user);
  }
}
