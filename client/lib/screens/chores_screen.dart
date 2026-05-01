import 'package:flutter/material.dart';
import 'package:sambo/models/chore.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/chore_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  late Future<List<Chore>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChoreService.instance.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = ChoreService.instance.list());
    await _future;
  }

  Future<void> _complete(Chore c) async {
    try {
      await ChoreService.instance.complete(c.id);
      await _refresh();
    } catch (e) {
      _toast('Kunde inte markera som klar: $e');
    }
  }

  Future<void> _showAddSheet() async {
    final controller = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: SamboAppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Ny syssla',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Namn',
                hintText: 'Dammsugning, diska …',
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lägg till'),
            ),
          ],
        ),
      ),
    );

    if (created == true && controller.text.trim().isNotEmpty) {
      try {
        await ChoreService.instance.create(controller.text.trim());
        await _refresh();
      } catch (e) {
        _toast('Kunde inte skapa: $e');
      }
    }
  }

  Future<void> _confirmDelete(Chore c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort syssla?'),
        content: Text('"${c.name}" tas bort permanent.'),
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
      appBar: AppBar(title: const Text('Sysslor')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Ny'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Chore>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(error: snap.error!);
            }
            final chores = snap.data ?? const <Chore>[];
            if (chores.isEmpty) {
              return _EmptyState(canAdd: isAdmin, onAdd: _showAddSheet);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: chores.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChoreCard(
                  chores[i],
                  onComplete: _complete,
                  onDelete: isAdmin ? _confirmDelete : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChoreCard extends StatelessWidget {
  final Chore chore;
  final Future<void> Function(Chore) onComplete;
  final Future<void> Function(Chore)? onDelete;

  const _ChoreCard(this.chore,
      {required this.onComplete, this.onDelete});

  /// Pick stripe + pill colour based on how stale this chore is.
  ({Color stripe, Color pillBg, Color pillFg, String pillText}) _stale() {
    final days = chore.daysSinceCompleted;
    if (days == null) {
      return (
        stripe: SamboAppColors.outline,
        pillBg: SamboAppColors.surfaceContainerHighest,
        pillFg: SamboAppColors.onSurfaceVariant,
        pillText: 'Aldrig'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _stale();
    final by = chore.lastCompletedBy?.displayName;
    return Material(
      color: SamboAppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: onDelete != null ? () => onDelete!(chore) : null,
        onTap: () => onComplete(chore),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: s.stripe,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
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
  final bool canAdd;
  final VoidCallback onAdd;
  const _EmptyState({required this.canAdd, required this.onAdd});

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
            Icons.cleaning_services,
            size: 48,
            color: SamboAppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Inga sysslor än',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          canAdd
              ? 'Lägg till första sysslan så börjar ni hålla koll tillsammans.'
              : 'Be en admin lägga till sysslor.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: SamboAppColors.onSurfaceVariant,
          ),
        ),
        if (canAdd) ...[
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
