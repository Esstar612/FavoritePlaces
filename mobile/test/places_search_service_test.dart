import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/places_search_service.dart';
import 'package:favorite_places/utils/place_types.dart';

PlacesSearchService _service(http.Response Function(http.Request) handler) =>
    PlacesSearchService(client: MockClient((request) async => handler(request)));

const _ferryDetails = {
  'location': {'latitude': 37.7955, 'longitude': -122.3937},
  'formattedAddress': '1 Ferry Building, San Francisco, CA 94111',
  'types': ['shopping_mall', 'tourist_attraction', 'point_of_interest', 'establishment'],
  'photos': [
    {
      'name': 'places/abc/photos/p1',
      'authorAttributions': [
        {'displayName': 'Ana', 'uri': 'https://maps.google.com/maps/contrib/1'},
      ],
    },
    {'name': 'places/abc/photos/p2'},
  ],
};

void main() {
  group('details', () {
    test('asks only for the Essentials fields', () async {
      late http.Request sent;
      final service = _service((request) {
        sent = request;
        return http.Response(jsonEncode(_ferryDetails), 200);
      });

      await service.details('abc');

      expect(sent.headers['X-Goog-FieldMask'], 'location,formattedAddress,types,photos');
    });

    test('reads the types and the first photo with its author', () async {
      final service = _service((_) => http.Response(jsonEncode(_ferryDetails), 200));

      final result = await service.details('abc');

      expect(result.types.first, 'shopping_mall');
      expect(result.photo!.name, 'places/abc/photos/p1');
      expect(result.photo!.author, 'Ana');
      expect(result.photo!.authorUri, 'https://maps.google.com/maps/contrib/1');
    });

    test('a place with no photos has no photo', () async {
      final service = _service((_) => http.Response(
            jsonEncode({..._ferryDetails}..remove('photos')),
            200,
          ));

      expect((await service.details('abc')).photo, isNull);
    });
  });

  group('nearby', () {
    test('asks for the closest place within 25 m', () async {
      late http.Request sent;
      final service = _service((request) {
        sent = request;
        return http.Response(jsonEncode({}), 200);
      });

      await service.nearby(37.7955, -122.3937);

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(sent.url.path, '/v1/places:searchNearby');
      expect(
        sent.headers['X-Goog-FieldMask'],
        'places.id,places.displayName,places.types,places.location,places.formattedAddress,places.photos',
      );
      expect(body['maxResultCount'], 5);
      expect(body['rankPreference'], 'DISTANCE');
      expect(body['locationRestriction']['circle']['radius'], 25.0);
    });

    test('reads the name, types and photo of the place found', () async {
      final service = _service((_) => http.Response(
            jsonEncode({
              'places': [
                {..._ferryDetails, 'displayName': {'text': 'Ferry Building'}},
              ],
            }),
            200,
          ));

      final found = (await service.nearby(37.7955, -122.3937))!;

      expect(found.name, 'Ferry Building');
      expect(found.details.types.first, 'shopping_mall');
      expect(found.details.photo!.author, 'Ana');
    });

    Map<String, dynamic> nearbyPlace(String name, List<String> types) => {
          'displayName': {'text': name},
          'types': types,
          'location': {'latitude': 40.764, 'longitude': -73.983},
        };

    test('prefers the nearest place with a real category over a suite tenant', () async {
      final service = _service((_) => http.Response(
            jsonEncode({
              'places': [
                nearbyPlace('Sanskrit Studies & Luminous Soul', ['point_of_interest', 'establishment']),
                nearbyPlace('The Grisly Pear', ['bar', 'point_of_interest', 'establishment']),
              ],
            }),
            200,
          ));

      expect((await service.nearby(40.764, -73.983))!.name, 'The Grisly Pear');
    });

    test('falls back to the nearest when none has a real category', () async {
      final service = _service((_) => http.Response(
            jsonEncode({
              'places': [
                nearbyPlace('Suite 9B', ['point_of_interest']),
                nearbyPlace('Suite 10A', ['establishment']),
              ],
            }),
            200,
          ));

      expect((await service.nearby(40.764, -73.983))!.name, 'Suite 9B');
    });

    test('nothing there gives null', () async {
      final service = _service((_) => http.Response(jsonEncode({}), 200));

      expect(await service.nearby(37.7955, -122.3937), isNull);
    });
  });

  group('autocomplete', () {
    const here = (latitude: 37.79, longitude: -122.39);

    for (final (radius, sent) in [(200.0, 1000.0), (10000.0, 10000.0), (80000.0, 50000.0)]) {
      test('biases around the origin with a radius of $sent for $radius', () async {
        late Map<String, dynamic> body;
        final service = _service((request) {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'suggestions': []}), 200);
        });

        await service.autocomplete('Ferry', origin: here, radiusMeters: radius);

        expect(body['origin'], {'latitude': 37.79, 'longitude': -122.39});
        expect(body['locationBias']['circle']['radius'], sent);
      });
    }

    test('sends no origin or bias without a location', () async {
      late Map<String, dynamic> body;
      final service = _service((request) {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'suggestions': []}), 200);
      });

      await service.autocomplete('Ferry', radiusMeters: 10000);

      expect(body.containsKey('origin'), isFalse);
      expect(body.containsKey('locationBias'), isFalse);
    });

    test('reads the distance and the matched text', () async {
      final service = _service((_) => http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'abc',
                    'distanceMeters': 640,
                    'structuredFormat': {
                      'mainText': {
                        'text': 'Ferry Building',
                        'matches': [
                          {'endOffset': 5},
                        ],
                      },
                      'secondaryText': {'text': 'San Francisco, CA'},
                    },
                  },
                },
                {
                  'placePrediction': {
                    'placeId': 'def',
                    'structuredFormat': {
                      'mainText': {'text': 'Ferry Plaza'},
                    },
                  },
                },
              ],
            }),
            200,
          ));

      final suggestions = await service.autocomplete('Ferry');

      expect(suggestions.first.primaryText, 'Ferry Building');
      expect(suggestions.first.matches, [(0, 5)]);
      expect(suggestions.first.distanceMeters, 640);
      expect(suggestions.last.distanceMeters, isNull);
      expect(suggestions.last.matches, isEmpty);
    });
  });

  group('categoryForTypes', () {
    for (final (types, category) in [
      (['shopping_mall', 'tourist_attraction', 'point_of_interest'], PlaceCategory.shopping),
      (['coffee_shop', 'cafe', 'food'], PlaceCategory.cafe),
      (['mexican_restaurant', 'food'], PlaceCategory.restaurant),
      (['book_store', 'point_of_interest'], PlaceCategory.shopping),
      (['point_of_interest', 'establishment'], PlaceCategory.other),
      (<String>[], PlaceCategory.other),
      (['tourist_attraction', 'art_gallery', 'art_museum', 'museum', 'point_of_interest'], PlaceCategory.museum),
      (['museum', 'park', 'point_of_interest', 'establishment'], PlaceCategory.museum),
      (['tourist_attraction', 'point_of_interest'], PlaceCategory.entertainment),
      (['park', 'tourist_attraction'], PlaceCategory.park),
    ]) {
      test('$types is ${category.name}', () {
        expect(categoryForTypes(types), category);
      });
    }
  });
}
