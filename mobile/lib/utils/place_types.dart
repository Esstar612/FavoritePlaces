import 'package:favorite_places/models/place.dart';

const _exact = {
  'cafe': PlaceCategory.cafe,
  'coffee_shop': PlaceCategory.cafe,
  'bakery': PlaceCategory.cafe,
  'restaurant': PlaceCategory.restaurant,
  'park': PlaceCategory.park,
  'national_park': PlaceCategory.park,
  'hiking_area': PlaceCategory.park,
  'museum': PlaceCategory.museum,
  'art_gallery': PlaceCategory.museum,
  'shopping_mall': PlaceCategory.shopping,
  'store': PlaceCategory.shopping,
  'movie_theater': PlaceCategory.entertainment,
  'amusement_park': PlaceCategory.entertainment,
  'night_club': PlaceCategory.entertainment,
  'bowling_alley': PlaceCategory.entertainment,
  'tourist_attraction': PlaceCategory.entertainment,
  'lodging': PlaceCategory.hotel,
  'hotel': PlaceCategory.hotel,
  'bar': PlaceCategory.bar,
  'pub': PlaceCategory.bar,
  'gym': PlaceCategory.gym,
  'fitness_center': PlaceCategory.gym,
};

const _byPriority = [
  PlaceCategory.museum,
  PlaceCategory.cafe,
  PlaceCategory.restaurant,
  PlaceCategory.bar,
  PlaceCategory.hotel,
  PlaceCategory.gym,
  PlaceCategory.shopping,
  PlaceCategory.park,
  PlaceCategory.entertainment,
];

PlaceCategory? _category(String type) =>
    _exact[type] ??
    (type.endsWith('_museum')
        ? PlaceCategory.museum
        : type.endsWith('_restaurant')
            ? PlaceCategory.restaurant
            : type.endsWith('_store')
                ? PlaceCategory.shopping
                : null);

/// The most specific category among all of a place's types. Google often lists
/// a generic type such as tourist_attraction first, so the order it gives
/// isn't a guide.
PlaceCategory categoryForTypes(List<String> types) {
  final found = types.map(_category).nonNulls.toSet();
  return _byPriority.firstWhere(found.contains, orElse: () => PlaceCategory.other);
}
