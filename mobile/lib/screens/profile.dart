import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/auth/signup.dart';
import 'package:favorite_places/screens/settings.dart';
import 'package:favorite_places/services/firestore_service.dart';
import 'package:favorite_places/utils/place_stats.dart';
import 'package:favorite_places/utils/user_display.dart';
import 'package:favorite_places/widgets/profile_stats.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final data = await FirestoreService.exportAllPlaces();
      final jsonString = jsonEncode(data, toEncodable: (obj) {
        if (obj is DateTime) return obj.toIso8601String();
        return obj.toString();
      });
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exported data'),
            content: SingleChildScrollView(child: SelectableText(jsonString)),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(action)),
        ],
      ),
    );
    return confirmed == true;
  }

  // AuthGate swaps the root screen on sign-out, but this pushed route would
  // otherwise stay on top showing a signed-out profile.
  Future<void> _leaveAccount() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authNotifierProvider.notifier).signOut();
    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      messenger.showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(state.error!))));
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _signOut() async {
    if (await _confirm('Sign out?', 'Your places stay saved to your account.', 'Sign out')) {
      await _leaveAccount();
    }
  }

  Future<void> _guestSignIn() async {
    if (await _confirm(
      'Leave the guest session?',
      "The sample places, and anything you added as a guest, won't carry over to your account.",
      'Continue',
    )) {
      await _leaveAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).value;
    final isGuest = user?.isAnonymous ?? false;
    final stats = PlaceStats.of(ref.watch(userPlacesProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isGuest ? scheme.secondaryContainer : scheme.primaryContainer,
                  foregroundColor: isGuest ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
                  child: isGuest
                      ? const Icon(Icons.person_outline, size: 36)
                      : Text(avatarInitial(user), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayNameOrFallback(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w500),
                      ),
                      Text(accountSubtitle(user), style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isGuest) ...[
            const SizedBox(height: 8),
            _GuestCard(
              places: stats.places,
              onCreateAccount: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              onSignIn: _guestSignIn,
            ),
          ],
          const SizedBox(height: 16),
          ProfileStatsCard(stats: stats),
          const SizedBox(height: 16),
          _Section(
            children: [
              _Row(
                icon: Icons.settings_outlined,
                title: 'App settings',
                subtitle: 'Theme, search radius, notifications',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _Row(
                icon: Icons.download_outlined,
                title: 'Export my data',
                subtitle: stats.places == 1
                    ? 'Download your 1 place as JSON'
                    : 'Download all ${stats.places} places as JSON',
                trailing: _isExporting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _isExporting ? null : _exportData,
              ),
              _Row(
                icon: Icons.cloud_outlined,
                title: 'Sync',
                subtitleWidget: isGuest
                    ? null
                    : Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF7DD99A), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text('Connected to Firebase'),
                        ],
                      ),
                subtitle: isGuest ? 'Sample places, saved to this guest session' : null,
              ),
              _Row(
                icon: Icons.info_outline,
                title: 'App version',
                trailing: Text('1.0.0', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          if (!isGuest) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: scheme.outline),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.places, required this.onCreateAccount, required this.onSignIn});

  final int places;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  static const _background = Color(0xFF3E2B33);
  static const _text = Color(0xFFFFD9E3);
  static const _accent = Color(0xFFF0B8C9);
  static const _onAccent = Color(0xFF492532);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These $places San Francisco spots are samples, so you can try every feature. '
                  'Sign in to start your own list and keep it in sync.',
                  style: const TextStyle(fontSize: 15, height: 22 / 15, color: _text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: _accent),
                onPressed: onCreateAccount,
                child: const Text('Create account'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: _onAccent),
                onPressed: onSignIn,
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final sub = subtitleWidget ?? (subtitle == null ? null : Text(subtitle!));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              Icon(icon, color: muted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, height: 24 / 16)),
                    if (sub != null)
                      DefaultTextStyle.merge(style: TextStyle(fontSize: 14, height: 20 / 14, color: muted), child: sub),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null) Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
