import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:favorite_places/config.dart';
import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_settings.dart';
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

  /// Values normally arrive at sign-in; refresh on entry so the screen reflects
  /// changes made on another device.
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

  /// Persist a change. The notifier applies it locally first, so the theme
  /// switch takes effect immediately and rolls back if the write fails.
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

  Future<void> _saveSettings() async {
    await _update(ref.read(userSettingsProvider));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: ListView(
        children: [
          // ── Map Settings ────────────────────────────────────────────
          _sectionHeader(context, 'Map Settings'),
          
          ListTile(
            leading: const Icon(Icons.radar),
            title: const Text('Default Search Radius'),
            subtitle: Text('${(settings.defaultRadius / 1000).toStringAsFixed(1)} km'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.defaultRadius.toDouble(),
                min: 500,
                max: 10000,
                divisions: 19,
                label: '${(settings.defaultRadius / 1000).toStringAsFixed(1)} km',
                // Persist on release, not on every drag frame.
                onChanged: (value) => ref
                    .read(userSettingsProvider.notifier)
                    .setLocal(settings.copyWith(defaultRadius: value.toInt())),
                onChangeEnd: (value) =>
                    _update(settings.copyWith(defaultRadius: value.toInt())),
              ),
            ),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Appearance ──────────────────────────────────────────────
          _sectionHeader(context, 'Appearance'),
          
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(settings.theme == 'dark' ? 'Dark Mode' : 'Light Mode'),
            trailing: Switch(
              value: settings.theme == 'dark',
              onChanged: (value) => _update(
                settings.copyWith(theme: value ? 'dark' : 'light'),
              ),
            ),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Notifications ───────────────────────────────────────────
          _sectionHeader(context, 'Notifications'),
          
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive updates via email'),
            value: settings.emailNotifications,
            onChanged: (value) =>
                _update(settings.copyWith(emailNotifications: value)),
          ),
          
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Get notified about new features'),
            value: settings.pushNotifications,
            onChanged: (value) =>
                _update(settings.copyWith(pushNotifications: value)),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Privacy ─────────────────────────────────────────────────
          _sectionHeader(context, 'Privacy & Data'),
          
          SwitchListTile(
            secondary: const Icon(Icons.analytics_outlined),
            title: const Text('Anonymous Usage Data'),
            subtitle: const Text('Help improve the app'),
            value: settings.dataSharing,
            onChanged: (value) =>
                _update(settings.copyWith(dataSharing: value)),
          ),

          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open privacy policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening privacy policy...')),
              );
            },
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Account Actions ─────────────────────────────────────────
          _sectionHeader(context, 'Account'),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text('Sign Out', style: TextStyle(color: Colors.orange)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
              }
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete all your data'),
            onTap: () => _showDeleteAccountDialog(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final emailController = TextEditingController();

    // The typed value is read after the dialog closes, so capture it before
    // disposing rather than holding the controller past its usefulness.
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

      // Call backend to delete account
      try {
        final token = await user.getIdToken();
        final response = await http.delete(
          Uri.parse('${AppConfig.backendUrl}/user/account'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          // What the user typed, not user.email — sending the latter would
          // make the backend's confirmation check trivially self-satisfying.
          body: jsonEncode({'confirmEmail': typedEmail}),
        );

        if (response.statusCode == 200) {
          // Account deleted successfully, sign out
          await ref.read(authNotifierProvider.notifier).signOut();
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
