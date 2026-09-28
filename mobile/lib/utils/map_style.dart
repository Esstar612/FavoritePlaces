import 'package:flutter/material.dart';

const darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#2a2631"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#ccc3d6"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d1a22"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#253547"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#3e3847"}]}
]
''';

const lightMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f1ecf4"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#49454e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#fef7ff"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#cde2f4"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]}
]
''';

String mapStyleFor(Brightness brightness) => brightness == Brightness.light ? lightMapStyle : darkMapStyle;
