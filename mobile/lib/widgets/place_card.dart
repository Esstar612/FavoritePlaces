import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/utils/evidence.dart';
import 'package:favorite_places/utils/static_map.dart';
import 'package:favorite_places/widgets/place_visuals.dart';

class PlaceCard extends ConsumerWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.onLongPress,
    this.evidence,
  });

  final Place place;
  final Evidence? evidence;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 124,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Hero(place: place),
                  Positioned(left: 12, top: 12, child: _CategoryPill(category: place.category)),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface,
                        fixedSize: const Size.square(44),
                      ),
                      tooltip: place.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                      color: place.isFavorite ? scheme.error : scheme.onSurface,
                      icon: Icon(place.isFavorite ? Icons.favorite : Icons.favorite_border),
                      onPressed: () => ref.read(userPlacesProvider.notifier).toggleFavorite(place.id),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (place.rating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 20, color: Color(0xFFF9C74F)),
                        const SizedBox(width: 4),
                        Text(
                          '${place.rating}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  if (evidence case final evidence?) ...[
                    const SizedBox(height: 8),
                    _EvidenceLine(evidence: evidence),
                  ] else
                    ..._details(scheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(ColorScheme scheme) => [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.place, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                place.location.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        if (place.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in place.tags.take(2)) _Tag(label: tag)],
          ),
        ],
        if (place.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            place.notes.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ];
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (lead, quote) = switch (evidence) {
      TagEvidence(:final tag) => ('Tagged ', tag),
      NoteEvidence(:final excerpt) => ('From your note: ', excerpt),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.auto_awesome, size: 16, color: scheme.tertiary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: lead,
              children: [
                TextSpan(
                  text: '\u201C$quote\u201D',
                  style: TextStyle(fontStyle: FontStyle.italic, color: scheme.onSurface),
                ),
              ],
            ),
            style: TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final tile = CategoryTile(category: place.category, iconSize: 64);
    return Image.network(
      place.photoUrls.isNotEmpty
          ? place.photoUrls.first
          : staticMapUrlFor(place.location, width: 600, height: 248, zoom: 15),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => frame == null ? tile : child,
      errorBuilder: (context, error, stack) => tile,
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${category.icon} ${category.displayName}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
