import 'dart:math';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/units.dart';

const _earthRadiusMeters = 6371000.0;
const _metersPerMile = 1609.344;
const duplicateRadiusMeters = 60.0;

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double degrees) => degrees * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * asin(sqrt(a));
}

String formatDistance(num meters, DistanceUnit unit) {
  String short(double value) => value < 10 ? value.toStringAsFixed(1) : _grouped(value.round());
  return switch (unit) {
    DistanceUnit.km when meters < 1000 => '${(meters / 10).round() * 10} m',
    DistanceUnit.km => '${short(meters / 1000)} km',
    DistanceUnit.mi => '${short(max(meters / _metersPerMile, 0.1))} mi',
  };
}

String _grouped(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

Place? savedPlaceNear(
  Iterable<Place> places,
  double latitude,
  double longitude, {
  double within = duplicateRadiusMeters,
}) {
  Place? nearest;
  var best = within;
  for (final place in places) {
    final d = haversineMeters(latitude, longitude, place.location.latitude, place.location.longitude);
    if (d <= best) {
      best = d;
      nearest = place;
    }
  }
  return nearest;
}
