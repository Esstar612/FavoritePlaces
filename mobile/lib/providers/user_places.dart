import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/firestore_service.dart';

class UserPlacesNotifier extends StateNotifier<List<Place>> {
  UserPlacesNotifier() : super(const []);

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  Completer<void>? _pending;

  void startListening() {
    if (_sub != null) return;
    _sub = FirestoreService.streamPlaces().listen(
      (docs) {
        state = docs.map(Place.fromFirestore).toList();
        _settle();
      },
      onError: (e) {
        debugPrint('Firestore stream error: $e');
        _settle(error: e);
      },
    );
  }

  void _settle({Object? error}) {
    final pending = _pending;
    _pending = null;
    if (pending == null || pending.isCompleted) return;
    error == null ? pending.complete() : pending.completeError(error);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _settle();
    state = const [];
  }

  Future<void> refresh() async {
    _sub?.cancel();
    _sub = null;

    final pending = Completer<void>();
    _pending = pending;
    startListening();

    try {
      await pending.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Refresh failed: $e');
      rethrow;
    }
  }

  Future<void> loadPlaces() => refresh();

  Future<void> addPlace(Place place) async {
    final urls = await FirestoreService.uploadPhotos(place.images);

    await FirestoreService.addPlace(
      id:         place.id,
      title:      place.title,
      photoUrls:  urls,
      lat:        place.location.latitude,
      lng:        place.location.longitude,
      address:    place.location.address,
      category:   place.category.name,
      tags:       place.tags,
      notes:      place.notes,
      rating:     place.rating,
      isFavorite: place.isFavorite,
      visitDate:  place.visitDate.toIso8601String(),
      createdAt:  place.createdAt.toIso8601String(),
    );
  }

  Future<void> updatePlace(Place place) async {
    final replaced = place.images.isNotEmpty;
    final urls = replaced
        ? await FirestoreService.uploadPhotos(place.images)
        : place.photoUrls;

    await FirestoreService.updatePlace(
      id:         place.id,
      title:      place.title,
      photoUrls:  urls,
      lat:        place.location.latitude,
      lng:        place.location.longitude,
      address:    place.location.address,
      category:   place.category.name,
      tags:       place.tags,
      notes:      place.notes,
      rating:     place.rating,
      isFavorite: place.isFavorite,
      visitDate:  place.visitDate.toIso8601String(),
    );

    if (replaced) {
      await FirestoreService.deletePhotos(
        place.photoUrls.where((u) => !urls.contains(u)),
      );
    }
  }

  Future<void> saveSummary(String placeId, PlaceSummary summary) async {
    await FirestoreService.saveSummary(placeId, summary.toMap());
  }

  Future<void> toggleFavorite(String placeId) async {
    final place = state.firstWhere((p) => p.id == placeId);
    final newVal = !place.isFavorite;

    state = state.map((p) => p.id == placeId ? p.copyWith(isFavorite: newVal) : p).toList();

    await FirestoreService.toggleFavorite(placeId, newVal);
  }

  Future<void> deletePlace(String placeId) async {
    state = state.where((p) => p.id != placeId).toList();
    await FirestoreService.deletePlace(placeId);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

final userPlacesProvider =
    StateNotifierProvider<UserPlacesNotifier, List<Place>>(
      (ref) => UserPlacesNotifier(),
    );
