import 'package:flutter/material.dart';
import 'package:sambo/models/leaderboard.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/leaderboard_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class LeaderboardSection extends StatefulWidget {
  const LeaderboardSection({super.key});

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {
  List<LeaderboardEntry>? _entries;
  String _period = 'week';
  String? _lastHouseholdId;

  @override
  void initState() {
    super.initState();
    _lastHouseholdId = AuthService.instance.user.value?.householdId;
    AuthService.instance.user.addListener(_onUserChanged);
    _entries = LeaderboardService.instance.cached(_period);
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
    setState(() => _entries = LeaderboardService.instance.cached(_period));
    _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    try {
      final list = await LeaderboardService.instance.fetch(_period);
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (_) {}
  }

  void _setPeriod(String p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _entries = LeaderboardService.instance.cached(p);
    });
    _refreshInBackground();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;

    // Don't render the card until we have data — avoids an empty flash.
    if (entries != null && entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: SamboAppColors.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Poängliga',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _PeriodToggle(period: _period, onChanged: _setPeriod),
                ],
              ),
            ),
            const Divider(height: 0),
            if (entries == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 0, indent: 56),
                _EntryRow(
                  entry: entries[i],
                  rank: i + 1,
                  initials: _initials(entries[i].displayName),
                ),
              ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Period toggle ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final String period;
  final void Function(String) onChanged;
  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      segments: const [
        ButtonSegment(value: 'week', label: Text('Vecka')),
        ButtonSegment(value: 'month', label: Text('Månad')),
      ],
      selected: {period},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

// ── Entry row ─────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final String initials;
  const _EntryRow({
    required this.entry,
    required this.rank,
    required this.initials,
  });

  Color _rankColor() => switch (rank) {
        1 => SamboAppColors.secondary,   // gold
        2 => SamboAppColors.onSurfaceVariant,
        3 => SamboAppColors.primary,
        _ => SamboAppColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor =
        SamboAppColors.hexToColor(entry.avatarColor) ?? SamboAppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 28,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: _rankColor(), size: 22)
                : Center(
                    child: Text(
                      '$rank',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: SamboAppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor,
            child: Text(
              initials,
              style: theme.textTheme.labelMedium?.copyWith(
                color: SamboAppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              entry.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SamboAppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.count} st',
              style: theme.textTheme.labelSmall?.copyWith(
                color: SamboAppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
