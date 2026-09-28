import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/home_shell.dart';
import 'package:favorite_places/screens/profile.dart';
import 'package:favorite_places/widgets/places_list.dart';
import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/utils/user_display.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortOption {
  recent('Recent', 'Recently added first', Icons.schedule),
  alphabetical('A to Z', 'By name', Icons.sort_by_alpha),
  rating('Rating', 'Highest first', Icons.star_outline),
  category('Category', 'Grouped, with a header for each', Icons.category_outlined);

  const SortOption(this.label, this.detail, this.icon);

  final String label;
  final String detail;
  final IconData icon;
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
  bool _favoritesFirst = false;

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

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          final scheme = Theme.of(sheetContext).colorScheme;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 16, 8),
                  child: Text('Sort by', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                ),
                RadioGroup<SortOption>(
                  groupValue: _sortOption,
                  onChanged: (option) {
                    if (option == null) return;
                    update(() => _sortOption = option);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Column(
                    children: [
                      for (final option in SortOption.values)
                        RadioListTile<SortOption>(
                          value: option,
                          tileColor: option == _sortOption ? scheme.surfaceContainerHigh : null,
                          title: Text(
                            option.label,
                            style: TextStyle(fontWeight: option == _sortOption ? FontWeight.w500 : null),
                          ),
                          subtitle: Text(option.detail),
                          secondary: Icon(
                            option.icon,
                            color: option == _sortOption ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ],
                  ),
                ),
                const Divider(indent: 24, endIndent: 24),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: const Text('Favorites first'),
                  subtitle: const Text('Keep hearted places at the top'),
                  value: _favoritesFirst,
                  onChanged: (value) => update(() => _favoritesFirst = value),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _aiMatchIds = null;
      _aiExplanation = null;
    });
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
    
    int byOption(Place a, Place b) => switch (_sortOption) {
          SortOption.alphabetical => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          SortOption.rating => b.rating.compareTo(a.rating),
          SortOption.category => a.category.displayName.compareTo(b.category.displayName),
          SortOption.recent => 0,
        };
    int byFavorite(Place a, Place b) =>
        _favoritesFirst ? (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0) : 0;
    filtered.sort((a, b) {
      final grouped = _sortOption == SortOption.category;
      final orders = grouped ? [byOption(a, b), byFavorite(a, b)] : [byFavorite(a, b), byOption(a, b)];
      for (final order in orders) {
        if (order != 0) return order;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allPlaces = ref.watch(userPlacesProvider);
    final scoped = widget.favoritesOnly ? allPlaces.where((p) => p.isFavorite).toList() : allPlaces;
    final filteredPlaces = _getFilteredAndSortedPlaces();
    final answering = _aiExplanation != null && _aiMatchIds != null;
    final scheme = Theme.of(context).colorScheme;
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
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(Icons.search, color: answering ? scheme.primary : null),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                        ),
                      if (!answering)
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: answering ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
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

            if (answering)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _AnswerCard(
                  fit: filteredPlaces.length,
                  total: scoped.length,
                  explanation: _aiExplanation!,
                  onClear: _clearSearch,
                  onPlan: () => openPlan(context, ref, draft: _searchController.text),
                ),
              ),

            if (scoped.isNotEmpty && !answering) ...[
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
                    TextButton.icon(
                      onPressed: _showSortSheet,
                      icon: const Icon(Icons.sort, size: 18),
                      label: Text(_sortOption.label),
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
                        : PlacesList(
                            places: filteredPlaces,
                            evidenceQuery: answering ? _searchController.text : null,
                            groupByCategory: _sortOption == SortOption.category,
                          ),
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

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.fit,
    required this.total,
    required this.explanation,
    required this.onClear,
    required this.onPlan,
  });

  final int fit;
  final int total;
  final String explanation;
  final VoidCallback onClear;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fit == 0
                        ? 'None of your $total places fit'
                        : '$fit of your $total ${total == 1 ? 'place fits' : 'places fit'}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.primary),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear answer and show all places',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(explanation, style: const TextStyle(fontSize: 16, height: 24 / 16)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onClear, child: const Text('Show all places')),
                  if (fit > 0) ...[
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: onPlan,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Plan with these'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
