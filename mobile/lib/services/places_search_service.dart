import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:favorite_places/config.dart';
import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/place_types.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    this.matches = const [],
    this.distanceMeters,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final List<(int, int)> matches;
  final int? distanceMeters;
}

class PlacePhoto {
  const PlacePhoto({required this.name, this.author, this.authorUri});

  final String name;
  final String? author;
  final String? authorUri;
}

class PlaceDetailsResult {
  const PlaceDetailsResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.types = const [],
    this.photo,
  });

  final double latitude;
  final double longitude;
  final String address;
  final List<String> types;
  final PlacePhoto? photo;
}

/// Google Places (New) search, one autocomplete session per instance.
///
/// Billing: a session that ends in an Essentials details call bills its first
/// 12 autocomplete requests, and the rest are free. Every field in
/// [detailsFieldMask] is Essentials, so adding one from the Pro tier would
/// change the price of every pick.
class PlacesSearchService {
  PlacesSearchService({http.Client? client})
      : _client = client ?? http.Client(),
        _sessionToken = const Uuid().v4();

  final http.Client _client;
  String _sessionToken;

  static const detailsFieldMask = 'location,formattedAddress,types,photos';
  static const minRadiusMeters = 1000.0;
  static const maxRadiusMeters = 50000.0;

  static const _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    ({double latitude, double longitude})? origin,
    double? radiusMeters,
  }) async {
    if (input.trim().length < 3) return const [];

    final center = origin == null ? null : {'latitude': origin.latitude, 'longitude': origin.longitude};
    final response = await _client.post(
      Uri.parse(_autocompleteUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
      },
      body: jsonEncode({
        'input': input,
        'sessionToken': _sessionToken,
        if (center != null) 'origin': center,
        if (center != null && radiusMeters != null)
          'locationBias': {
            'circle': {
              'center': center,
              'radius': radiusMeters.clamp(minRadiusMeters, maxRadiusMeters),
            },
          },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Place search failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = (body['suggestions'] as List?) ?? const [];

    return suggestions
        .map((raw) => (raw as Map<String, dynamic>)['placePrediction'])
        .whereType<Map<String, dynamic>>()
        .map((p) {
          final fmt = (p['structuredFormat'] as Map<String, dynamic>?) ?? const {};
          final main = (fmt['mainText'] as Map<String, dynamic>?) ?? const {};
          String part(String key) =>
              ((fmt[key] as Map<String, dynamic>?)?['text'] as String?) ?? '';
          return PlaceSuggestion(
            placeId: p['placeId'] as String? ?? '',
            primaryText: part('mainText').isNotEmpty
                ? part('mainText')
                : ((p['text'] as Map<String, dynamic>?)?['text'] as String? ?? ''),
            secondaryText: part('secondaryText'),
            matches: [
              for (final m in (main['matches'] as List?) ?? const [])
                (
                  // Google omits startOffset when a match starts at 0.
                  ((m as Map<String, dynamic>)['startOffset'] as num?)?.toInt() ?? 0,
                  (m['endOffset'] as num).toInt(),
                ),
            ],
            distanceMeters: (p['distanceMeters'] as num?)?.toInt(),
          );
        })
        .where((s) => s.placeId.isNotEmpty)
        .toList();
  }

  /// Resolve a suggestion to coordinates. Ends the billing session, so a new
  /// token is issued for whatever the user searches next.
  Future<PlaceDetailsResult> details(String placeId) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId')
        .replace(queryParameters: {'sessionToken': _sessionToken});

    final response = await _client.get(uri, headers: {
      'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
      'X-Goog-FieldMask': detailsFieldMask,
    });

    // Whatever the outcome, the session is spent.
    _sessionToken = const Uuid().v4();

    if (response.statusCode != 200) {
      throw Exception('Place lookup failed (${response.statusCode})');
    }

    return _detailsFrom(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static const nearbyFieldMask =
      'places.id,places.displayName,places.types,places.location,places.formattedAddress,places.photos';
  static const nearbyRadiusMeters = 25.0;
  static const nearbyCandidates = 5;

  /// The closest Google place within [nearbyRadiusMeters] of a dropped pin, or
  /// null when there's nothing there. Billed as Nearby Search Pro on every
  /// call, so it runs once per pin, never per keystroke.
  Future<({String name, PlaceDetailsResult details})?> nearby(double latitude, double longitude) async {
    final response = await _client.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
        'X-Goog-FieldMask': nearbyFieldMask,
      },
      body: jsonEncode({
        'maxResultCount': nearbyCandidates,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': nearbyRadiusMeters,
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Nearby lookup failed (${response.statusCode})');
    }

    final places = [
      for (final raw in (jsonDecode(response.body) as Map<String, dynamic>)['places'] as List? ?? const [])
        if (((raw as Map<String, dynamic>)['displayName'] as Map<String, dynamic>?)?['text'] case final String name
            when name.isNotEmpty)
          (name: name, details: _detailsFrom(raw)),
    ];
    // Offices and suite tenants share a building's pin but carry only generic
    // types, so the nearest place with a real category is usually what was tapped.
    return places.where((p) => categoryForTypes(p.details.types) != PlaceCategory.other).firstOrNull ??
        places.firstOrNull;
  }
}

PlaceDetailsResult _detailsFrom(Map<String, dynamic> body) {
  final loc = (body['location'] as Map<String, dynamic>?) ?? const {};
  final lat = (loc['latitude'] as num?)?.toDouble();
  final lng = (loc['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) {
    throw Exception('Place has no coordinates');
  }

  final photos = (body['photos'] as List?) ?? const [];
  final first = photos.isEmpty ? null : photos.first as Map<String, dynamic>;
  final author = (first?['authorAttributions'] as List?)?.firstOrNull as Map<String, dynamic>?;
  return PlaceDetailsResult(
    latitude: lat,
    longitude: lng,
    address: body['formattedAddress'] as String? ?? '',
    types: [for (final t in (body['types'] as List?) ?? const []) t as String],
    photo: first?['name'] is String
        ? PlacePhoto(
            name: first!['name'] as String,
            author: author?['displayName'] as String?,
            authorUri: author?['uri'] as String?,
          )
        : null,
  );
}

String photoMediaUrl(String name, {int maxWidthPx = 400}) =>
    'https://places.googleapis.com/v1/$name/media?maxWidthPx=$maxWidthPx&key=${AppConfig.googleMapsApiKey}';
