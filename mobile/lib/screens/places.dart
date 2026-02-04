import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/profile.dart';
import 'package:favorite_places/widgets/places_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String _searchQuery = '';
  PlaceCategory? _filterCategory;
  SortOption _sortOption = SortOption.recent;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _placesFuture = ref.read(userPlacesProvider.notifier).loadPlaces();
  }

  List<Place> _getFilteredAndSortedPlaces() {
    var places = ref.watch(userPlacesProvider);
    
    // Create mutable copy
    var filtered = List<Place>.from(places);
    
    // Filter by search
    if (_searchQuery.isNotEmpty) {
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
                  (FirebaseAuth.instance.currentUser?.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(userPlacesProvider.notifier).loadPlaces();
        },
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search places, tags, notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
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
