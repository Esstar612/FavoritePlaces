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

enum SortOption { recent, alphabetical, rating, category }

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

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
  bool _showFavoritesOnly = false;

  // ── AI smart-search state ────────────────────────────────────────────────
  // When non-null, the list is restricted to these ids instead of the plain
  // substring match. Cleared whenever the query text changes.
  List<String>? _aiMatchIds;
  String? _aiExplanation;
  bool _aiSearching = false;

  @override
  void initState() {
    super.initState();
    _placesFuture = ref.read(userPlacesProvider.notifier).loadPlaces();
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
    if (_showFavoritesOnly) {
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
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allPlaces = ref.watch(userPlacesProvider);
    final filteredPlaces = _getFilteredAndSortedPlaces();
    final user = ref.watch(authStateProvider).value;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Places'),
        actions: [
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
            tooltip: 'Show Favorites Only',
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.recent,
                child: Text('Sort by Recent'),
              ),
              const PopupMenuItem(
                value: SortOption.alphabetical,
                child: Text('Sort A-Z'),
              ),
              const PopupMenuItem(
                value: SortOption.rating,
                child: Text('Sort by Rating'),
              ),
              const PopupMenuItem(
                value: SortOption.category,
                child: Text('Sort by Category'),
              ),
            ],
          ),
          // Profile avatar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  avatarInitial(user),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search, or ask "somewhere quiet to work"',
                  prefixIcon: const Icon(Icons.search),
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
                            : const Icon(Icons.auto_awesome),
                        tooltip: 'Ask AI',
                        onPressed: (_aiSearching || _searchQuery.trim().isEmpty)
                            ? null
                            : _runAiSearch,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
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
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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

            // Filter Chips
            if (allPlaces.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filterCategory == null,
                      onSelected: (selected) {
                        setState(() {
                          _filterCategory = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...PlaceCategory.values.map((category) {
                      final count = allPlaces.where((p) => p.category == category).length;
                      if (count == 0) return const SizedBox.shrink();
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${category.icon} ${category.displayName} ($count)'),
                          selected: _filterCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _filterCategory = selected ? category : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 8),

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const AddPlaceScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Place'),
      ),
    );
  }
}
