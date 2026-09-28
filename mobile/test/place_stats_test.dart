import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/place_stats.dart';

Place _place(
  PlaceCategory category, {
  int rating = 0,
  bool favorite = false,
  String notes = '',
  List<String> tags = const [],
}) =>
    Place(
      title: 'p',
      location: const PlaceLocation(latitude: 0, longitude: 0, address: ''),
      category: category,
      rating: rating,
      isFavorite: favorite,
      notes: notes,
      tags: tags,
    );

void main() {
  test('counts places, favorites, notes and unique tags', () {
    final stats = PlaceStats.of([
      _place(PlaceCategory.cafe, favorite: true, notes: 'quiet', tags: ['Quiet', 'Views']),
      _place(PlaceCategory.cafe, notes: '  ', tags: ['quiet']),
      _place(PlaceCategory.park, favorite: true),
    ]);
    expect(stats.places, 3);
    expect(stats.favorites, 2);
    expect(stats.withNotes, 1);
    expect(stats.uniqueTags, 2);
  });

  test('averages only rated places, and is null when none are rated', () {
    expect(
      PlaceStats.of([
        _place(PlaceCategory.cafe, rating: 5),
        _place(PlaceCategory.cafe, rating: 4),
        _place(PlaceCategory.cafe),
      ]).averageRating,
      4.5,
    );
    expect(PlaceStats.of([_place(PlaceCategory.cafe)]).averageRating, isNull);
  });

  test('the mix is ordered by count, ties in category order', () {
    final mix = PlaceStats.of([
      _place(PlaceCategory.park),
      _place(PlaceCategory.cafe),
      _place(PlaceCategory.museum),
      _place(PlaceCategory.museum),
    ]).mix;
    expect(mix.map((e) => (e.key, e.value)), [
      (PlaceCategory.museum, 2),
      (PlaceCategory.cafe, 1),
      (PlaceCategory.park, 1),
    ]);
  });
}
