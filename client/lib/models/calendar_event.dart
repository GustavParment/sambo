// Mirrors `CalendarEventDto` on the server. `startsAt`/`endsAt` come back as
// UTC ISO strings — we always convert to local time before rendering.

class CalendarEvent {
  final String id;
  final String title;
  final String? description;

  /// Server time (UTC). Use `.toLocal()` when displaying.
  final DateTime startsAt;
  final DateTime endsAt;

  final bool allDay;
  final String color; // "#RRGGBB"
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.color,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        allDay: json['allDay'] as bool,
        color: json['color'] as String,
        createdByUserId: json['createdByUserId'] as String,
        createdByName: json['createdByName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Curated palette presented in the colour picker. Hex literals are the
/// authoritative source — DB stores them verbatim.
class CalendarColors {
  CalendarColors._();

  static const List<String> palette = [
    '#E5747B', // tomato
    '#D2691E', // orange (brand primary)
    '#E8B447', // gold (brand secondary)
    '#5BAB7A', // green (success)
    '#4FB3A9', // teal
    '#6B8FB5', // muted blue (brand tertiary)
    '#9C77C5', // lavender
    '#B7C0CE', // slate
  ];

  static const String defaultColor = '#D2691E';
}
