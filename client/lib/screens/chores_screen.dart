import 'package:flutter/material.dart';
import 'package:sambo/models/chore.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/chore_service.dart';
import 'package:sambo/services/household_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  bool _showingArchived = false;
  List<Chore>? _chores;
  Object? _error;

  /// The household we last fetched against — used to detect a switch and
  /// trigger a re-fetch from the cache for the new tenant.
  String? _lastHouseholdId;

  /// Loaded lazily on first completion-sheet open. Cached so the picker
  /// doesn't refetch members on every chore tap.
  List<UserSummary>? _members;

  @override
  void initState() {
    super.initState();
    _lastHouseholdId = AuthService.instance.user.value?.householdId;
    AuthService.instance.user.addListener(_onUserChanged);
    _chores = ChoreService.instance.cachedList(archived: _showingArchived);
    _refreshInBackground();
  }

  @override
  void dispose() {
    AuthService.instance.user.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (!mounted) return;
    final newHh = AuthService.instance.user.value?.householdId;
    if (newHh == _lastHouseholdId) return;
    _lastHouseholdId = newHh;
    _members = null; // member roster is per-household
    setState(() {
      _chores = ChoreService.instance.cachedList(archived: _showingArchived);
      _error = null;
    });
    _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    try {
      final list =
          await ChoreService.instance.list(archived: _showingArchived);
      if (!mounted) return;
      setState(() {
        _chores = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep showing whatever cache we already have; only surface the error
      // if there's nothing to render.
      if (_chores == null) setState(() => _error = e);
    }
  }

  Future<void> _refresh() => _refreshInBackground();

  void _toggleArchivedView() {
    setState(() {
      _showingArchived = !_showingArchived;
      _chores = ChoreService.instance.cachedList(archived: _showingArchived);
      _error = null;
    });
    _refreshInBackground();
  }

  Future<List<UserSummary>> _loadMembers() async {
    return _members ??= await HouseholdService.instance.members();
  }

  Future<void> _promptComplete(Chore c) async {
    final members = await _loadMembers();
    if (!mounted) return;
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CompleteChoreSheet(chore: c, members: members),
    );
    if (selected == null || selected.isEmpty) return;
    try {
      await ChoreService.instance.complete(c.id, participantIds: selected);
      // Auto-arkivera direkt efter completion — ett klick "klar" räcker.
      // Sysslan försvinner ur aktiva listan tills den återställs (då kan man
      // sätta nytt schemalagt datum).
      await ChoreService.instance.archive(c.id);
      await _refresh();
    } catch (e) {
      _toast('Kunde inte markera som klar: $e');
    }
  }

  Future<void> _archive(Chore c) async {
    try {
      await ChoreService.instance.archive(c.id);
      await _refresh();
      _toast('${c.name} arkiverad');
    } catch (e) {
      _toast('Kunde inte arkivera: $e');
    }
  }

  Future<void> _unarchive(Chore c) async {
    try {
      await ChoreService.instance.unarchive(c.id);
      await _refresh();
      _toast('${c.name} återställd');
    } catch (e) {
      _toast('Kunde inte återställa: $e');
    }
  }

  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<_AddChoreResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddChoreSheet(),
    );
    if (result == null) return;
    try {
      await ChoreService.instance.create(
        result.name,
        lastCompletedAt: result.lastCompletedAt,
        scheduledFor: result.scheduledFor,
      );
      await _refresh();
    } catch (e) {
      _toast('Kunde inte skapa: $e');
    }
  }

  Future<void> _confirmDelete(Chore c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort permanent?'),
        content: Text(
          '"${c.name}" och hela dess historik tas bort permanent. '
          'Använd Arkivera om du vill behålla historiken.',
        ),
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
        await ChoreService.instance.delete(c.id);
        await _refresh();
      } catch (e) {
        _toast('Kunde inte ta bort: $e');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.instance.user.value?.role == 'ADMIN';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sysslor'),
      ),
      floatingActionButton: _showingArchived
          ? null
          : FloatingActionButton.extended(
              heroTag: 'chores-fab',
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Ny'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Aktiva'),
                    icon: Icon(Icons.list),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Arkiverade'),
                    icon: Icon(Icons.archive_outlined),
                  ),
                ],
                selected: {_showingArchived},
                onSelectionChanged: (s) {
                  if (s.first == _showingArchived) return;
                  _toggleArchivedView();
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: Builder(
                builder: (context) {
                  // First-load with no cache: spinner. Otherwise cache renders
                  // instantly and the network fetch updates in place.
                  if (_chores == null && _error == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_chores == null && _error != null) {
                    return _ErrorState(error: _error!);
                  }
                  final chores = _chores ?? const <Chore>[];
                  if (chores.isEmpty) {
                    return _EmptyState(
                      archived: _showingArchived,
                      canAdd: isAdmin,
                      onAdd: _showAddSheet,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: chores.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChoreCard(
                        chores[i],
                        archivedView: _showingArchived,
                        canDelete: isAdmin,
                        onComplete: _promptComplete,
                        onArchive: _archive,
                        onUnarchive: _unarchive,
                        onDelete: _confirmDelete,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Chore card
// ============================================================================

class _ChoreCard extends StatelessWidget {
  final Chore chore;
  final bool archivedView;
  final bool canDelete;
  final Future<void> Function(Chore) onComplete;
  final Future<void> Function(Chore) onArchive;
  final Future<void> Function(Chore) onUnarchive;
  final Future<void> Function(Chore) onDelete;

  const _ChoreCard(
    this.chore, {
    required this.archivedView,
    required this.canDelete,
    required this.onComplete,
    required this.onArchive,
    required this.onUnarchive,
    required this.onDelete,
  });

  ({Color stripe, Color pillBg, Color pillFg, String pillText}) _stale() {
    if (archivedView) {
      return (
        stripe: SamboAppColors.outline,
        pillBg: SamboAppColors.surfaceContainerHighest,
        pillFg: SamboAppColors.onSurfaceVariant,
        pillText: 'Arkiverad'
      );
    }
    // Aktiva sysslor: schemalagt datum är primär signal — sysslor som blivit
    // klara arkiveras automatiskt, så det som ligger kvar i listan är
    // antingen schemalagt eller helt nytt.
    if (chore.scheduledFor != null) {
      return _scheduledStyling(chore.scheduledFor!);
    }
    final days = chore.daysSinceCompleted;
    if (days == null) {
      // Auto-archive on completion means anything in the active list with no
      // scheduledFor and no completion history is just "freshly created" —
      // 'Aldrig' was technically correct but read confusingly.
      return (
        stripe: SamboAppColors.tertiary,
        pillBg: SamboAppColors.tertiary.withValues(alpha: 0.18),
        pillFg: SamboAppColors.tertiary,
        pillText: 'Ny'
      );
    }
    final text = switch (days) { 0 => 'Idag', 1 => 'Igår', _ => '$days d' };
    if (days <= 2) {
      return (
        stripe: SamboAppColors.success,
        pillBg: SamboAppColors.success.withValues(alpha: 0.15),
        pillFg: SamboAppColors.success,
        pillText: text
      );
    }
    if (days <= 7) {
      return (
        stripe: SamboAppColors.secondary,
        pillBg: SamboAppColors.secondary.withValues(alpha: 0.15),
        pillFg: SamboAppColors.secondary,
        pillText: text
      );
    }
    return (
      stripe: SamboAppColors.error,
      pillBg: SamboAppColors.error.withValues(alpha: 0.15),
      pillFg: SamboAppColors.error,
      pillText: text
    );
  }

  /// Pill styling for a chore that has a {@code scheduledFor} date.
  /// Försenad → röd, idag → primary (orange), inom en vecka → guldigt,
  /// längre fram → grönt.
  ({Color stripe, Color pillBg, Color pillFg, String pillText})
      _scheduledStyling(DateTime d) {
    // Server lagrar scheduled_for som UTC Instant. Konvertera till lokal tid
    // INNAN vi strippar till bara datum, annars hamnar svenska kvällsval på
    // föregående UTC-dag och färglogiken blir fel.
    final local = d.toLocal();
    final today = DateTime.now();
    final daysAhead = DateTime(local.year, local.month, local.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    final String text = switch (daysAhead) {
      0 => 'Idag',
      1 => 'Imorgon',
      -1 => 'Igår',
      _ => _shortDate(local),
    };

    final Color color;
    if (daysAhead < 0) {
      color = SamboAppColors.error;
    } else if (daysAhead == 0) {
      color = SamboAppColors.primary;
    } else if (daysAhead <= 7) {
      color = SamboAppColors.secondary;
    } else {
      color = SamboAppColors.success;
    }

    return (
      stripe: color,
      pillBg: color.withValues(alpha: 0.15),
      pillFg: color,
      pillText: text,
    );
  }

  static String _shortDate(DateTime d) {
    const names = [
      'jan', 'feb', 'mar', 'apr', 'maj', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    final today = DateTime.now();
    final base = '${d.day} ${names[d.month - 1]}';
    return d.year == today.year ? base : '$base ${d.year}';
  }

  String? _participantsLabel() {
    if (chore.lastCompletedBy.isEmpty) return null;
    if (chore.lastCompletedBy.length == 1) {
      return chore.lastCompletedBy.first.displayName;
    }
    if (chore.lastCompletedBy.length == 2) {
      return '${chore.lastCompletedBy[0].displayName} + ${chore.lastCompletedBy[1].displayName}';
    }
    return '${chore.lastCompletedBy.first.displayName} + ${chore.lastCompletedBy.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _stale();
    final by = _participantsLabel();

    // Subtle wash of the staleness colour over the surface — enough to
    // make the card glance-readable without competing with the stripe.
    final cardBg = Color.alphaBlend(
      s.stripe.withValues(alpha: archivedView ? 0.04 : 0.07),
      SamboAppColors.surface,
    );

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: archivedView ? null : () => onComplete(chore),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: s.stripe,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chore.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: archivedView
                                    ? SamboAppColors.onSurfaceVariant
                                    : null,
                                decoration: archivedView
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _Pill(text: s.pillText, bg: s.pillBg, fg: s.pillFg),
                                if (by != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      by,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: SamboAppColors.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!archivedView)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: SamboAppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            tooltip: 'Markera som klar',
                            icon: const Icon(Icons.check),
                            color: SamboAppColors.primary,
                            onPressed: () => onComplete(chore),
                          ),
                        ),
                      _adminMenu(),
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

  Widget _adminMenu() {
    return PopupMenuButton<_ChoreAction>(
      tooltip: 'Mer',
      icon: Icon(Icons.more_vert, color: SamboAppColors.onSurfaceVariant),
      onSelected: (action) {
        switch (action) {
          case _ChoreAction.archive:
            onArchive(chore);
          case _ChoreAction.unarchive:
            onUnarchive(chore);
          case _ChoreAction.delete:
            onDelete(chore);
        }
      },
      itemBuilder: (_) => [
        if (!archivedView)
          const PopupMenuItem(
            value: _ChoreAction.archive,
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Arkivera'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (archivedView)
          const PopupMenuItem(
            value: _ChoreAction.unarchive,
            child: ListTile(
              leading: Icon(Icons.unarchive_outlined),
              title: Text('Återställ'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: _ChoreAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: SamboAppColors.error),
              title: Text('Ta bort permanent',
                  style: TextStyle(color: SamboAppColors.error)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

enum _ChoreAction { archive, unarchive, delete }

// ============================================================================
// Add chore sheet — name + optional "last completed" baseline date
// ============================================================================

class _AddChoreResult {
  final String name;
  final DateTime? lastCompletedAt;
  final DateTime? scheduledFor;
  _AddChoreResult({
    required this.name,
    this.lastCompletedAt,
    this.scheduledFor,
  });
}

class _AddChoreSheet extends StatefulWidget {
  const _AddChoreSheet();

  @override
  State<_AddChoreSheet> createState() => _AddChoreSheetState();
}

class _AddChoreSheetState extends State<_AddChoreSheet> {
  final _nameController = TextEditingController();
  DateTime? _lastDoneAt;
  DateTime? _scheduledFor;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPast() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDoneAt ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Senast utförd',
    );
    if (picked != null) setState(() => _lastDoneAt = picked);
  }

  Future<void> _pickFuture() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 5),
      helpText: 'Nästa gång',
    );
    if (picked != null) setState(() => _scheduledFor = picked);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _AddChoreResult(
        name: name,
        lastCompletedAt: _lastDoneAt,
        scheduledFor: _scheduledFor,
      ),
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatPast(DateTime d) {
    final today = DateTime.now();
    final daysAgo = DateTime(today.year, today.month, today.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    final text = switch (daysAgo) {
      0 => 'Idag',
      1 => 'Igår',
      _ => '$daysAgo dagar sedan',
    };
    return '$text · ${_isoDate(d)}';
  }

  String _formatFuture(DateTime d) {
    final today = DateTime.now();
    final daysAhead = DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final text = switch (daysAhead) {
      0 => 'Idag',
      1 => 'Imorgon',
      _ => 'Om $daysAhead dagar',
    };
    return '$text · ${_isoDate(d)}';
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
          Text('Ny syssla',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Namn',
              hintText: 'Dammsugning, diska …',
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          _DatePickerRow(
            icon: Icons.history,
            label: 'Senast utförd',
            value: _lastDoneAt == null
                ? 'Valfritt — tryck för att välja'
                : _formatPast(_lastDoneAt!),
            cleared: _lastDoneAt == null,
            onTap: _pickPast,
            onClear: () => setState(() => _lastDoneAt = null),
          ),
          const SizedBox(height: 8),
          _DatePickerRow(
            icon: Icons.event_outlined,
            label: 'Nästa gång',
            value: _scheduledFor == null
                ? 'Valfritt — tryck för att schemalägga'
                : _formatFuture(_scheduledFor!),
            cleared: _scheduledFor == null,
            onTap: _pickFuture,
            onClear: () => setState(() => _scheduledFor = null),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Lägg till'),
          ),
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool cleared;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cleared,
    required this.onTap,
    required this.onClear,
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
              Icon(icon, color: SamboAppColors.onSurfaceVariant),
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
              if (!cleared)
                IconButton(
                  tooltip: 'Rensa',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Completion picker sheet
// ============================================================================

class _CompleteChoreSheet extends StatefulWidget {
  final Chore chore;
  final List<UserSummary> members;
  const _CompleteChoreSheet({required this.chore, required this.members});

  @override
  State<_CompleteChoreSheet> createState() => _CompleteChoreSheetState();
}

class _CompleteChoreSheetState extends State<_CompleteChoreSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final me = AuthService.instance.user.value;
    _selected = {if (me != null) me.id};
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
          Text('Markera klar',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            widget.chore.name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: SamboAppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('Vem gjorde det?',
              style: theme.textTheme.labelLarge?.copyWith(
                color: SamboAppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 4),
          ...widget.members.map((m) {
            final checked = _selected.contains(m.id);
            return CheckboxListTile(
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(m.id);
                  } else {
                    _selected.remove(m.id);
                  }
                });
              },
              title: Text(m.displayName),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: SamboAppColors.primary,
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            icon: const Icon(Icons.check),
            label: const Text('Markera klar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tiny shared widgets
// ============================================================================

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool archived;
  final bool canAdd;
  final VoidCallback onAdd;
  const _EmptyState(
      {required this.archived, required this.canAdd, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: SamboAppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            archived ? Icons.archive_outlined : Icons.cleaning_services,
            size: 48,
            color: SamboAppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          archived ? 'Inga arkiverade sysslor' : 'Inga sysslor än',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          archived
              ? 'Allt aktivt syns under "Sysslor".'
              : (canAdd
                  ? 'Lägg till första sysslan så börjar ni hålla koll tillsammans.'
                  : 'Be en admin lägga till sysslor.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
        if (!archived && canAdd) ...[
          const SizedBox(height: 32),
          Center(
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Lägg till syssla'),
            ),
          ),
        ],
      ],
    );
  }
}

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
