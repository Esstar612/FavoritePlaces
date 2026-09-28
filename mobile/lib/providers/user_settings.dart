import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';
import 'package:favorite_places/utils/units.dart';

@immutable
class UserSettings {
  const UserSettings({
    this.defaultRadius = 1000,
    this.theme = 'dark',
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.dataSharing = false,
    this.distanceUnit,
  });

  final int defaultRadius;
  final String theme;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool dataSharing;
  final DistanceUnit? distanceUnit;

  static const minRadius = 1000;
  static const maxRadius = 50000;

  DistanceUnit unitFor(Locale locale) => distanceUnit ?? defaultUnitFor(locale);

  ThemeMode get themeMode => switch (theme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        defaultRadius: ((json['defaultRadius'] as num?)?.toInt() ?? minRadius).clamp(minRadius, maxRadius),
        theme: json['theme'] as String? ?? 'dark',
        emailNotifications: json['emailNotifications'] as bool? ?? true,
        pushNotifications: json['pushNotifications'] as bool? ?? true,
        dataSharing: json['dataSharing'] as bool? ?? false,
        distanceUnit: DistanceUnit.values.asNameMap()[json['distanceUnit']],
      );

  Map<String, dynamic> toJson() => {
        'defaultRadius': defaultRadius,
        'theme': theme,
        if (distanceUnit case final unit?) 'distanceUnit': unit.name,
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
    DistanceUnit? distanceUnit,
  }) =>
      UserSettings(
        defaultRadius: (defaultRadius ?? this.defaultRadius).clamp(minRadius, maxRadius),
        theme: theme ?? this.theme,
        emailNotifications: emailNotifications ?? this.emailNotifications,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        dataSharing: dataSharing ?? this.dataSharing,
        distanceUnit: distanceUnit ?? this.distanceUnit,
      );
}

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

  void setLocal(UserSettings next) => state = next;

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

  void reset() => state = const UserSettings();
}

final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettings>(
  (ref) => UserSettingsNotifier(),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(userSettingsProvider).themeMode,
);

final distanceUnitProvider = Provider<DistanceUnit>(
  (ref) => ref
      .watch(userSettingsProvider)
      .unitFor(WidgetsBinding.instance.platformDispatcher.locale),
);
