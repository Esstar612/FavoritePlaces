import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

/// User preferences, mirrored from `GET /user/settings`.
///
/// Defaults here must match the backend's defaults in routes/user.js so an
/// unauthenticated cold start looks the same as a fresh account.
@immutable
class UserSettings {
  const UserSettings({
    this.defaultRadius = 1000,
    this.theme = 'dark',
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.dataSharing = false,
  });

  final int defaultRadius;
  final String theme;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool dataSharing;

  ThemeMode get themeMode =>
      theme == 'light' ? ThemeMode.light : ThemeMode.dark;

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        defaultRadius: (json['defaultRadius'] as num?)?.toInt() ?? 1000,
        theme: json['theme'] as String? ?? 'dark',
        emailNotifications: json['emailNotifications'] as bool? ?? true,
        pushNotifications: json['pushNotifications'] as bool? ?? true,
        dataSharing: json['dataSharing'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'defaultRadius': defaultRadius,
        'theme': theme,
        'emailNotifications': emailNotifications,
        'pushNotifications': pushNotifications,
        'dataSharing': dataSharing,
      };

  UserSettings copyWith({
    int? defaultRadius,
    String? theme,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? dataSharing,
  }) =>
      UserSettings(
        defaultRadius: defaultRadius ?? this.defaultRadius,
        theme: theme ?? this.theme,
        emailNotifications: emailNotifications ?? this.emailNotifications,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        dataSharing: dataSharing ?? this.dataSharing,
      );
}

/// Owns the two `/user/settings` calls so the fetch happens once at sign-in
/// rather than on every visit to the Settings screen — that's what lets the
/// saved theme apply at launch.
class UserSettingsNotifier extends StateNotifier<UserSettings> {
  UserSettingsNotifier() : super(const UserSettings());

  bool _loading = false;
  bool get isLoading => _loading;

  Future<Map<String, String>?> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch settings for the signed-in user. Safe to call more than once.
  /// Returns null on success, or a human-readable message on failure.
  Future<String?> load() async {
    if (_loading) return null;
    _loading = true;
    try {
      final headers = await _authHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/user/settings'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        return 'Could not load settings (${response.statusCode}).';
      }

      state = UserSettings.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      return null;
    } catch (e) {
      debugPrint('Failed to load settings: $e');
      return 'Could not load settings. Check your connection.';
    } finally {
      _loading = false;
    }
  }

  /// Apply [next] locally without persisting — for continuous controls (a
  /// slider drag) that should not fire a write per frame. Follow with [save].
  void setLocal(UserSettings next) => state = next;

  /// Apply [next] immediately, then persist. Rolls back and returns a message
  /// if the write fails, so the UI never keeps a value the server rejected.
  Future<String?> save(UserSettings next) async {
    final previous = state;
    state = next;

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        state = previous;
        return 'You are not signed in.';
      }

      final response = await http.put(
        Uri.parse('${AppConfig.backendUrl}/user/settings'),
        headers: headers,
        body: jsonEncode(next.toJson()),
      );

      if (response.statusCode != 200) {
        state = previous;
        return 'Failed to save settings (${response.statusCode}): ${response.body}';
      }
      return null;
    } catch (e) {
      state = previous;
      return 'Failed to save settings: $e';
    }
  }

  /// Drop back to defaults on sign-out so the next user doesn't inherit them.
  void reset() => state = const UserSettings();
}

final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettings>(
  (ref) => UserSettingsNotifier(),
);

/// Theme currently in force. Watched by MyApp.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(userSettingsProvider).themeMode,
);
