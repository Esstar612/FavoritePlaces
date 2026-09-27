import 'package:favorite_places/config.dart';
import 'package:favorite_places/models/place.dart';

/// Google Static Maps image for a coordinate.
///
/// Used for the location previews, and as a place's card image when it has no
/// photo — a map of where it is says more than a grey placeholder.
String staticMapUrl({
  required double latitude,
  required double longitude,
  int width = 600,
  int height = 300,
  int zoom = 16,
}) =>
    'https://maps.googleapis.com/maps/api/staticmap'
    '?center=$latitude,$longitude'
    '&zoom=$zoom'
    '&size=${width}x$height'
    '&maptype=roadmap'
    '&markers=color:red%7Clabel:A%7C$latitude,$longitude'
    '&key=${AppConfig.googleMapsApiKey}';

/// Convenience for a [PlaceLocation].
String staticMapUrlFor(
  PlaceLocation location, {
  int width = 600,
  int height = 300,
  int zoom = 16,
}) =>
    staticMapUrl(
      latitude: location.latitude,
      longitude: location.longitude,
      width: width,
      height: height,
      zoom: zoom,
    );

// Dark styling matches the app's dark theme on the results card.
const _darkStyle = '&style=element:geometry%7Ccolor:0x2a2631'
    '&style=element:labels.text.fill%7Ccolor:0xccc3d6'
    '&style=element:labels.text.stroke%7Ccolor:0x1d1a22'
    '&style=feature:water%7Ccolor:0x253547'
    '&style=feature:road%7Celement:geometry%7Ccolor:0x3e3847'
    '&style=feature:poi%7Cvisibility:off';

/// Static map of an outing: numbered markers in stop order, joined by a line.
String staticRouteMapUrl(List<PlaceLocation> stops, {int width = 640, int height = 280}) {
  final points = [for (final stop in stops) '${stop.latitude},${stop.longitude}'];
  final markers = [
    for (final (i, point) in points.indexed) '&markers=color:0xD3BBFF%7Clabel:${i + 1}%7C$point',
  ].join();
  final path = points.length > 1 ? '&path=color:0xD3BBFFCC%7Cweight:4%7C${points.join('%7C')}' : '';
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?size=${width}x$height&scale=2&maptype=roadmap'
      '$_darkStyle$markers$path'
      '&key=${AppConfig.googleMapsApiKey}';
}
