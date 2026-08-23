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
