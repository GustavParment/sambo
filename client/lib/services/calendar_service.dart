import 'package:sambo/models/calendar_event.dart';
import 'package:sambo/services/api_client.dart';

/// All endpoints under `/api/calendar`. Tenant scope is taken from the JWT
/// principal server-side, never sent in the URL.
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

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
