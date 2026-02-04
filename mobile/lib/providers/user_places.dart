import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/firestore_service.dart';

/// Notifier that keeps the in-memory place list in sync with Firestore.
///
/// * On construction it subscribes to the Firestore stream for the current user.
/// * Every CRUD method writes to Firestore first; the stream subscription
///   automatically pushes the updated list back into state.
class UserPlacesNotifier extends StateNotifier<List<Place>> {
  UserPlacesNotifier() : super(const []);

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  /// Call this once after the user is authenticated to start listening.
  void startListening() {
    _sub?.cancel();
    _sub = FirestoreService.streamPlaces().listen(
      (docs) {
        state = docs.map(Place.fromFirestore).toList();
      },
      onError: (e) {
        // Stream errored — leave state as-is; UI can show stale data
        print('Firestore stream error: $e');
      },
    );
  }

  /// Stop listening (call on sign-out).
  void stopListening() {
    _sub?.cancel();
    _sub = null;
    state = const [];
  }

  // ── no-op shim so PlacesScreen.initState doesn't break ─────────────────
  Future<void> loadPlaces() async {
    // Firestore stream handles this automatically after startListening().
  }

  // ── CREATE ──────────────────────────────────────────────────────────────
  Future<void> addPlace(Place place) async {
    // 1. Upload any local images
    final urls = await FirestoreService.uploadPhotos(place.images);

    // 2. Write the document
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
    // Stream will fire and update state automatically.
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────
  Future<void> updatePlace(Place place) async {
    // If the caller swapped in new local images, upload them; otherwise keep existing URLs
    final urls = place.images.isNotEmpty
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
  }

  // ── TOGGLE FAVORITE ─────────────────────────────────────────────────────
  Future<void> toggleFavorite(String placeId) async {
    final place = state.firstWhere((p) => p.id == placeId);
    final newVal = !place.isFavorite;

    // Optimistic local update so the UI flips instantly
    state = state.map((p) => p.id == placeId ? p.copyWith(isFavorite: newVal) : p).toList();

    // Persist to Firestore (stream will eventually confirm)
    await FirestoreService.toggleFavorite(placeId, newVal);
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  Future<void> deletePlace(String placeId) async {
    // Optimistic
    state = state.where((p) => p.id != placeId).toList();
    // Persist
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
