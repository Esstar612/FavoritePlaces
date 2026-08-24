import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/models/place.dart';

/// The minimum Firestore document Place.fromFirestore requires.
Map<String, dynamic> doc([Map<String, dynamic> overrides = const {}]) => {
      'id': 'abc123',
      'title': 'Blue Bottle Coffee',
      'lat': 37.7955,
      'lng': -122.3937,
      'address': '1 Ferry Building, San Francisco, CA',
      ...overrides,
    };

void main() {
  group('Place.fromFirestore', () {
    test('reads a full document', () {
      final place = Place.fromFirestore(doc({
        'category': 'cafe',
        'tags': ['Hidden Gem', 'Great Views'],
        'notes': 'Amazing pour over.',
        'rating': 5,
        'isFavorite': true,
        'photoUrls': ['https://example.com/a.jpg'],
        'visitDate': '2026-07-15T00:00:00.000Z',
        'createdAt': '2026-08-01T00:00:00.000Z',
      }));

      expect(place.id, 'abc123');
      expect(place.title, 'Blue Bottle Coffee');
      expect(place.category, PlaceCategory.cafe);
      expect(place.tags, ['Hidden Gem', 'Great Views']);
      expect(place.rating, 5);
      expect(place.isFavorite, isTrue);
      expect(place.photoUrls, ['https://example.com/a.jpg']);
      expect(place.location.latitude, closeTo(37.7955, 1e-6));
      expect(place.location.address, contains('Ferry Building'));
      expect(place.visitDate.year, 2026);
    });

    test('defaults every optional field when they are absent', () {
      final place = Place.fromFirestore(doc());

      expect(place.category, PlaceCategory.other);
      expect(place.tags, isEmpty);
      expect(place.photoUrls, isEmpty);
      expect(place.notes, '');
      expect(place.rating, 0);
      expect(place.isFavorite, isFalse);
      expect(place.summary, isNull);
    });

    test('falls back to "other" for a category the app does not know', () {
      final place = Place.fromFirestore(doc({'category': 'spaceport'}));
      expect(place.category, PlaceCategory.other);
    });

    test('survives an unparseable date rather than throwing', () {
      final place = Place.fromFirestore(doc({'visitDate': 'not-a-date'}));
      expect(place.visitDate, isNotNull);
    });

    test('accepts an integer latitude, which Firestore may hand back', () {
      final place = Place.fromFirestore(doc({'lat': 37, 'lng': -122}));
      expect(place.location.latitude, 37.0);
      expect(place.location.longitude, -122.0);
    });

    test('reads a cached summary when present', () {
      final place = Place.fromFirestore(doc({
        'notes': 'Great coffee.',
        'summary': {
          'whyILikedIt': 'The pour over.',
          'tips': 'Go early.',
          'bestTimeToGo': '8am',
          'sourceNotes': 'Great coffee.',
        },
      }));

      expect(place.summary, isNotNull);
      expect(place.summary!.tips, 'Go early.');
    });
  });

  group('PlaceSummary.matches', () {
    const summary = PlaceSummary(
      whyILikedIt: 'w', tips: 't', bestTimeToGo: 'b',
      sourceNotes: 'Great coffee.',
    );

    test('matches the notes it was generated from', () {
      expect(summary.matches('Great coffee.'), isTrue);
    });

    test('ignores surrounding whitespace', () {
      expect(summary.matches('  Great coffee.  '), isTrue);
    });

    // This is what stops a stale summary being shown after an edit.
    test('does not match once the notes change', () {
      expect(summary.matches('Great coffee, but pricey.'), isFalse);
    });
  });

  group('Place.copyWith', () {
    test('keeps identity and creation time', () {
      final original = Place.fromFirestore(doc({'createdAt': '2026-08-01T00:00:00.000Z'}));
      final copy = original.copyWith(title: 'Renamed');

      expect(copy.id, original.id);
      expect(copy.createdAt, original.createdAt);
      expect(copy.title, 'Renamed');
    });

    test('leaves untouched fields alone', () {
      final original = Place.fromFirestore(doc({'rating': 4, 'notes': 'keep me'}));
      final copy = original.copyWith(isFavorite: true);

      expect(copy.rating, 4);
      expect(copy.notes, 'keep me');
      expect(copy.isFavorite, isTrue);
    });
  });

  group('PlaceCategory', () {
    test('every value has a display name and an icon', () {
      for (final c in PlaceCategory.values) {
        expect(c.displayName, isNotEmpty, reason: 'no displayName for ${c.name}');
        expect(c.icon, isNotEmpty, reason: 'no icon for ${c.name}');
      }
    });

    test('names round-trip through Firestore storage', () {
      for (final c in PlaceCategory.values) {
        final place = Place.fromFirestore(doc({'category': c.name}));
        expect(place.category, c);
      }
    });
  });
}
