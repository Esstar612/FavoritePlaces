import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:favorite_places/config.dart';

/// One autocomplete suggestion.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;    // e.g. "Blue Bottle Coffee"
  final String secondaryText;  // e.g. "Ferry Building, San Francisco, CA"
}

/// Resolved coordinates for a chosen suggestion.
class PlaceDetailsResult {
  const PlaceDetailsResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

/// Google Places Autocomplete (New).
///
/// Billing note: autocomplete keystrokes are grouped into a *session* by a
/// token, and a session that ends in a Place Details call is billed as one
/// unit rather than one-per-keystroke. Create a service per search, reuse it
/// for every keystroke, then call [details] — which closes the session.
class PlacesSearchService {
  PlacesSearchService() : _sessionToken = const Uuid().v4();

  String _sessionToken;

  static const _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 3) return const [];

    final response = await http.post(
      Uri.parse(_autocompleteUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
      },
      body: jsonEncode({
        'input': input,
        'sessionToken': _sessionToken,
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
          String part(String key) =>
              ((fmt[key] as Map<String, dynamic>?)?['text'] as String?) ?? '';
          return PlaceSuggestion(
            placeId: p['placeId'] as String? ?? '',
            primaryText: part('mainText').isNotEmpty
                ? part('mainText')
                : ((p['text'] as Map<String, dynamic>?)?['text'] as String? ?? ''),
            secondaryText: part('secondaryText'),
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

    final response = await http.get(uri, headers: {
      'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
      'X-Goog-FieldMask': 'location,formattedAddress',
    });

    // Whatever the outcome, the session is spent.
    _sessionToken = const Uuid().v4();

    if (response.statusCode != 200) {
      throw Exception('Place lookup failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final loc = (body['location'] as Map<String, dynamic>?) ?? const {};
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw Exception('Place has no coordinates');
    }

    return PlaceDetailsResult(
      latitude: lat,
      longitude: lng,
      address: body['formattedAddress'] as String? ?? '',
    );
  }
}
