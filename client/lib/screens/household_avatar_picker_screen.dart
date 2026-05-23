import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sambo/services/household_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class HouseholdAvatarPickerScreen extends StatefulWidget {
  const HouseholdAvatarPickerScreen({super.key});

  @override
  State<HouseholdAvatarPickerScreen> createState() =>
      _HouseholdAvatarPickerScreenState();
}

class _HouseholdAvatarPickerScreenState
    extends State<HouseholdAvatarPickerScreen> {
  List<({String key, String url})>? _options;
  String? _selectedKey;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await HouseholdService.instance.avatarOptions();
      if (!mounted) return;
      setState(() => _options = options);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kunde inte ladda avatarer.');
    }
  }

  Future<void> _save() async {
    final key = _selectedKey;
    if (key == null) return;
    setState(() => _saving = true);
    try {
      final updated = await HouseholdService.instance.patchAvatar(key);
      if (!mounted) return;
      Navigator.pop(context, updated.avatarUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunde inte spara avatar.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Välj hushållsavatar'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _selectedKey != null ? _save : null,
              child: const Text('Spara'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _error = null);
                _loadOptions();
              },
              child: const Text('Försök igen'),
            ),
          ],
        ),
      );
    }

    final options = _options;
    if (options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        final isSelected = _selectedKey == opt.key;
        return GestureDetector(
          onTap: () => setState(() => _selectedKey = opt.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: SamboAppColors.secondary, width: 3)
                  : null,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: opt.url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ColoredBox(
                  color: Color(0xFF1A1A2E),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.home),
              ),
            ),
          ),
        );
      },
    );
  }
}
