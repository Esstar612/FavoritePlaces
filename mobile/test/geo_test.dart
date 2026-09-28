import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/geo.dart';
import 'package:favorite_places/utils/units.dart';

Place _at(String title, double latitude, double longitude) => Place(
      title: title,
      location: PlaceLocation(latitude: latitude, longitude: longitude, address: ''),
    );

// About 111,320 m per degree of latitude.
double _north(double meters) => 37.7955 + meters / 111320;

void main() {
  test('distance between known points', () {
    // A pick 34 m from Blue Bottle's seeded pin, and Blue Bottle to SFMOMA.
    expect(haversineMeters(37.7955, -122.3937, 37.7957, -122.3934), closeTo(35, 5));
    expect(haversineMeters(37.7955, -122.3937, 37.7857, -122.4011), closeTo(1270, 30));
  });

  for (final (meters, unit, text) in [
    (243, DistanceUnit.km, '240 m'),
    (1234, DistanceUnit.km, '1.2 km'),
    (23400, DistanceUnit.km, '23 km'),
    (640, DistanceUnit.mi, '0.4 mi'),
    (37000, DistanceUnit.mi, '23 mi'),
    (20, DistanceUnit.mi, '0.1 mi'),
    (4126000, DistanceUnit.mi, '2,564 mi'),
    (4126000, DistanceUnit.km, '4,126 km'),
  ]) {
    test('$meters m in ${unit.name} reads $text', () {
      expect(formatDistance(meters, unit), text);
    });
  }

  test('the nearest saved place within 60 m', () {
    final places = [_at('far', _north(50), -122.3937), _at('near', _north(35), -122.3937)];

    expect(savedPlaceNear(places, 37.7955, -122.3937)!.title, 'near');
  });

  test('nothing past 60 m', () {
    expect(savedPlaceNear([_at('next door', _north(70), -122.3937)], 37.7955, -122.3937), isNull);
  });
}
