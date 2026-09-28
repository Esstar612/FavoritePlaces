import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/map_style.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.location, this.title});

  final PlaceLocation location;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(location.latitude, location.longitude);
    return Scaffold(
      appBar: AppBar(title: Text(title ?? location.address, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: 16),
        style: mapStyleFor(Theme.of(context).brightness),
        markers: {
          Marker(
            markerId: const MarkerId('place'),
            position: target,
            infoWindow: InfoWindow(title: title, snippet: location.address),
          ),
        },
      ),
    );
  }
}
