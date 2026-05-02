import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sambo/models/auth_user.dart';
import 'package:sambo/models/household_membership.dart';
import 'package:sambo/models/invite.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/services/household_service.dart';
import 'package:sambo/services/invite_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

/// Hard cap on household memberships per user, mirroring the backend's
/// `InviteService.MAX_HOUSEHOLDS_PER_USER`. The UI greys out the create/join
/// CTA once this is reached so the user gets a hint before the server
/// rejects them.
const int _maxHouseholdsPerUser = 3;

class SettingsScreen extends StatefulWidget {
  final AuthUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<HouseholdMembership>? _memberships;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadMemberships();
  }

  Future<void> _loadMemberships() async {
    try {
      final list = await HouseholdService.instance.memberships();
      if (!mounted) return;
      setState(() => _memberships = list);
    } catch (_) {
      // Silent — leave previous list. Pull-to-refresh would be nice future work.
    }
  }

  HouseholdMembership? get _active {
    final list = _memberships;
    if (list == null) return null;
    for (final m in list) {
      if (m.active) return m;
    }
    return null;
  }

  bool get _atCap => (_memberships?.length ?? 0) >= _maxHouseholdsPerUser;

  String get _initials {
    final parts = widget.user.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _humanError(Object e) {
    var msg = e.toString();
    final i = msg.indexOf(': ');
    if (i > 0 && msg.startsWith('HTTP ')) msg = msg.substring(i + 2);
    return msg;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchTo(HouseholdMembership m) async {
    if (m.active || _busy) return;
    await _runBusy(() async {
      try {
        await HouseholdService.instance.switchActive(m.householdId);
        await _loadMemberships();
        _toast('Bytte till ${m.householdName}');
      } catch (e) {
        _toast('Kunde inte byta hushåll: ${_humanError(e)}');
      }
    });
  }

  Future<void> _confirmLeave(HouseholdMembership m) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmLeaveSheet(membership: m),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      try {
        await HouseholdService.instance.leave(m.householdId);
        // If that was the last household, AuthService.signOut() was called and
        // the router will redirect to /login — no further work here.
        if (!mounted) return;
        await _loadMemberships();
        _toast('Lämnade ${m.householdName}');
      } catch (e) {
        _toast('Kunde inte lämna: ${_humanError(e)}');
      }
    });
  }

  Future<void> _createHousehold() async {
    if (_atCap) {
      _toast('Du kan max vara med i $_maxHouseholdsPerUser hushåll');
      return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _CreateHouseholdSheet(),
    );
    if (name == null || name.isEmpty) return;
    await _runBusy(() async {
      try {
        await HouseholdService.instance.create(name);
        await _loadMemberships();
        _toast('Hushållet "$name" skapades');
      } catch (e) {
        _toast('Kunde inte skapa hushåll: ${_humanError(e)}');
      }
    });
  }

  Future<void> _renameActive() async {
    final current = _active?.householdName ?? '';
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RenameHouseholdSheet(initialName: current),
    );
    if (newName == null || newName.isEmpty || newName == current) return;
    await _runBusy(() async {
      try {
        await HouseholdService.instance.rename(newName);
        await _loadMemberships();
        _toast('Hushållsnamn uppdaterat');
      } catch (e) {
        _toast('Kunde inte byta namn: ${_humanError(e)}');
      }
    });
  }

  Future<void> _generateInvite() async {
    Invite invite;
    try {
      invite = await InviteService.instance.generate();
    } catch (e) {
      _toast('Kunde inte skapa inbjudan: ${_humanError(e)}');
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
    if (mounted) await _loadMemberships();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final isAdminOfActive = active?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Inställningar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Hero(initials: _initials, user: widget.user),
          const SizedBox(height: 24),
          const _SectionLabel('Aktivt'),
          const SizedBox(height: 8),
          _ActiveHouseholdCard(
            active: active,
            isAdmin: isAdminOfActive,
            disabled: _busy,
            onRename: _renameActive,
            onInvite: _generateInvite,
            onLeave: active == null ? null : () => _confirmLeave(active),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Lägg till'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_home_outlined),
                  title: const Text('Skapa nytt hushåll'),
                  subtitle: Text(
                    _atCap
                        ? 'Max $_maxHouseholdsPerUser hushåll — lämna ett först'
                        : 'Du blir ägare till det nya hushållet',
                    style: TextStyle(
                      color: _atCap
                          ? SamboAppColors.onSurfaceVariant
                              .withValues(alpha: 0.6)
                          : SamboAppColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy && !_atCap,
                  onTap: _createHousehold,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.login_outlined),
                  title: const Text('Använd inbjudan'),
                  subtitle: Text(
                    _atCap
                        ? 'Max $_maxHouseholdsPerUser hushåll — lämna ett först'
                        : 'Gå med i ett befintligt hushåll',
                    style: TextStyle(
                      color: _atCap
                          ? SamboAppColors.onSurfaceVariant
                              .withValues(alpha: 0.6)
                          : SamboAppColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy && !_atCap,
                  onTap: _showAcceptSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SwitchHouseholdDropdown(
            memberships: _memberships,
            disabled: _busy,
            onSwitch: _switchTo,
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

/// Always-visible card for the currently active household. This is where
/// every detail-edit lives — rename, invite, leave — since "the active
/// household" is what every other tab in the app operates on. Switching to
/// a different one is a separate concern, handled by the dropdown below.
class _ActiveHouseholdCard extends StatelessWidget {
  final HouseholdMembership? active;
  final bool isAdmin;
  final bool disabled;
  final VoidCallback onRename;
  final VoidCallback onInvite;
  final VoidCallback? onLeave;

  const _ActiveHouseholdCard({
    required this.active,
    required this.isAdmin,
    required this.disabled,
    required this.onRename,
    required this.onInvite,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = active;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.home_filled,
                color: SamboAppColors.primary),
            title: Text(
              a?.householdName ?? 'Inget aktivt hushåll',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Aktivt hushåll'),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Byt hushållsnamn'),
            trailing: const Icon(Icons.chevron_right),
            enabled: a != null && !disabled,
            onTap: onRename,
          ),
          if (isAdmin) ...[
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Bjud in sambo'),
              subtitle: const Text('Generera en kod att dela'),
              trailing: const Icon(Icons.chevron_right),
              enabled: !disabled,
              onTap: onInvite,
            ),
          ],
          if (onLeave != null) ...[
            const Divider(height: 0),
            ListTile(
              leading:
                  const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text(
                'Lämna hushåll',
                style: TextStyle(color: Colors.redAccent),
              ),
              enabled: !disabled,
              onTap: onLeave,
            ),
          ],
        ],
      ),
    );
  }
}

/// Collapsed-by-default dropdown for switching active household. The header
/// deliberately *does not* show the active household — its only job is to
/// reveal the list of households the user can switch to. Tapping a row
/// switches; nothing else happens here (rename / leave / invite all live in
/// the always-visible AKTIVT card above).
class _SwitchHouseholdDropdown extends StatefulWidget {
  final List<HouseholdMembership>? memberships;
  final bool disabled;
  final void Function(HouseholdMembership) onSwitch;

  const _SwitchHouseholdDropdown({
    required this.memberships,
    required this.disabled,
    required this.onSwitch,
  });

  @override
  State<_SwitchHouseholdDropdown> createState() =>
      _SwitchHouseholdDropdownState();
}

class _SwitchHouseholdDropdownState extends State<_SwitchHouseholdDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.memberships;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Byt hushåll'),
            subtitle: list == null
                ? null
                : Text('${list.length} hushåll'),
            trailing: AnimatedRotation(
              turns: _open ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.expand_more),
            ),
            onTap: list == null || widget.disabled
                ? null
                : () => setState(() => _open = !_open),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: !_open || list == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const Divider(height: 0),
                      for (final m in list)
                        _SwitchRow(
                          membership: m,
                          disabled: widget.disabled,
                          onTap: m.active
                              ? null
                              : () {
                                  setState(() => _open = false);
                                  widget.onSwitch(m);
                                },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final HouseholdMembership membership;
  final bool disabled;
  final VoidCallback? onTap;
  const _SwitchRow({
    required this.membership,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = membership;
    return ListTile(
      enabled: !disabled,
      onTap: onTap,
      leading: Icon(
        m.active ? Icons.check_circle : Icons.circle_outlined,
        color: m.active ? SamboAppColors.primary : SamboAppColors.outline,
      ),
      title: Text(
        m.householdName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================================
// Pieces
// ============================================================================

class _Hero extends StatelessWidget {
  final String initials;
  final AuthUser user;
  const _Hero({required this.initials, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: SamboAppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
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
          _SheetHandle(),
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

class _CreateHouseholdSheet extends StatefulWidget {
  const _CreateHouseholdSheet();

  @override
  State<_CreateHouseholdSheet> createState() => _CreateHouseholdSheetState();
}

class _CreateHouseholdSheetState extends State<_CreateHouseholdSheet> {
  final _ctrl = TextEditingController();

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
          _SheetHandle(),
          Text('Nytt hushåll',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Du blir ägare och kan bjuda in andra med en kod.',
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
              hintText: 'Sommarstugan, Kontoret …',
            ),
            maxLength: 60,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add_home_outlined),
            label: const Text('Skapa hushåll'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmLeaveSheet extends StatelessWidget {
  final HouseholdMembership membership;
  const _ConfirmLeaveSheet({required this.membership});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(),
          Text('Lämna ${membership.householdName}?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Du får inte längre se sysslor, budget eller kalender för det här '
            'hushållet. Om du är den sista medlemmen tas hushållet bort helt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SamboAppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Lämna hushåll'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
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

  String get _shareText =>
      'Gå med i mitt Sambo-hushåll med koden: ${invite.code}\n\n'
      'Ladda ner Sambo, logga in och välj "Använd inbjudan".';

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: _shareText,
      subject: 'Sambo-inbjudan',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share),
              label: const Text('Dela inbjudan'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
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
          _SheetHandle(),
          Text('Använd inbjudan',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Ange koden från din sambo. Du kan vara med i flera hushåll '
            'samtidigt — du behöver inte lämna ditt nuvarande.',
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

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: SamboAppColors.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
