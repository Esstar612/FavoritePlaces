import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/agent_service.dart';
import 'package:favorite_places/utils/static_map.dart';
import 'package:favorite_places/widgets/plan/common.dart';

class PlanResultsView extends ConsumerWidget {
  const PlanResultsView({super.key, required this.state});

  final PlanResults state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(planProvider.notifier);
    final places = {for (final p in ref.watch(userPlacesProvider)) p.id: p};
    final result = state.result;
    final stops = [
      for (final stop in result.stops)
        if (places[stop.placeId] case final place?) (stop, place),
    ];
    final legs = {for (final leg in result.legs) (leg.fromPlaceId, leg.toPlaceId): leg};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        PlanYouAsked(request: state.request),
        const SizedBox(height: 16),
        if (result.overview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.tertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(result.overview, style: const TextStyle(fontSize: 18, height: 26 / 18)),
                ),
              ],
            ),
          ),
        if (stops.length > 1) ...[
          const SizedBox(height: 16),
          _RouteCard(stops: stops),
        ],
        const SizedBox(height: 16),
        for (final (i, (stop, place)) in stops.indexed) ...[
          if (i > 0) _LegRow(leg: legs[(stops[i - 1].$1.placeId, stop.placeId)]),
          _StopCard(stop: stop, place: place, number: i + 1),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: _big,
                onPressed: notifier.retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try another'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                style: _big,
                onPressed: notifier.reset,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New plan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final _big = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
  iconSize: WidgetStateProperty.all(20),
);

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.stops});

  final List<(Stop, Place)> stops;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = stops.first.$1.suggestedTime;
    final last = stops.last.$1.suggestedTime;
    final span = first != null && last != null && first != last
        ? '$first to $last'
        : '${stops.length} stops';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.network(
            staticRouteMapUrl([for (final (_, place) in stops) place.location]),
            height: 176,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox(height: 176),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              span,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.place, required this.number});

  final Stop stop;
  final Place place;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(place: place, number: number),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stop.suggestedTime case final time?)
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          time,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(place.title, style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${place.category.displayName} · ', style: muted),
                    const Icon(Icons.star, size: 12, color: Color(0xFFF9C74F)),
                    Text('${place.rating}', style: muted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.reason.isEmpty ? 'Your starting point' : stop.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.place, required this.number});

  final Place place;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = _tileColors[place.category] ??
        (scheme.secondaryContainer, scheme.onSecondaryContainer);
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 72,
                child: place.photoUrls.isNotEmpty
                    ? Image.network(place.photoUrls.first, fit: BoxFit.cover)
                    : ColoredBox(
                        color: background,
                        child: Icon(
                          categoryIcon(place.category),
                          size: 32,
                          color: foreground.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surfaceContainer, width: 2),
            ),
            child: Text(
              '$number',
              style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

const _tileColors = {
  PlaceCategory.cafe: (Color(0xFF4A3040), Color(0xFFFFD9E3)),
  PlaceCategory.museum: (Color(0xFF3F3470), Color(0xFFEBDDFF)),
  PlaceCategory.park: (Color(0xFF2F4A38), Color(0xFFCDEBD3)),
  PlaceCategory.restaurant: (Color(0xFF4A3A28), Color(0xFFFFDDB8)),
};

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});

  final Leg? leg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = leg?.walkMinutes;
    final walk = minutes != null;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 30),
          Container(width: 2, height: 40, color: theme.colorScheme.outlineVariant),
          const SizedBox(width: 18),
          Icon(walk ? Icons.directions_walk : Icons.directions_transit, size: 18,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            walk ? 'Walk about $minutes min' : 'Transit or a ride',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
