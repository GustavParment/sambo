import 'package:flutter/material.dart';
import 'package:sambo/models/auth_user.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class SettingsScreen extends StatelessWidget {
  final AuthUser user;
  const SettingsScreen({super.key, required this.user});

  String get _initials {
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Inställningar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Hero header --------------------------------------------------
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SamboAppColors.primary.withValues(alpha: 0.20),
                  SamboAppColors.secondary.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: SamboAppColors.outline.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: SamboAppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: SamboAppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SamboAppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: SamboAppColors.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: SamboAppColors.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel('Hushåll'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Household ID'),
                  subtitle: Text(
                    user.householdId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Bjud in sambo'),
                  subtitle: const Text('Snart…'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => AuthService.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Logga ut'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
