import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/widgets/plan/compose.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planProvider);
    final count = ref.watch(userPlacesProvider).length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plan an outing',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            Text('From your $count saved places', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (state is! PlanIdle && state is! PlanThinking)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Start a new plan',
              onPressed: ref.read(planProvider.notifier).reset,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          PlanIdle() => PlanCompose(key: ValueKey(state), state: state),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}
