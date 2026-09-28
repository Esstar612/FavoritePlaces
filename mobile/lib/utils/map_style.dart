// Same palette as the dark Static Maps style in static_map.dart, so the live
// map and Plan's route card read as one surface. Points of interest stay
// visible here because they help people find what to add.
const darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#2a2631"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#ccc3d6"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d1a22"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#253547"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#3e3847"}]}
]
''';
