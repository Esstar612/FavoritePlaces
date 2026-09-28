import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';

const planExamples = [
  (Icons.local_cafe, 'Coffee then a walk with a view'),
  (Icons.star, 'A memorable evening'),
  (Icons.laptop, 'Somewhere quiet to work'),
  (Icons.museum, 'Rainy day, indoors'),
];

class PlanIdeaChips extends StatelessWidget {
  const PlanIdeaChips({super.key, required this.ideas, required this.onSelected});

  final List<(IconData, String)> ideas;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in ideas)
          ActionChip(
            avatar: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: () => onSelected(label),
          ),
      ],
    );
  }
}

class PlanYouAsked extends ConsumerWidget {
  const PlanYouAsked({super.key, required this.request, this.editable = true});

  final PlanRequest request;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final start = request.startPlaceId == null
        ? null
        : ref.watch(userPlacesProvider).where((p) => p.id == request.startPlaceId).firstOrNull;
    final asked = request.askedText ?? 'Plan from ${start?.title ?? 'your starting place'}';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, editable ? 4 : 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You asked',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(asked, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit request',
              onPressed: ref.read(planProvider.notifier).edit,
            ),
        ],
      ),
    );
  }
}

IconData categoryIcon(PlaceCategory category) => switch (category) {
      PlaceCategory.restaurant => Icons.restaurant,
      PlaceCategory.cafe => Icons.local_cafe,
      PlaceCategory.park => Icons.park,
      PlaceCategory.museum => Icons.museum,
      PlaceCategory.shopping => Icons.shopping_bag,
      PlaceCategory.entertainment => Icons.theater_comedy,
      PlaceCategory.hotel => Icons.hotel,
      PlaceCategory.bar => Icons.local_bar,
      PlaceCategory.gym => Icons.fitness_center,
      PlaceCategory.other => Icons.place,
    };
