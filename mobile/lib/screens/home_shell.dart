import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/home_tab.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/screens/places.dart';
import 'package:favorite_places/screens/plan.dart';

void openPlan(BuildContext context, WidgetRef ref, {String draft = '', String? startPlaceId}) {
  ref.read(planProvider.notifier).compose(draft, startPlaceId: startPlaceId);
  ref.read(homeTabProvider.notifier).state = HomeTab.plan;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const [
          PlacesScreen(),
          PlanScreen(),
          PlacesScreen(favoritesOnly: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (index) =>
            ref.read(homeTabProvider.notifier).state = HomeTab.values[index],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Places',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
