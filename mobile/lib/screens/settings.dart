import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:favorite_places/config.dart';
import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/utils/geo.dart';
import 'package:favorite_places/utils/units.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final error = await ref.read(userSettingsProvider.notifier).load();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _update(UserSettings next) async {
    setState(() => _isSaving = true);
    final error = await ref.read(userSettingsProvider.notifier).save(next);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(userSettingsProvider);
    final unit = settings.unitFor(Localizations.localeOf(context));
    final isGuest = ref.watch(authStateProvider).value?.isAnonymous ?? false;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final muted = TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant);
    Widget heading(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
          child: Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: scheme.primary),
          ),
        );
    Widget label(String title, String subtitle) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, height: 24 / 16)),
            Text(subtitle, style: muted),
          ],
        );
    Widget card(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
          padding: padding,
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
    Widget toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(child: label(title, subtitle)),
              const SizedBox(width: 16),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        );
    final divider = Divider(height: 1, color: scheme.outlineVariant);
    final radiusKm = (settings.defaultRadius / 1000).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          heading('Appearance'),
          card([
            label('Theme', "System follows your phone's setting"),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'light', label: Text('Light')),
                ButtonSegment(value: 'dark', label: Text('Dark')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {settings.themeMode.name},
              onSelectionChanged: (value) => _update(settings.copyWith(theme: value.single)),
            ),
          ]),
          heading('Search'),
          card([
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: label('Default search radius', 'For place search')),
                const SizedBox(width: 12),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    formatDistance(settings.defaultRadius, unit),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            Slider(
              value: radiusKm.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              semanticFormatterCallback: (value) => formatDistance(value * 1000, unit),
              onChanged: (value) => ref
                  .read(userSettingsProvider.notifier)
                  .setLocal(settings.copyWith(defaultRadius: value.round() * 1000)),
              onChangeEnd: (value) => _update(settings.copyWith(defaultRadius: value.round() * 1000)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDistance(UserSettings.minRadius, unit), style: muted.copyWith(fontSize: 12)),
                Text(formatDistance(UserSettings.maxRadius, unit), style: muted.copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            divider,
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: label('Distance units', 'Used for distances across the app')),
                const SizedBox(width: 16),
                SegmentedButton<DistanceUnit>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: DistanceUnit.km, label: Text('km')),
                    ButtonSegment(value: DistanceUnit.mi, label: Text('mi')),
                  ],
                  selected: {unit},
                  onSelectionChanged: (value) => _update(settings.copyWith(distanceUnit: value.single)),
                ),
              ],
            ),
          ]),
          heading('Notifications'),
          card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            [
              toggle('Push notifications', 'Reminders and plan updates on this phone', settings.pushNotifications,
                  (value) => _update(settings.copyWith(pushNotifications: value))),
              divider,
              toggle('Email notifications', 'Account and sync updates', settings.emailNotifications,
                  (value) => _update(settings.copyWith(emailNotifications: value))),
            ],
          ),
          heading('Privacy'),
          card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            [
              toggle('Anonymous usage data', 'Help improve the app', settings.dataSharing,
                  (value) => _update(settings.copyWith(dataSharing: value))),
              divider,
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening privacy policy...')),
                ),
              ),
            ],
          ),
          if (!isGuest) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              onPressed: _showDeleteAccountDialog,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete account'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final emailController = TextEditingController();

    final bool? confirmed;
    final String typedEmail;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account and all associated data. This action cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Type your email to confirm:'),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: user.email,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      );
      typedEmail = emailController.text.trim();
    } finally {
      emailController.dispose();
    }

    if (confirmed == true && mounted) {
      if (typedEmail != user.email) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email does not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final navigator = Navigator.of(context);
      try {
        final token = await user.getIdToken();
        final response = await http.delete(
          Uri.parse('${AppConfig.backendUrl}/user/account'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          // What was typed, not user.email, or the backend's confirmation check always passes.
          body: jsonEncode({'confirmEmail': typedEmail}),
        );

        if (response.statusCode == 200) {
          await ref.read(authNotifierProvider.notifier).signOut();
          navigator.popUntil((route) => route.isFirst);
        } else {
          throw Exception('Failed to delete account');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
