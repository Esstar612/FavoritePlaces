import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

Future<LatLng?> currentLatLng() async {
  try {
    final location = Location();

    // On web, requesting a position *is* the permission prompt. There is no
    // separate grant step, and asking permission first reports "denied"
    // while the browser is still only in the "prompt" state. Native does
    // need the explicit request.
    if (!kIsWeb) {
      var status = await location.hasPermission();
      if (status == PermissionStatus.denied) {
        status = await location.requestPermission();
      }
      final allowed = status == PermissionStatus.granted ||
          status == PermissionStatus.grantedLimited;
      if (!allowed || !await location.serviceEnabled()) return null;
    }

    final data = await location.getLocation().timeout(
          const Duration(seconds: 20),
        );
    final lat = data.latitude, lng = data.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  } catch (_) {
    // Denied, unsupported, or timed out. The fallback map is already up and
    // search and pan both work, so this is a degraded start, not a failure.
    return null;
  }
}

/// A stand-in for the platform "blue dot" on web. Rendered as two circles,
/// a translucent accuracy halo and a solid core, so it reads as "you are
/// here" rather than being mistaken for the red selection pin.
Set<Circle> selfLocationCircles(LatLng? self) {
  if (!kIsWeb || self == null) return const {};
  const blue = Color(0xFF4285F4);
  return {
    Circle(
      circleId: const CircleId('self-halo'),
      center: self,
      radius: 45,
      fillColor: blue.withValues(alpha: 0.15),
      strokeWidth: 0,
    ),
    Circle(
      circleId: const CircleId('self-core'),
      center: self,
      radius: 9,
      fillColor: blue,
      strokeColor: Colors.white,
      strokeWidth: 2,
    ),
  };
}
