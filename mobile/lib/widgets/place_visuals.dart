import 'package:flutter/material.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/widgets/plan/common.dart';

const categoryTileColors = {
  PlaceCategory.cafe: (Color(0xFF4A3040), Color(0xFFFFD9E3)),
  PlaceCategory.museum: (Color(0xFF3F3470), Color(0xFFEBDDFF)),
  PlaceCategory.park: (Color(0xFF2F4A38), Color(0xFFCDEBD3)),
  PlaceCategory.restaurant: (Color(0xFF4A3A28), Color(0xFFFFDDB8)),
};

(Color, Color) tileColorsFor(PlaceCategory category, ColorScheme scheme) =>
    categoryTileColors[category] ?? (scheme.secondaryContainer, scheme.onSecondaryContainer);

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.iconSize = 32});

  final PlaceCategory category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tileColorsFor(category, Theme.of(context).colorScheme);
    return ColoredBox(
      color: background,
      child: Center(
        child: Icon(categoryIcon(category), size: iconSize, color: foreground.withValues(alpha: 0.6)),
      ),
    );
  }
}

class PlaceThumb extends StatelessWidget {
  const PlaceThumb({super.key, required this.place, this.size = 72, this.radius = 12});

  final Place place;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tile = CategoryTile(category: place.category, iconSize: size * 4 / 9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: place.photoUrls.isNotEmpty
            ? Image.network(
                place.photoUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => tile,
              )
            : tile,
      ),
    );
  }
}
