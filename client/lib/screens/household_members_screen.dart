import 'package:flutter/material.dart';
import 'package:sambo/models/chore.dart';
import 'package:sambo/services/household_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class HouseholdMembersScreen extends StatefulWidget {
  final String householdName;
  const HouseholdMembersScreen({super.key, required this.householdName});

  @override
  State<HouseholdMembersScreen> createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen> {
  List<UserSummary>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await HouseholdService.instance.members();
      if (!mounted) return;
      setState(() => _members = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
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
    final members = _members;

    return Scaffold(
      appBar: AppBar(title: Text(widget.householdName)),
      body: Builder(
        builder: (_) {
          if (_error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Kunde inte hämta medlemmar',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Försök igen'),
                  ),
                ],
              ),
            );
          }

          if (members == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (members.isEmpty) {
            return Center(
              child: Text(
                'Inga medlemmar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: SamboAppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: members.length,
            separatorBuilder: (ctx, i) => const Divider(height: 0, indent: 72),
            itemBuilder: (_, i) {
              final m = members[i];
              final avatarColor =
                  SamboAppColors.hexToColor(m.avatarColor) ??
                  SamboAppColors.primary;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    _initials(m.displayName),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: SamboAppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  m.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
