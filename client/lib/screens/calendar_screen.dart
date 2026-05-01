import 'package:flutter/material.dart';
import 'package:sambo/models/calendar_event.dart';
import 'package:sambo/services/calendar_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

/// Shared household calendar — month grid à la Google Calendar mobile.
/// Tap a day → bottom sheet of that day's events. FAB to create.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _monthStart; // local midnight of day 1 of the visible month
  late Future<List<CalendarEvent>> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    _future = _fetch();
  }

  /// Loads enough events to cover the 6-week visible grid (which spills past
  /// the month edges), so events on those overflow days still render.
  Future<List<CalendarEvent>> _fetch() {
    final gridStart = _gridStart(_monthStart);
    final gridEnd = gridStart.add(const Duration(days: 42));
    return CalendarService.instance.listInWindow(from: gridStart, to: gridEnd);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    await _future;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month + delta, 1);
      _future = _fetch();
    });
  }

  Future<void> _showDaySheet(DateTime day, List<CalendarEvent> dayEvents) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DaySheet(
        day: day,
        events: dayEvents,
        onAdd: () {
          Navigator.pop(context);
          _showEventSheet(initialDate: day);
        },
        onTapEvent: (e) {
          Navigator.pop(context);
          _showEventSheet(existing: e);
        },
        onDelete: (e) async {
          Navigator.pop(context);
          await _confirmDelete(e);
        },
      ),
    );
  }

  Future<void> _showEventSheet({
    DateTime? initialDate,
    CalendarEvent? existing,
  }) async {
    final result = await showModalBottomSheet<_EventSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventSheet(
        existing: existing,
        initialDate: initialDate ?? _monthStart,
      ),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await CalendarService.instance.create(
          title: result.title,
          description: result.description,
          startsAt: result.startsAt,
          endsAt: result.endsAt,
          allDay: result.allDay,
          color: result.color,
        );
      } else {
        await CalendarService.instance.update(
          existing.id,
          title: result.title,
          description: result.description,
          startsAt: result.startsAt,
          endsAt: result.endsAt,
          allDay: result.allDay,
          color: result.color,
        );
      }
      await _refresh();
    } catch (e) {
      _toast('Kunde inte spara: $e');
    }
  }

  Future<void> _confirmDelete(CalendarEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort event?'),
        content: Text('"${e.title}" tas bort permanent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ta bort')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await CalendarService.instance.delete(e.id);
        await _refresh();
      } catch (err) {
        _toast('Kunde inte ta bort: $err');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _MonthSwitcher(
            monthStart: _monthStart,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-fab',
        onPressed: () => _showEventSheet(initialDate: DateTime.now()),
        icon: const Icon(Icons.add),
        label: const Text('Nytt event'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CalendarEvent>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(error: snap.error!);
            }
            final events = snap.data ?? const <CalendarEvent>[];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const _WeekdayHeader(),
                _MonthGrid(
                  monthStart: _monthStart,
                  events: events,
                  onDayTap: _showDaySheet,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Date helpers — single place for "where does the visible 6-week grid start"
// ============================================================================

/// Monday on or before the 1st of the month. Dart's `weekday` is 1=Mon..7=Sun.
DateTime _gridStart(DateTime monthStart) {
  final daysBack = monthStart.weekday - 1;
  return monthStart.subtract(Duration(days: daysBack));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Local midnight of the same day.
DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

const _swedishMonths = [
  'Januari', 'Februari', 'Mars', 'April', 'Maj', 'Juni',
  'Juli', 'Augusti', 'September', 'Oktober', 'November', 'December',
];

// ============================================================================
// Top bar — month switcher
// ============================================================================

class _MonthSwitcher extends StatelessWidget {
  final DateTime monthStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSwitcher({
    required this.monthStart,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${_swedishMonths[monthStart.month - 1]} ${monthStart.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Föregående månad',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Nästa månad',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Weekday header (Mån Tis Ons …)
// ============================================================================

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['Mån', 'Tis', 'Ons', 'Tor', 'Fre', 'Lör', 'Sön'];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(
                  l,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: SamboAppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Month grid — 6 rows × 7 cols
// ============================================================================

class _MonthGrid extends StatelessWidget {
  final DateTime monthStart;
  final List<CalendarEvent> events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;

  const _MonthGrid({
    required this.monthStart,
    required this.events,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = _gridStart(monthStart);
    final today = _stripTime(DateTime.now());

    // Bucket events by their *local* start day. Multi-day events render only
    // on their first day for now — good enough for MVP.
    final Map<DateTime, List<CalendarEvent>> byDay = {};
    for (final e in events) {
      final localDay = _stripTime(e.startsAt.toLocal());
      byDay.putIfAbsent(localDay, () => []).add(e);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          for (int row = 0; row < 6; row++)
            Row(
              children: [
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: _buildCell(
                      start.add(Duration(days: row * 7 + col)),
                      monthStart,
                      today,
                      byDay,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    DateTime day,
    DateTime monthStart,
    DateTime today,
    Map<DateTime, List<CalendarEvent>> byDay,
  ) {
    final isCurrentMonth = day.month == monthStart.month;
    final isToday = _sameDay(day, today);
    final dayEvents = byDay[_stripTime(day)] ?? const <CalendarEvent>[];

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: SamboAppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onDayTap(day, dayEvents),
          child: SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: isToday
                          ? const BoxDecoration(
                              color: SamboAppColors.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? SamboAppColors.onPrimary
                              : (isCurrentMonth
                                  ? SamboAppColors.onSurface
                                  : SamboAppColors.onSurfaceVariant
                                      .withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(child: _eventChips(dayEvents)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventChips(List<CalendarEvent> dayEvents) {
    if (dayEvents.isEmpty) return const SizedBox.shrink();

    // Show up to 2 colour-coded chips, plus "+N" if there are more.
    final visible = dayEvents.take(2).toList();
    final extra = dayEvents.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in visible) ...[
          _EventChip(event: e),
          const SizedBox(height: 2),
        ],
        if (extra > 0)
          Text(
            '+$extra',
            style: const TextStyle(
              fontSize: 10,
              color: SamboAppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _EventChip extends StatelessWidget {
  final CalendarEvent event;
  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(event.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final stripped = hex.startsWith('#') ? hex.substring(1) : hex;
  return Color(int.parse('FF$stripped', radix: 16));
}

// ============================================================================
// Day sheet — list of one day's events + "add to this day"
// ============================================================================

class _DaySheet extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final VoidCallback onAdd;
  final void Function(CalendarEvent) onTapEvent;
  final void Function(CalendarEvent) onDelete;

  const _DaySheet({
    required this.day,
    required this.events,
    required this.onAdd,
    required this.onTapEvent,
    required this.onDelete,
  });

  String _dayLabel() {
    const weekdays = ['Mån', 'Tis', 'Ons', 'Tor', 'Fre', 'Lör', 'Sön'];
    final wd = weekdays[day.weekday - 1];
    return '$wd ${day.day} ${_swedishMonths[day.month - 1].toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: SamboAppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            _dayLabel(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Inga events den här dagen.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DayEventTile(
                  event: e,
                  onTap: () => onTapEvent(e),
                  onDelete: () => onDelete(e),
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Lägg till event'),
          ),
        ],
      ),
    );
  }
}

class _DayEventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _DayEventTile({
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  String _timeLabel() {
    if (event.allDay) return 'Hela dagen';
    final s = event.startsAt.toLocal();
    final e = event.endsAt.toLocal();
    return '${_hhmm(s)}–${_hhmm(e)}';
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(event.color);
    return Material(
      color: SamboAppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onDelete,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_timeLabel()} · ${event.createdByName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: SamboAppColors.onSurfaceVariant,
                              ),
                            ),
                            if (event.description != null &&
                                event.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                event.description!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ta bort',
                        icon: const Icon(Icons.close, size: 18),
                        color: SamboAppColors.onSurfaceVariant,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Add / edit event sheet
// ============================================================================

class _EventSheetResult {
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String color;
  _EventSheetResult({
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.color,
  });
}

class _EventSheet extends StatefulWidget {
  final CalendarEvent? existing;
  final DateTime initialDate;
  const _EventSheet({this.existing, required this.initialDate});

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _allDay;
  late String _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _allDay = e?.allDay ?? false;
    _color = e?.color ?? CalendarColors.defaultColor;

    if (e != null) {
      _startsAt = e.startsAt.toLocal();
      _endsAt = e.endsAt.toLocal();
    } else {
      // Default to 09:00–10:00 on the chosen day.
      final base = DateTime(widget.initialDate.year,
          widget.initialDate.month, widget.initialDate.day, 9, 0);
      _startsAt = base;
      _endsAt = base.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startsAt, allDay: _allDay);
    if (picked == null) return;
    setState(() {
      _startsAt = picked;
      // Keep ends_at after starts_at; bump by an hour if it slipped.
      if (_endsAt.isBefore(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endsAt, allDay: _allDay);
    if (picked == null) return;
    if (!mounted) return;
    if (picked.isBefore(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slut måste vara efter start')),
      );
      return;
    }
    setState(() => _endsAt = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime initial, {required bool allDay}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null) return null;
    if (allDay) {
      return DateTime(date.year, date.month, date.day);
    }
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _toggleAllDay(bool v) {
    setState(() {
      _allDay = v;
      if (v) {
        _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day);
        _endsAt = DateTime(_endsAt.year, _endsAt.month, _endsAt.day, 23, 59);
      }
    });
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _EventSheetResult(
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startsAt: _startsAt,
        endsAt: _endsAt,
        allDay: _allDay,
        color: _color,
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final date = '${d.day}/${d.month} ${d.year}';
    if (_allDay) return date;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: SamboAppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(isEdit ? 'Redigera event' : 'Nytt event',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              autofocus: !isEdit,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'Middag, läkarbesök …',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _allDay,
              onChanged: _toggleAllDay,
              title: const Text('Hela dagen'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: SamboAppColors.primary,
            ),
            _DateTimeRow(
              label: 'Start',
              value: _formatDateTime(_startsAt),
              onTap: _pickStart,
            ),
            const SizedBox(height: 8),
            _DateTimeRow(
              label: 'Slut',
              value: _formatDateTime(_endsAt),
              onTap: _pickEnd,
            ),
            const SizedBox(height: 16),
            Text('Färg',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final hex in CalendarColors.palette)
                  _ColorDot(
                    hex: hex,
                    selected: _color.toUpperCase() == hex.toUpperCase(),
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beskrivning (valfritt)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(isEdit ? 'Spara' : 'Skapa event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: SamboAppColors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.event_outlined,
                  color: SamboAppColors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SamboAppColors.onSurfaceVariant,
                        )),
                    Text(value, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? SamboAppColors.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

// ============================================================================
// Error state
// ============================================================================

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
      children: [
        const Icon(Icons.error_outline,
            size: 64, color: SamboAppColors.error),
        const SizedBox(height: 16),
        Text(
          'Något gick fel',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
