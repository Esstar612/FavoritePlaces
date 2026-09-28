import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place_map.dart';
import 'package:favorite_places/screens/place_detail.dart';
import 'package:favorite_places/utils/evidence.dart';
import 'package:favorite_places/widgets/place_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlacesList extends ConsumerWidget {
  const PlacesList({
    super.key,
    required this.places,
    this.evidenceQuery,
    this.groupByCategory = false,
  });

  final List<Place> places;
  final String? evidenceQuery;
  final bool groupByCategory;

  void _showOptionsMenu(BuildContext context, Place place, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddPlaceMapScreen(placeToEdit: place),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(place.isFavorite ? Icons.favorite : Icons.favorite_border),
              title: Text(place.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(userPlacesProvider.notifier).toggleFavorite(place.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        place.isFavorite ? 'Removed from favorites' : 'Added to favorites',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Delete Place'),
                    content: Text('Are you sure you want to delete ${place.title}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(userPlacesProvider.notifier).deletePlace(place.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${place.title} deleted'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (places.isEmpty) {
      // Scrollable even though it fits, so the parent RefreshIndicator still
      // responds — an empty list is exactly when a refresh is wanted.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'No places found',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters or\ntap + to add your first place!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rows = <Object>[
      for (final (i, place) in places.indexed) ...[
        if (groupByCategory && (i == 0 || places[i - 1].category != place.category)) place.category,
        place,
      ],
    ];
    return ListView.separated(
      itemCount: rows.length,
      // Allow the pull gesture even when the list is shorter than the screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      separatorBuilder: (context, index) =>
          SizedBox(height: index + 1 < rows.length && rows[index + 1] is PlaceCategory ? 20 : 12),
      itemBuilder: (ctx, index) => switch (rows[index]) {
        PlaceCategory category => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '${category.icon} ${category.displayName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        final Place place => PlaceCard(
            place: place,
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => PlaceDetailScreen(place: place),
                transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            ),
            onLongPress: () => _showOptionsMenu(context, place, ref),
            evidence: evidenceQuery == null ? null : evidenceFor(place, evidenceQuery!),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
