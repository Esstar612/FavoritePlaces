import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/utils/units.dart';

void main() {
  test('themeMode maps light, system, and anything else to dark', () {
    expect(const UserSettings(theme: 'light').themeMode, ThemeMode.light);
    expect(const UserSettings(theme: 'system').themeMode, ThemeMode.system);
    expect(const UserSettings(theme: 'purple').themeMode, ThemeMode.dark);
  });

  test('toJson sends distanceUnit only once it is chosen', () {
    expect(const UserSettings(distanceUnit: DistanceUnit.mi).toJson()['distanceUnit'], 'mi');
    expect(const UserSettings().toJson().containsKey('distanceUnit'), isFalse);
  });

  test('the radius is clamped to 1 to 50 km', () {
    expect(UserSettings.fromJson({'defaultRadius': 200}).defaultRadius, 1000);
    expect(UserSettings.fromJson({'defaultRadius': 80000}).defaultRadius, 50000);
    expect(const UserSettings().copyWith(defaultRadius: 90000).defaultRadius, 50000);
  });
}
