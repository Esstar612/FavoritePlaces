import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:favorite_places/models/place.dart';

class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key, required this.stops});

  final List<Place> stops;

  @override
  Widget build(BuildContext context) {
    final points = [for (final place in stops) LatLng(place.location.latitude, place.location.longitude)];
    return Scaffold(
      appBar: AppBar(title: const Text('Your route')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
        markers: {
          for (final (i, place) in stops.indexed)
            Marker(
              markerId: MarkerId(place.id),
              position: points[i],
              infoWindow: InfoWindow(title: '${i + 1}. ${place.title}'),
            ),
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        },
        onMapCreated: (controller) {
          if (points.length < 2) return;
          controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds(points), 64));
        },
      ),
    );
  }
}

LatLngBounds _bounds(List<LatLng> points) {
  final lats = points.map((p) => p.latitude);
  final lngs = points.map((p) => p.longitude);
  return LatLngBounds(
    southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
    northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
  );
}
