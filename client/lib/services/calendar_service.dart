import 'package:sambo/core/cache.dart';
import 'package:sambo/models/calendar_event.dart';
import 'package:sambo/services/api_client.dart';
import 'package:sambo/services/auth_service.dart';

/// All endpoints under `/api/calendar`. Tenant scope is taken from the JWT
/// principal server-side, never sent in the URL.
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  String _windowKey(DateTime from, DateTime to) {
    String d(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    return 'calendar:${d(from)}_${d(to)}';
  }

  List<CalendarEvent>? cachedListInWindow({
    required DateTime from,
    required DateTime to,
  }) {
    final hh = AuthService.instance.user.value?.householdId;
    if (hh == null) return null;
    final raw = Cache.read<List<dynamic>>(
      Cache.householdKey(hh, _windowKey(from, to)),
      (j) => j as List<dynamic>,
    );
    if (raw == null) return null;
    return raw
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Half-open window: events overlapping `[from, to)`.
  Future<List<CalendarEvent>> listInWindow({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();
    final res = await ApiClient.instance.getJsonList(
      '/api/calendar?from=$fromIso&to=$toIso',
    );
    final hh = AuthService.instance.user.value?.householdId;
    if (hh != null) {
      await Cache.write(Cache.householdKey(hh, _windowKey(from, to)), res);
    }
    return res
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> create({
    required String title,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool allDay,
    required String color,
  }) async {
    final json = await ApiClient.instance.postJson(
      '/api/calendar',
      body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'allDay': allDay,
        'color': color,
      },
    );
    return CalendarEvent.fromJson(json);
  }

  Future<CalendarEvent> update(
    String id, {
    required String title,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool allDay,
    required String color,
  }) async {
    await ApiClient.instance.putJson(
      '/api/calendar/$id',
      body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'allDay': allDay,
        'color': color,
      },
    );
    // PUT responds with the updated DTO via 200 — but our ApiClient.putJson
    // currently returns void. Refetch is handled by the caller after edit.
    return CalendarEvent(
      id: id,
      title: title,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
      allDay: allDay,
      color: color,
      createdByUserId: '',
      createdByName: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> delete(String id) async {
    await ApiClient.instance.deleteJson('/api/calendar/$id');
  }
}
