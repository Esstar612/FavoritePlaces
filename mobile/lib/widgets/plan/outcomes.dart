import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/widgets/plan/common.dart';

final _compact = ButtonStyle(
  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
  iconSize: WidgetStateProperty.all(20),
);

class PlanNothingFitsView extends ConsumerWidget {
  const PlanNothingFitsView({super.key, required this.state});

  final PlanNothingFits state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(planProvider.notifier);
    final count = ref.watch(userPlacesProvider).length;
    final searches = state.result.toolCalls.where((c) => c.name == 'search_places').toList();
    final checked = {for (final call in state.result.toolCalls) ...call.resultPlaceIds}.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        PlanYouAsked(request: state.request),
        const SizedBox(height: 24),
        Icon(Icons.wrong_location_outlined, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'None of your places fit this one',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          "I checked your $count saved places and none of them fit. "
          "I'd rather tell you than send you somewhere you haven't picked.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text(
          'Your places are better for',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        PlanIdeaChips(
          ideas: planExamples,
          onSelected: (text) {
            notifier.reset();
            notifier.submit(text);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: _compact,
                onPressed: notifier.edit,
                icon: const Icon(Icons.edit, size: 18),
                label: const FittedBox(child: Text('Change request')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: _compact,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AddPlaceScreen())),
                icon: const Icon(Icons.add, size: 18),
                label: const FittedBox(child: Text('Save a place')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                child: Icon(Icons.code, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How I got this',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${searches.length} ${searches.length == 1 ? 'search' : 'searches'} · '
                      'checked $checked ${checked == 1 ? 'place' : 'places'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PlanErrorView extends ConsumerWidget {
  const PlanErrorView({super.key, required this.state});

  final PlanError state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(planProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        PlanYouAsked(request: state.request),
        const SizedBox(height: 24),
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(state.message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(onPressed: notifier.retry, child: const Text('Try again')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: notifier.reset, child: const Text('New plan')),
          ],
        ),
      ],
    );
  }
}

class PlanResultsPreview extends ConsumerWidget {
  const PlanResultsPreview({super.key, required this.state});

  final PlanResults state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = {for (final p in ref.watch(userPlacesProvider)) p.id: p};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        PlanYouAsked(request: state.request),
        const SizedBox(height: 16),
        Text(state.result.overview, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final stop in state.result.stops)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${stop.order}')),
              title: Text(places[stop.placeId]?.title ?? stop.placeId),
              subtitle: Text(stop.reason.isEmpty ? 'Your starting point' : stop.reason),
            ),
          ),
      ],
    );
  }
}
