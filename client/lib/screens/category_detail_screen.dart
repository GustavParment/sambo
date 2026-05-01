import 'package:flutter/material.dart';
import 'package:sambo/models/budget.dart';
import 'package:sambo/screens/budget_screen.dart' show YearMonth;
import 'package:sambo/services/budget_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

/// Detail view for one category in one month.
///
/// AppBar gives the user a back arrow to the budget tab automatically. From
/// here they can:
///   - see budgeted / spent / remaining (rounded to whole kr),
///   - browse transactions for the month,
///   - add a new purchase (drains the budget),
///   - edit the monthly budget amount.
class CategoryDetailScreen extends StatefulWidget {
  final BudgetCategory category;
  final YearMonth yearMonth;

  /// Snapshot from the budget overview screen — used for instant first paint.
  /// We refetch on init to get the authoritative latest numbers.
  final CategoryStatus? initialStatus;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.yearMonth,
    this.initialStatus,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_DetailData> _fetch() async {
    final results = await Future.wait([
      BudgetService.instance.getOverview(widget.yearMonth.toIso()),
      BudgetService.instance.listTransactions(
        yearMonth: widget.yearMonth.toIso(),
        categoryId: widget.category.id,
      ),
    ]);
    final overview = results[0] as MonthlyOverview;
    CategoryStatus? status;
    for (final s in overview.categories) {
      if (s.categoryId == widget.category.id) {
        status = s;
        break;
      }
    }
    return _DetailData(
      status: status,
      transactions: results[1] as List<BudgetTransaction>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    await _future;
  }

  Future<void> _showAddPurchaseSheet() async {
    final result = await showModalBottomSheet<_NewPurchaseResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewPurchaseSheet(),
    );
    if (result == null) return;
    try {
      await BudgetService.instance.createTransaction(
        categoryId: widget.category.id,
        amount: result.amount,
        description: result.description,
        bookedDate: result.bookedDate,
      );
      await _refresh();
    } catch (e) {
      _toast('Kunde inte spara köp: $e');
    }
  }

  Future<void> _editAllocation(double currentAmount) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditAllocationSheet(initial: currentAmount),
    );
    if (amount == null) return;
    try {
      await BudgetService.instance.setAllocation(
        yearMonth: widget.yearMonth.toIso(),
        categoryId: widget.category.id,
        amount: amount,
      );
      await _refresh();
    } catch (e) {
      _toast('Kunde inte uppdatera budget: $e');
    }
  }

  Future<void> _confirmDeleteCategory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort budget?'),
        content: Text(
          '"${widget.category.name}" och budgetbeloppen för alla månader tas '
          'bort permanent. Köp som var kopplade till kategorin blir '
          'okategoriserade men finns kvar.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt')),
          FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SamboAppColors.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ta bort')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BudgetService.instance.deleteCategory(widget.category.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _toast('Kunde inte ta bort: $e');
    }
  }

  Future<void> _confirmDelete(BudgetTransaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort köp?'),
        content: Text('"${tx.description}" tas bort från budgeten.'),
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
        await BudgetService.instance.deleteTransaction(tx.id);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mer',
            onSelected: (v) {
              if (v == 'delete') _confirmDeleteCategory();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: SamboAppColors.error),
                  title: Text('Ta bort budget',
                      style: TextStyle(color: SamboAppColors.error)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPurchaseSheet,
        icon: const Icon(Icons.add),
        label: const Text('Lägg till köp'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DetailData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                widget.initialStatus == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(error: snap.error!);
            }
            final data = snap.data;
            final status = data?.status ?? widget.initialStatus;
            final transactions = data?.transactions ?? const <BudgetTransaction>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _MetricsCard(
                  status: status,
                  yearMonth: widget.yearMonth,
                  onEditBudget: () => _editAllocation(status?.budgeted ?? 0),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Köp den här månaden',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: SamboAppColors.onSurfaceVariant,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                if (transactions.isEmpty)
                  _NoTransactions()
                else
                  for (final tx in transactions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TransactionTile(
                        tx: tx,
                        onDelete: () => _confirmDelete(tx),
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
// Detail-page data bundle
// ============================================================================

class _DetailData {
  final CategoryStatus? status;
  final List<BudgetTransaction> transactions;
  _DetailData({required this.status, required this.transactions});
}

// ============================================================================
// Big metrics card at the top
// ============================================================================

class _MetricsCard extends StatelessWidget {
  final CategoryStatus? status;
  final YearMonth yearMonth;
  final VoidCallback onEditBudget;

  const _MetricsCard({
    required this.status,
    required this.yearMonth,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status;
    final hasBudget = s != null && s.budgeted > 0;
    final overspent = hasBudget && s.spent > s.budgeted;
    final progress = hasBudget ? (s.spent / s.budgeted).clamp(0.0, 1.0) : 0.0;

    final accent = !hasBudget
        ? SamboAppColors.outline
        : overspent
            ? SamboAppColors.error
            : (progress > 0.8
                ? SamboAppColors.secondary
                : SamboAppColors.success);

    return Material(
      color: SamboAppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    yearMonth.swedishLabel(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: SamboAppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditBudget,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(hasBudget ? 'Ändra budget' : 'Sätt budget'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!hasBudget) ...[
              Text(
                'Ingen budget satt',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Tryck "Sätt budget" för att lägga in ett belopp '
                'för ${yearMonth.swedishLabel()}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    overspent
                        ? '−${_kr(s.spent - s.budgeted)}'
                        : _kr(s.remaining),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: overspent
                          ? SamboAppColors.error
                          : SamboAppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'kr ${overspent ? "över" : "kvar"}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: SamboAppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: SamboAppColors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricColumn(
                    label: 'Spenderat',
                    value: '${_kr(s.spent)} kr',
                  ),
                  _MetricColumn(
                    label: 'Budget',
                    value: '${_kr(s.budgeted)} kr',
                    align: CrossAxisAlignment.end,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final CrossAxisAlignment align;
  const _MetricColumn({
    required this.label,
    required this.value,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Transaction tile
// ============================================================================

class _TransactionTile extends StatelessWidget {
  final BudgetTransaction tx;
  final VoidCallback onDelete;

  const _TransactionTile({required this.tx, required this.onDelete});

  String _dateLabel() {
    final d = tx.bookedDate;
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final whoBy = tx.createdByName ?? 'Okänd';
    return Material(
      color: SamboAppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$whoBy · ${_dateLabel()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SamboAppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_kr(tx.amount)} kr',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
    );
  }
}

class _NoTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Inga köp än — tryck "Lägg till köp" när du handlar.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

// ============================================================================
// Add-purchase sheet
// ============================================================================

class _NewPurchaseResult {
  final double amount;
  final String description;
  final DateTime bookedDate;
  _NewPurchaseResult({
    required this.amount,
    required this.description,
    required this.bookedDate,
  });
}

class _NewPurchaseSheet extends StatefulWidget {
  const _NewPurchaseSheet();

  @override
  State<_NewPurchaseSheet> createState() => _NewPurchaseSheetState();
}

class _NewPurchaseSheetState extends State<_NewPurchaseSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late DateTime _bookedDate;

  @override
  void initState() {
    super.initState();
    _bookedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _bookedDate = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final desc = _descCtrl.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;
    Navigator.pop(
      context,
      _NewPurchaseResult(
        amount: amount,
        description: desc,
        bookedDate: _bookedDate,
      ),
    );
  }

  String _dateLabel(DateTime d) {
    const names = [
      'jan', 'feb', 'mar', 'apr', 'maj', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    return '${d.day} ${names[d.month - 1]} ${d.year}';
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
          Text('Lägg till köp',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Belopp',
              suffixText: 'kr',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Vad köpte du?',
              hintText: 'ICA Maxi, Toapapper …',
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Material(
            color: SamboAppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        color: SamboAppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Datum',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: SamboAppColors.onSurfaceVariant,
                              )),
                          Text(_dateLabel(_bookedDate),
                              style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Spara köp'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Edit-allocation sheet
// ============================================================================

class _EditAllocationSheet extends StatefulWidget {
  final double initial;
  const _EditAllocationSheet({required this.initial});

  @override
  State<_EditAllocationSheet> createState() => _EditAllocationSheetState();
}

class _EditAllocationSheetState extends State<_EditAllocationSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial > 0 ? widget.initial.round().toString() : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null || v < 0) return;
    Navigator.pop(context, v);
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
          Text('Månadens budget',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Belopp',
              suffixText: 'kr',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Helpers / shared
// ============================================================================

String _kr(double v) => v.abs().round().toString();

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
