import 'package:sambo/models/chore.dart';
import 'package:sambo/services/api_client.dart';

/// Wraps `/api/chores`. All calls go through [ApiClient] which means JWT
/// header injection and 401 → auto-signOut are handled centrally.
class ChoreService {
  ChoreService._();
  static final ChoreService instance = ChoreService._();

  Future<List<Chore>> list() async {
    final res = await ApiClient.instance.getJsonList('/api/chores');
    return res.map((e) => Chore.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Chore> create(String name) async {
    final json = await ApiClient.instance
        .postJson('/api/chores', body: {'name': name});
    return Chore.fromJson(json);
  }

  Future<Chore> complete(String id) async {
    final json = await ApiClient.instance.postJson('/api/chores/$id/complete');
    return Chore.fromJson(json);
  }

  Future<void> delete(String id) async {
    await ApiClient.instance.deleteJson('/api/chores/$id');
  }
}
