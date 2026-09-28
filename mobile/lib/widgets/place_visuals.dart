import 'package:flutter/material.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/widgets/plan/common.dart';

const categoryTileColors = {
  PlaceCategory.cafe: (Color(0xFF4A3040), Color(0xFFFFD9E3)),
  PlaceCategory.museum: (Color(0xFF3F3470), Color(0xFFEBDDFF)),
  PlaceCategory.park: (Color(0xFF2F4A38), Color(0xFFCDEBD3)),
  PlaceCategory.restaurant: (Color(0xFF4A3A28), Color(0xFFFFDDB8)),
};

const lightCategoryTileColors = {
  PlaceCategory.cafe: (Color(0xFFFFD8E4), Color(0xFF7D5260)),
  PlaceCategory.museum: (Color(0xFFEBDDFF), Color(0xFF6B4FA3)),
  PlaceCategory.park: (Color(0xFFD5ECD9), Color(0xFF2F6B43)),
  PlaceCategory.restaurant: (Color(0xFFFFE2C4), Color(0xFF7A4A12)),
};

const _categoryColors = {
  PlaceCategory.restaurant: (Color(0xFFB25E00), Color(0xFFFFB77C)),
  PlaceCategory.cafe: (Color(0xFF9A4868), Color(0xFFFFB0CB)),
  PlaceCategory.park: (Color(0xFF2E7D4F), Color(0xFF8FD5A6)),
  PlaceCategory.museum: (Color(0xFF6B4FA3), Color(0xFFD3BBFF)),
  PlaceCategory.shopping: (Color(0xFF1E6AA3), Color(0xFF9CCAFF)),
  PlaceCategory.entertainment: (Color(0xFF00796B), Color(0xFF7ED8C8)),
  PlaceCategory.hotel: (Color(0xFF7A5C3E), Color(0xFFE3C4A0)),
  PlaceCategory.bar: (Color(0xFFA63D40), Color(0xFFFFB3AE)),
  PlaceCategory.gym: (Color(0xFF6F7A00), Color(0xFFC8D35A)),
  PlaceCategory.other: (Color(0xFF6F6977), Color(0xFFCAC4D0)),
};

Color categoryColor(PlaceCategory category, Brightness brightness) {
  final (light, dark) = _categoryColors[category]!;
  return brightness == Brightness.light ? light : dark;
}

(Color, Color) tileColorsFor(PlaceCategory category, ColorScheme scheme) =>
    (scheme.brightness == Brightness.light ? lightCategoryTileColors : categoryTileColors)[category] ??
    (scheme.secondaryContainer, scheme.onSecondaryContainer);

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
