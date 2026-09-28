import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/home_tab.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/widgets/place_visuals.dart';

class FavoritesEmpty extends ConsumerWidget {
  const FavoritesEmpty({super.key, required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final top = ([...places]..sort((a, b) => b.rating.compareTo(a.rating))).take(3).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      children: [
        Icon(Icons.favorite_border, size: 72, color: scheme.tertiary),
        const SizedBox(height: 16),
        const Text(
          'No favorites yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              "Tap the heart on any place and it'll wait for you here, ready for your next outing.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Text(
                    'Start with your highest rated',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
                  ),
                ),
                for (final place in top) _TopRow(place: place),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => ref.read(homeTabProvider.notifier).state = HomeTab.places,
              child: Text('Browse all ${places.length} ${places.length == 1 ? 'place' : 'places'}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopRow extends ConsumerWidget {
  const _TopRow({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 40,
              child: CategoryTile(category: place.category, iconSize: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.title, style: const TextStyle(fontSize: 16, height: 24 / 16)),
                Row(
                  children: [
                    Text(
                      '${place.category.displayName} · ',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const Icon(Icons.star, size: 12, color: Color(0xFFF9C74F)),
                    const SizedBox(width: 2),
                    Text('${place.rating}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add ${place.title} to favorites',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => ref.read(userPlacesProvider.notifier).toggleFavorite(place.id),
          ),
        ],
      ),
    );
  }
}
