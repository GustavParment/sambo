import 'package:flutter/material.dart';
import 'package:sambo/models/budget.dart';
import 'package:sambo/models/overview.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/overview_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

/// Dashboard tab — month-at-a-glance for what the household actually did
/// (chores) and how it spent (budget). One backend round-trip via
/// `/api/overview/{yyyy-MM}`; everything else is rendering.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late DateTime _monthStart;
  Overview? _data;
  Object? _error;
  String? _lastHouseholdId;

  String get _yearMonth =>
      '${_monthStart.year.toString().padLeft(4, '0')}-${_monthStart.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    _lastHouseholdId = AuthService.instance.user.value?.householdId;
    AuthService.instance.user.addListener(_onUserChanged);
    _data = OverviewService.instance.cachedOverview(_yearMonth);
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
    setState(() {
      _data = OverviewService.instance.cachedOverview(_yearMonth);
      _error = null;
    });
    _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await OverviewService.instance.getOverview(_yearMonth);
      if (!mounted) return;
      setState(() {
        _data = fresh;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_data == null) setState(() => _error = e);
    }
  }

  Future<void> _refresh() => _refreshInBackground();

  void _shiftMonth(int delta) {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month + delta, 1);
      _data = OverviewService.instance.cachedOverview(_yearMonth);
      _error = null;
    });
    _refreshInBackground();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Översikt'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _MonthSwitcher(
            monthStart: _monthStart,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(
          builder: (context) {
            if (_data == null && _error == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_data == null && _error != null) {
              return _ErrorState(error: _error!);
            }
            final d = _data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _ChoresCard(summary: d.chores),
                const SizedBox(height: 16),
                _BudgetCard(budget: d.budget),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Month switcher
// ============================================================================

const _swedishMonths = [
  'Januari', 'Februari', 'Mars', 'April', 'Maj', 'Juni',
  'Juli', 'Augusti', 'September', 'Oktober', 'November', 'December',
];

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
    final label =
        '${_swedishMonths[monthStart.month - 1]} ${monthStart.year}';
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
// Chores card
// ============================================================================

class _ChoresCard extends StatelessWidget {
  final ChoreSummary summary;
  const _ChoresCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cleaning_services_outlined,
                    color: SamboAppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Sysslor denna månad',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _BigStat(
                  value: '${summary.totalCompletions}',
                  label: 'gjorda',
                ),
                const SizedBox(width: 24),
                _BigStat(
                  value: '${summary.distinctChoresDone}',
                  label: 'distinkta',
                  muted: true,
                ),
              ],
            ),
            if (summary.participants.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _participantsLabel(summary.participants),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Inga sysslor avbockade än',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _participantsLabel(List<ChoreParticipant> ps) {
    final names = ps.map((p) => p.displayName).toList();
    if (names.length == 1) return '${names.first} har städat';
    if (names.length == 2) return '${names[0]} och ${names[1]} har städat';
    final last = names.removeLast();
    return '${names.join(', ')} och $last har städat';
  }
}

// ============================================================================
// Budget card
// ============================================================================

class _BudgetCard extends StatelessWidget {
  final MonthlyOverview budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spent = budget.totalSpent;
    final budgeted = budget.totalBudgeted;
    final remaining = budget.totalRemaining;
    final fraction = budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.0) : 0.0;
    final overspent = spent > budgeted && budgeted > 0;

    // Top 3 categories by spent. Server already returns them in sortOrder;
    // we resort here for the dashboard's "what dominated" angle.
    final top = [...budget.categories]
      ..sort((a, b) => b.spent.compareTo(a.spent));
    final visible = top.where((c) => c.spent > 0).take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: SamboAppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Ekonomi denna månad',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _BigStat(
                  value: '${_kr(spent)} kr',
                  label: 'spenderat',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor:
                    SamboAppColors.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                  overspent ? SamboAppColors.error : SamboAppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              budgeted == 0
                  ? 'Ingen budget satt'
                  : overspent
                      ? 'Över med ${_kr(spent - budgeted)} kr av ${_kr(budgeted)} kr'
                      : '${_kr(remaining)} kr kvar av ${_kr(budgeted)} kr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: overspent
                    ? SamboAppColors.error
                    : SamboAppColors.onSurfaceVariant,
                fontWeight: overspent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (visible.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Mest spenderat',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final c in visible) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.categoryName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${_kr(c.spent)} kr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tiny shared bits
// ============================================================================

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final bool muted;
  const _BigStat({
    required this.value,
    required this.label,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: muted ? SamboAppColors.onSurfaceVariant : null,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Let RefreshIndicator pull-to-retry even in the error state.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        Icon(Icons.cloud_off_outlined,
            size: 48,
            color: SamboAppColors.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(
          'Kunde inte hämta översikten',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SamboAppColors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

String _kr(double v) => v.abs().round().toString();
