import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sambo/models/auth_user.dart';
import 'package:sambo/models/household.dart';
import 'package:sambo/models/invite.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/household_service.dart';
import 'package:sambo/services/invite_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final AuthUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Household? _household;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  Future<void> _loadHousehold() async {
    try {
      final h = await HouseholdService.instance.get();
      if (!mounted) return;
      setState(() => _household = h);
    } catch (_) {
      // Silent — the user already sees stale-or-empty name. Pull-to-refresh
      // would be nice future work.
    }
  }

  String get _initials {
    final parts = widget.user.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _generateInvite() async {
    Invite invite;
    try {
      invite = await InviteService.instance.generate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte skapa inbjudan: $e')),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InviteCodeSheet(invite: invite),
    );
  }

  Future<void> _showAcceptSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AcceptInviteSheet(),
    );
  }

  Future<void> _renameHousehold() async {
    final current = _household?.name ?? '';
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RenameHouseholdSheet(initialName: current),
    );
    if (newName == null || newName.isEmpty || newName == current) return;
    try {
      final updated = await HouseholdService.instance.rename(newName);
      if (!mounted) return;
      setState(() => _household = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hushållsnamn uppdaterat')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte byta namn: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = widget.user.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Inställningar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Hero header ------------------------------------------------
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
              border: Border.all(
                  color: SamboAppColors.outline.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
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
                  widget.user.displayName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SamboAppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: SamboAppColors.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.user.role,
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
          const _SectionLabel('Hushåll'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Hushållsnamn'),
                  subtitle: Text(_household?.name ?? '…'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _renameHousehold,
                ),
                if (isAdmin) ...[
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('Bjud in sambo'),
                    subtitle: const Text('Generera en kod att dela'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _generateInvite,
                  ),
                ],
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.login_outlined),
                  title: const Text('Använd inbjudan'),
                  subtitle: const Text('Gå med i ett befintligt hushåll'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAcceptSheet,
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

// ============================================================================
// Sheets
// ============================================================================

class _RenameHouseholdSheet extends StatefulWidget {
  final String initialName;
  const _RenameHouseholdSheet({required this.initialName});

  @override
  State<_RenameHouseholdSheet> createState() => _RenameHouseholdSheetState();
}

class _RenameHouseholdSheetState extends State<_RenameHouseholdSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
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
          Text('Hushållsnamn',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Visas i appen för alla medlemmar.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Namn',
              hintText: 'Hemma, Vasagatan 4 …',
            ),
            maxLength: 60,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeSheet extends StatelessWidget {
  final Invite invite;
  const _InviteCodeSheet({required this.invite});

  String _formatExpiry() {
    final hours = invite.expiresAt.difference(DateTime.now()).inHours;
    if (hours <= 0) return 'Utgången';
    if (hours == 1) return 'Går ut om 1 timme';
    if (hours < 24) return 'Går ut om $hours timmar';
    final days = (hours / 24).round();
    return 'Går ut om $days dagar';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: SamboAppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Inbjudan',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Dela koden med din sambo. Den måste loggas in på Sambo-appen och välja "Använd inbjudan".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: SamboAppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: SamboAppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              invite.code,
              style: theme.textTheme.displaySmall?.copyWith(
                color: SamboAppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatExpiry(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: SamboAppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod kopierad')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Kopiera kod'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptInviteSheet extends StatefulWidget {
  const _AcceptInviteSheet();

  @override
  State<_AcceptInviteSheet> createState() => _AcceptInviteSheetState();
}

class _AcceptInviteSheetState extends State<_AcceptInviteSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await InviteService.instance.accept(code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du är nu med i hushållet')),
      );
    } catch (e) {
      var msg = e.toString();
      final i = msg.indexOf(': ');
      if (i > 0 && msg.startsWith('HTTP ')) msg = msg.substring(i + 2);
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: SamboAppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Använd inbjudan',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Ange koden från din sambo. Du måste vara ensam i ditt nuvarande hushåll för att kunna byta.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 6,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: 'XXXXXX',
            ),
            inputFormatters: [
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SamboAppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? 'Ansluter…' : 'Anslut till hushåll'),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
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
