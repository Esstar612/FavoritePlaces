import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/profile.dart';
import 'package:favorite_places/widgets/places_list.dart';
import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/utils/user_display.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortOption {
  recent('Recent'),
  alphabetical('A to Z'),
  rating('Rating'),
  category('Category');

  const SortOption(this.label);

  final String label;
}

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key, this.favoritesOnly = false});

  final bool favoritesOnly;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _PlacesScreenState();
  }
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  late Future<void> _placesFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  PlaceCategory? _filterCategory;
  SortOption _sortOption = SortOption.recent;

  // ── AI smart-search state ────────────────────────────────────────────────
  // When non-null, the list is restricted to these ids instead of the plain
  // substring match. Cleared whenever the query text changes.
  List<String>? _aiMatchIds;
  String? _aiExplanation;
  bool _aiSearching = false;

  @override
  void initState() {
    super.initState();
    // loadPlaces restarts the Firestore stream, so only the Places tab calls it.
    _placesFuture = widget.favoritesOnly
        ? Future.value()
        : ref.read(userPlacesProvider.notifier).loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh. Surfaces failure rather than silently spinning back.
  Future<void> _refresh() async {
    try {
      await ref.read(userPlacesProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't refresh. Check your connection.")),
      );
    }
  }

  void _clearAiSearch() {
    if (_aiMatchIds == null && _aiExplanation == null) return;
    setState(() { _aiMatchIds = null; _aiExplanation = null; });
  }

  /// Ask the backend to interpret the query against this user's places.
  /// Deliberately an explicit action — every call is a model request, so
  /// running it per keystroke would be wasteful and slow.
  Future<void> _runAiSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final places = ref.read(userPlacesProvider);
    if (places.isEmpty) return;

    setState(() { _aiSearching = true; _aiExplanation = null; });
    try {
      final result = await AIService().smartSearch(
        query: query,
        places: places.map((p) => {
          'id': p.id,
          'title': p.title,
          'category': p.category.name,
          'tags': p.tags,
          'notes': p.notes,
        }).toList(),
      );
      if (!mounted) return;
      setState(() {
        _aiMatchIds   = result.matchingIds;
        _aiExplanation = result.explanation;
        _aiSearching  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _aiSearching = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Smart search unavailable right now.')),
      );
    }
  }

  List<Place> _getFilteredAndSortedPlaces() {
    var places = ref.watch(userPlacesProvider);
    
    // Create mutable copy
    var filtered = List<Place>.from(places);
    
    // Filter by search — AI results take precedence over the substring match
    if (_aiMatchIds != null) {
      final ids = _aiMatchIds!.toSet();
      filtered = filtered.where((p) => ids.contains(p.id)).toList();
    } else if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((place) {
        final query = _searchQuery.toLowerCase();
        return place.title.toLowerCase().contains(query) ||
               place.tags.any((tag) => tag.toLowerCase().contains(query)) ||
               place.notes.toLowerCase().contains(query) ||
               place.location.address.toLowerCase().contains(query);
      }).toList();
    }
    
    // Filter by category
    if (_filterCategory != null) {
      filtered = filtered.where((p) => p.category == _filterCategory).toList();
    }
    
    // Filter favorites only
    if (widget.favoritesOnly) {
      filtered = filtered.where((p) => p.isFavorite).toList();
    }
    
    // Sort
    switch (_sortOption) {
      case SortOption.alphabetical:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.category:
        filtered.sort((a, b) => a.category.name.compareTo(b.category.name));
        break;
      case SortOption.recent:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allPlaces = ref.watch(userPlacesProvider);
    final scoped = widget.favoritesOnly ? allPlaces.where((p) => p.isFavorite).toList() : allPlaces;
    final filteredPlaces = _getFilteredAndSortedPlaces();
    final user = ref.watch(authStateProvider).value;
    
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          widget.favoritesOnly ? 'Favorites' : 'Favorite Places',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Profile',
              child: InkResponse(
                radius: 24,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  child: Text(
                    avatarInitial(user),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search or ask, like "quiet to work"',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 12),
                    child: Icon(Icons.search),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            _clearAiSearch();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      IconButton(
                        icon: _aiSearching
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Ask AI',
                        onPressed: (_aiSearching || _searchQuery.trim().isEmpty)
                            ? null
                            : _runAiSearch,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runAiSearch(),
                onChanged: (value) {
                  // A new query invalidates the previous AI result.
                  _clearAiSearch();
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // ── AI answer banner ───────────────────────────────────────────
            if (_aiExplanation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _aiExplanation!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      InkWell(
                        onTap: _clearAiSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (scoped.isNotEmpty) ...[
              _CategoryChips(
                places: scoped,
                selected: _filterCategory,
                onSelected: (category) => setState(() => _filterCategory = category),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filteredPlaces.length} ${filteredPlaces.length == 1 ? 'place' : 'places'}',
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    PopupMenuButton<SortOption>(
                      tooltip: 'Sort: ${_sortOption.label}. Change sort',
                      initialValue: _sortOption,
                      onSelected: (option) => setState(() => _sortOption = option),
                      itemBuilder: (context) => [
                        for (final option in SortOption.values)
                          PopupMenuItem(value: option, child: Text(option.label)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              _sortOption.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Places List
            Expanded(
              child: FutureBuilder(
                future: _placesFuture,
                builder: (context, snapshot) =>
                    snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : PlacesList(places: filteredPlaces),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.favoritesOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddPlaceScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add place'),
            ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.places, required this.selected, required this.onSelected});

  final List<Place> places;
  final PlaceCategory? selected;
  final ValueChanged<PlaceCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final counts = <PlaceCategory, int>{};
    for (final place in places) {
      counts.update(place.category, (n) => n + 1, ifAbsent: () => 1);
    }
    final firstSeen = counts.keys.toList();
    final ranked = [...firstSeen]..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : firstSeen.indexOf(a).compareTo(firstSeen.indexOf(b));
      });
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _chip(context, null, 'All', places.length, selected == null, () => onSelected(null)),
          for (final category in ranked) ...[
            const SizedBox(width: 8),
            _chip(
              context,
              category.icon,
              category.displayName,
              counts[category]!,
              selected == category,
              () => onSelected(selected == category ? null : category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String? emoji, String label, int count, bool on, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    final color = on ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? scheme.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: on ? scheme.secondaryContainer : scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
              child: Row(
                children: [
                  if (emoji != null) ...[
                    Text(emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                  ] else if (on) ...[
                    Icon(Icons.check, size: 18, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: on ? scheme.onSurfaceVariant : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
