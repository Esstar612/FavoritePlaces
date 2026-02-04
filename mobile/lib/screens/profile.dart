import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';
import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/firestore_service.dart';
import 'package:favorite_places/screens/settings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isExporting = false;
  bool _isLoadingStats = false;
  Map<String, dynamic>? _backendStats;

  @override
  void initState() {
    super.initState();
    _loadBackendStats();
  }

  // ── load stats from backend ──────────────────────────────────────────────
  Future<void> _loadBackendStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/user/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final stats = jsonDecode(response.body);
        if (mounted) {
          setState(() => _backendStats = stats);
        }
      }
    } catch (e) {
      // Silently fail, show local stats instead
      print('Failed to load backend stats: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // ── export JSON ──────────────────────────────────────────────────────────
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final data = await FirestoreService.exportAllPlaces();
      final jsonString = jsonEncode(data, toEncodable: (obj) {
        if (obj is DateTime) return obj.toIso8601String();
        return obj.toString();
      });

      // Show the JSON in a dialog so user can copy it
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exported Data'),
            content: SingleChildScrollView(
              child: SelectableText(jsonString),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── sign out ─────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      // AuthGate will automatically route back to LoginScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final places = ref.watch(userPlacesProvider);
    final favoriteCount = places.where((p) => p.isFavorite).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Avatar + name ──────────────────────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (user?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? 'User',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),

            const SizedBox(height: 24),

            // ── Stats row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard(
                    context, 
                    '${_backendStats?['totalPlaces'] ?? places.length}', 
                    'Places'
                  ),
                  _statCard(
                    context, 
                    '${_backendStats?['favoriteCount'] ?? favoriteCount}', 
                    'Favorites'
                  ),
                  _statCard(
                    context, 
                    '${_backendStats?['categoriesUsed'] ?? places.map((p) => p.category).toSet().length}', 
                    'Categories'
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(indent: 24, endIndent: 24),

            // ── Enhanced Stats (from backend) ──────────────────────────
            if (_backendStats != null) ...[
              _sectionHeader(context, 'Statistics'),
              
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Average Rating'),
                trailing: Text(
                  _backendStats!['averageRating']?.toString() ?? '0',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: const Text('Places with Notes'),
                trailing: Text(
                  '${_backendStats!['placesWithNotes'] ?? 0}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.tag_outlined),
                title: const Text('Unique Tags'),
                trailing: Text(
                  '${_backendStats!['totalTags'] ?? 0}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const Divider(indent: 24, endIndent: 24),
            ],

            // ── Settings Section ───────────────────────────────────────────
            _sectionHeader(context, 'Settings'),

            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('App Settings'),
              subtitle: const Text('Theme, notifications, preferences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export My Data'),
              subtitle: const Text('Download all places as JSON'),
              trailing: _isExporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _isExporting ? null : _exportData,
            ),

            const Divider(indent: 24, endIndent: 24),

            // ── About Section ──────────────────────────────────────────────
            _sectionHeader(context, 'About'),

            ListTile(
              leading: const Icon(Icons.info_outlined),
              title: const Text('App Version'),
              trailing: const Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Sync Status'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
              subtitle: const Text('Connected to Firebase'),
            ),

            const Divider(indent: 24, endIndent: 24),

            // ── Danger Zone ────────────────────────────────────────────────
            _sectionHeader(context, 'Danger Zone'),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: _signOut,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  Widget _statCard(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
