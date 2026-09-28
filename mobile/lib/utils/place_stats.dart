import 'package:favorite_places/models/place.dart';

class PlaceStats {
  const PlaceStats({
    required this.places,
    required this.favorites,
    required this.averageRating,
    required this.withNotes,
    required this.uniqueTags,
    required this.mix,
  });

  factory PlaceStats.of(List<Place> places) {
    final rated = places.where((p) => p.rating > 0).toList();
    final counts = <PlaceCategory, int>{};
    for (final p in places) {
      counts.update(p.category, (n) => n + 1, ifAbsent: () => 1);
    }
    final mix = counts.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.index - b.key.index);
    return PlaceStats(
      places: places.length,
      favorites: places.where((p) => p.isFavorite).length,
      averageRating: rated.isEmpty ? null : rated.fold(0, (sum, p) => sum + p.rating) / rated.length,
      withNotes: places.where((p) => p.notes.trim().isNotEmpty).length,
      uniqueTags: {for (final p in places) ...p.tags.map((t) => t.trim().toLowerCase())}.length,
      mix: mix,
    );
  }

  final int places;
  final int favorites;

  final double? averageRating;
  final int withNotes;
  final int uniqueTags;

  final List<MapEntry<PlaceCategory, int>> mix;
}
