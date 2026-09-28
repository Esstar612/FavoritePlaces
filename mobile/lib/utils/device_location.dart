import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

Future<LatLng?> currentLatLng() async {
  try {
    final location = Location();

    // On web, getLocation() is the permission prompt; asking first reports denied.
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
    return LatLng(data.latitude, data.longitude);
  } catch (_) {
    return null;
  }
}

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
