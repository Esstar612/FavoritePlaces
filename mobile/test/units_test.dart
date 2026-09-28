import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/utils/units.dart';

void main() {
  test('miles only where the country uses them', () {
    expect(defaultUnitFor(const Locale('en', 'US')), DistanceUnit.mi);
    expect(defaultUnitFor(const Locale('en', 'GB')), DistanceUnit.mi);
    expect(defaultUnitFor(const Locale('my', 'MM')), DistanceUnit.mi);
    expect(defaultUnitFor(const Locale('en', 'CA')), DistanceUnit.km);
    expect(defaultUnitFor(const Locale('fr', 'FR')), DistanceUnit.km);
    expect(defaultUnitFor(const Locale('en')), DistanceUnit.km);
  });

  test('a saved unit wins over the locale', () {
    final settings = UserSettings.fromJson({'distanceUnit': 'km'});

    expect(settings.unitFor(const Locale('en', 'US')), DistanceUnit.km);
  });

  for (final json in [
    <String, dynamic>{},
    {'distanceUnit': 'miles'},
    {'distanceUnit': null},
  ]) {
    test('an unset or unknown unit falls back to the locale: $json', () {
      final settings = UserSettings.fromJson(json);

      expect(settings.distanceUnit, isNull);
      expect(settings.unitFor(const Locale('en', 'US')), DistanceUnit.mi);
    });
  }
}
