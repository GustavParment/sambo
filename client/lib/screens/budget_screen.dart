import 'package:flutter/material.dart';
import 'package:sambo/models/budget.dart';
import 'package:sambo/screens/category_detail_screen.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/budget_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late YearMonth _ym;
  _BudgetPageData? _data;
  Object? _error;
  String? _lastHouseholdId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ym = YearMonth(now.year, now.month);
    _lastHouseholdId = AuthService.instance.user.value?.householdId;
    AuthService.instance.user.addListener(_onUserChanged);
    _data = _readCache();
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
      _data = _readCache();
      _error = null;
    });
    _refreshInBackground();
  }

  _BudgetPageData? _readCache() {
    final cats = BudgetService.instance.cachedCategories();
    final ov = BudgetService.instance.cachedOverview(_ym.toIso());
    if (cats == null || ov == null) return null;
    return _BudgetPageData(categories: cats, overview: ov);
  }

  Future<void> _refreshInBackground() async {
    try {
      final results = await Future.wait([
        BudgetService.instance.listCategories(),
        BudgetService.instance.getOverview(_ym.toIso()),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _BudgetPageData(
          categories: results[0] as List<BudgetCategory>,
          overview: results[1] as MonthlyOverview,
        );
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
      _ym = _ym.shifted(delta);
      _data = _readCache();
      _error = null;
    });
    _refreshInBackground();
  }

  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<_NewBudgetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewBudgetSheet(),
    );
    if (result == null) return;
    try {
      final cat = await BudgetService.instance.createCategory(result.name);
      await BudgetService.instance.setAllocation(
        yearMonth: _ym.toIso(),
        categoryId: cat.id,
        amount: result.amount,
      );
      await _refresh();
    } catch (e) {
      _toast('Kunde inte skapa: $e');
    }
  }

  Future<void> _openDetail(BudgetCategory cat, CategoryStatus? status) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          category: cat,
          yearMonth: _ym,
          initialStatus: status,
        ),
      ),
    );
    // Refresh on return — they may have added/removed transactions.
    await _refresh();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _MonthSwitcher(
            ym: _ym,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget-fab',
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Ny budget'),
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
            final data = _data!;
            if (data.categories.isEmpty) {
              return _EmptyState(onAdd: _showAddSheet);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                for (final cat in data.categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CategoryCard(
                      category: cat,
                      status: data.statusFor(cat.id),
                      onTap: () => _openDetail(cat, data.statusFor(cat.id)),
                    ),
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
// Page-level data bundle
// ============================================================================

class _BudgetPageData {
  final List<BudgetCategory> categories;
  final MonthlyOverview overview;

  _BudgetPageData({required this.categories, required this.overview});

  CategoryStatus? statusFor(String categoryId) {
    for (final s in overview.categories) {
      if (s.categoryId == categoryId) return s;
    }
    return null;
  }
}

// ============================================================================
// Month switcher
// ============================================================================

/// Lightweight value type for (year, month). Avoids string juggling at call
/// sites.
class YearMonth {
  final int year;
  final int month;
  const YearMonth(this.year, this.month);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  YearMonth shifted(int months) {
    final total = year * 12 + (month - 1) + months;
    return YearMonth(total ~/ 12, (total % 12) + 1);
  }

  String swedishLabel() {
    const names = [
      'Januari', 'Februari', 'Mars', 'April', 'Maj', 'Juni',
      'Juli', 'Augusti', 'September', 'Oktober', 'November', 'December',
    ];
    return '${names[month - 1]} $year';
  }
}

class _MonthSwitcher extends StatelessWidget {
  final YearMonth ym;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSwitcher({
    required this.ym,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
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
              ym.swedishLabel(),
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
// Category card — name + tiny status hint (kr remaining / progress)
// ============================================================================

class _CategoryCard extends StatelessWidget {
  final BudgetCategory category;
  final CategoryStatus? status;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status;

    final hasBudget = s != null && s.budgeted > 0;
    final overspent = hasBudget && s.spent > s.budgeted;
    final progress = hasBudget ? (s.spent / s.budgeted).clamp(0.0, 1.0) : 0.0;

    final stripeColor = !hasBudget
        ? SamboAppColors.outline
        : overspent
            ? SamboAppColors.error
            : (progress > 0.8
                ? SamboAppColors.secondary
                : SamboAppColors.success);

    return Material(
      color: SamboAppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: SamboAppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!hasBudget)
                        Text(
                          'Ingen budget för månaden',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SamboAppColors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                overspent
                                    ? 'Över med ${_kr(s.spent - s.budgeted)} kr'
                                    : '${_kr(s.remaining)} kr kvar',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: overspent
                                      ? SamboAppColors.error
                                      : SamboAppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${_kr(s.spent)} / ${_kr(s.budgeted)} kr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: SamboAppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor:
                                SamboAppColors.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(stripeColor),
                          ),
                        ),
                      ],
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

/// Round to whole kr for display. Negative values render as their absolute
/// counterpart with the sign carried by surrounding text ("Över med X kr").
String _kr(double v) => v.abs().round().toString();

// ============================================================================
// "Ny budget" sheet — name + amount in one step
// ============================================================================

class _NewBudgetResult {
  final String name;
  final double amount;
  _NewBudgetResult({required this.name, required this.amount});
}

class _NewBudgetSheet extends StatefulWidget {
  const _NewBudgetSheet();

  @override
  State<_NewBudgetSheet> createState() => _NewBudgetSheetState();
}

class _NewBudgetSheetState extends State<_NewBudgetSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount < 0) return;
    Navigator.pop(context, _NewBudgetResult(name: name, amount: amount));
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
          Text('Ny budget',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Namn',
              hintText: 'Mat, Bensin, Hushållsartiklar …',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Belopp denna månad',
              suffixText: 'kr',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Skapa'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty / error states
// ============================================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

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
          child: const Icon(
            Icons.savings_outlined,
            size: 48,
            color: SamboAppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Inga budgetar än',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Skapa din första budget — t.ex. Mat eller Bensin — '
          'och börja lägga in köp för att hålla koll.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ny budget'),
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
