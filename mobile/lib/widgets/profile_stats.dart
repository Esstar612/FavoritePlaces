import 'package:flutter/material.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/palette.dart';
import 'package:favorite_places/utils/place_stats.dart';

const _mixColors = [
  Color(0xFFF0B8C9),
  Color(0xFFD3BBFF),
  Color(0xFF9AD1A8),
  Color(0xFFF9C74F),
  Color(0xFF9ECAFF),
  Color(0xFFFFB68C),
  Color(0xFF80D5D0),
  Color(0xFFE6C3A0),
  Color(0xFFC5B8FF),
  Color(0xFFB7B0BF),
];

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key, required this.stats});

  final PlaceStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cap = TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: 0.3, color: scheme.onSurfaceVariant);
    final average = stats.averageRating;

    Widget stat(String value, String label, {IconData? icon, Color? iconColor}) => Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20, color: iconColor), const SizedBox(width: 4)],
                  Text(value, style: const TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: cap),
            ],
          ),
        );
    Widget small(IconData icon, String value, String label) => Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(label, style: cap),
                ],
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              stat('${stats.places}', 'Places'),
              stat('${stats.favorites}', 'Favorites', icon: Icons.favorite, iconColor: scheme.error),
              stat(
                average == null ? '–' : average.toStringAsFixed(1),
                'Avg rating',
                icon: Icons.star,
                iconColor: scheme.star,
              ),
            ],
          ),
          if (stats.mix.length > 1) ...[
            const SizedBox(height: 16),
            _Mix(mix: stats.mix),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              small(Icons.notes, '${stats.withNotes} of ${stats.places}', 'have notes'),
              small(Icons.sell_outlined, '${stats.uniqueTags}', 'unique tags'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mix extends StatelessWidget {
  const _Mix({required this.mix});

  final List<MapEntry<PlaceCategory, int>> mix;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final label = mix.map((e) => '${e.key.displayName} ${e.value}').join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your mix', style: TextStyle(fontSize: 14, color: muted)),
            Text('${mix.length} categories', style: TextStyle(fontSize: 14, color: muted)),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, entry) in mix.indexed) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(flex: entry.value, child: ColoredBox(color: _mixColors[i % _mixColors.length])),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final (i, entry) in mix.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: _mixColors[i % _mixColors.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${entry.key.displayName} ${entry.value}', style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
