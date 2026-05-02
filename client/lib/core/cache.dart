import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny TTL-aware JSON cache backed by [SharedPreferences].
///
/// Use this for "show last fetched data instantly while a fresh request
/// runs in the background" — the classic stale-while-revalidate pattern.
/// Not meant for large blobs (everything goes through `getString`); for
/// MVP-sized JSON (a household's chores / month's budget / 6-week calendar
/// window) this is plenty fast.
///
/// Storage layout:
/// ```
///   cache:<key> = {"ts": "<ISO 8601>", "data": <json>}
/// ```
/// The `cache:` prefix is for housekeeping — [clearAll] only removes our
/// keys so the rest of [SharedPreferences] (settings, etc) stays put.
///
/// Cache keys SHOULD be namespaced by household / user so a switch doesn't
/// surface another tenant's data. See [householdKey] / [userKey].
class Cache {
  Cache._();

  static const _prefix = 'cache:';
  static SharedPreferences? _prefs;

  /// Must be awaited from app init before any read/write.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Builds a key in the form `hh:<householdId>:<suffix>`. Use this for
  /// per-household-scoped data (chores, budget, calendar, …).
  static String householdKey(String householdId, String suffix) =>
      'hh:$householdId:$suffix';

  /// Builds a key in the form `user:<userId>:<suffix>`. Use this for
  /// per-user-scoped data (memberships).
  static String userKey(String userId, String suffix) =>
      'user:$userId:$suffix';

  /// Read cached entry. Returns `null` if missing, malformed, or older than
  /// [maxAge]. Pass `maxAge: null` to ignore age (return whatever's stored).
  static T? read<T>(
    String key,
    T Function(Object json) decoder, {
    Duration? maxAge,
  }) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      if (maxAge != null) {
        final ts = DateTime.parse(entry['ts'] as String);
        if (DateTime.now().difference(ts) > maxAge) return null;
      }
      return decoder(entry['data'] as Object);
    } catch (_) {
      // Stored entry is malformed — wipe it so we don't keep failing.
      prefs.remove('$_prefix$key');
      return null;
    }
  }

  /// Persist [data] under [key] with the current timestamp.
  static Future<void> write(String key, Object data) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final entry = jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'data': data,
    });
    await prefs.setString('$_prefix$key', entry);
  }

  /// Drop a single cached entry.
  static Future<void> remove(String key) async {
    await _prefs?.remove('$_prefix$key');
  }

  /// Drop every entry whose key (without the `cache:` prefix) matches
  /// [predicate]. Useful for "clear this household's data" on leave.
  static Future<void> clearWhere(bool Function(String key) predicate) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final toRemove = prefs
        .getKeys()
        .where((k) =>
            k.startsWith(_prefix) && predicate(k.substring(_prefix.length)))
        .toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }

  /// Drop every cache entry. Called on sign-out.
  static Future<void> clearAll() async {
    await clearWhere((_) => true);
  }
}
