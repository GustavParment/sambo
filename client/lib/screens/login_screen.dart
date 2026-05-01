import 'package:flutter/material.dart';
import 'package:sambo/services/auth_service.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Soft radial glow behind the logo for depth.
          const _LoginBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/sambo_app_logo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Sambo',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: SamboAppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delad budget och städlista',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: SamboAppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SamboAppColors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(_busy ? 'Loggar in…' : 'Logga in med Google'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Top-anchored "shield" — full bleed at the top edge, rounded into a
    // half-ellipse at the bottom. Height covers roughly the upper half of
    // the screen so logo + title sit on the orange field, the CTA below
    // sits on the dark background.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: size.height * 0.55,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SamboAppColors.primary.withValues(alpha: 0.32),
              SamboAppColors.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.elliptical(size.width / 2, 110),
            bottomRight: Radius.elliptical(size.width / 2, 110),
          ),
        ),
      ),
    );
  }
}
