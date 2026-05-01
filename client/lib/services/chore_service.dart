import 'package:sambo/models/chore.dart';
import 'package:sambo/services/api_client.dart';

class ChoreService {
  ChoreService._();
  static final ChoreService instance = ChoreService._();

  /// [archived] = true returns soft-archived chores (newest first); false (default)
  /// returns active.
  Future<List<Chore>> list({bool archived = false}) async {
    final path = archived ? '/api/chores?archived=true' : '/api/chores';
    final res = await ApiClient.instance.getJsonList(path);
    return res.map((e) => Chore.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [lastCompletedAt] optional past baseline ("we already did it on date X").
  /// [scheduledFor]    optional future deadline ("supposed to be done by Y").
  Future<Chore> create(
    String name, {
    DateTime? lastCompletedAt,
    DateTime? scheduledFor,
  }) async {
    final body = <String, Object?>{'name': name};
    if (lastCompletedAt != null) {
      body['lastCompletedAt'] = lastCompletedAt.toUtc().toIso8601String();
    }
    if (scheduledFor != null) {
      body['scheduledFor'] = scheduledFor.toUtc().toIso8601String();
    }
    final json = await ApiClient.instance.postJson('/api/chores', body: body);
    return Chore.fromJson(json);
  }

  Future<Chore> complete(String id, {List<String>? participantIds}) async {
    final body = <String, Object?>{};
    if (participantIds != null) body['userIds'] = participantIds;
    final json = await ApiClient.instance
        .postJson('/api/chores/$id/complete', body: body);
    return Chore.fromJson(json);
  }

  Future<Chore> archive(String id) async {
    final json = await ApiClient.instance.postJson('/api/chores/$id/archive');
    return Chore.fromJson(json);
  }

  Future<Chore> unarchive(String id) async {
    final json = await ApiClient.instance.postJson('/api/chores/$id/unarchive');
    return Chore.fromJson(json);
  }

  Future<void> delete(String id) async {
    await ApiClient.instance.deleteJson('/api/chores/$id');
  }
}
