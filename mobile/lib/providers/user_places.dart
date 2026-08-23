import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Completed by the next snapshot (or error). Lets callers await real data
  /// instead of returning immediately.
  Completer<void>? _pending;

  /// Call this once after the user is authenticated to start listening.
  ///
  /// Idempotent: AuthGate calls this from build() to cover cold start, so
  /// re-subscribing here would tear down and recreate the snapshot listener on
  /// every rebuild (extra reads, and the list visibly flashes).
  void startListening() {
    if (_sub != null) return;
    _sub = FirestoreService.streamPlaces().listen(
      (docs) {
        state = docs.map(Place.fromFirestore).toList();
        _settle();
      },
      onError: (e) {
        // Leave state as-is so the UI keeps showing stale data rather than
        // emptying; refresh() is how the user recovers.
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

  /// Stop listening (call on sign-out).
  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _settle();
    state = const [];
  }

  /// Tear the subscription down and rebuild it, completing once fresh data
  /// arrives.
  ///
  /// With a live snapshot listener the list is normally already current, so
  /// this exists for the case that isn't: a stream that errored stays
  /// subscribed to nothing and the list is stale forever. Pull-to-refresh is
  /// the user's way out of that.
  Future<void> refresh() async {
    _sub?.cancel();
    _sub = null;

    final pending = Completer<void>();
    _pending = pending;
    startListening();

    try {
      // Bounded so the gesture can't spin forever with no connection.
      await pending.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Refresh failed: $e');
      rethrow;
    }
  }

  /// Initial load — awaits the first snapshot so the screen can show a
  /// spinner rather than an empty list.
  Future<void> loadPlaces() => refresh();

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

    // Only once the document points at the new URLs — otherwise a failed write
    // would leave the place referencing images that no longer exist.
    if (replaced) {
      await FirestoreService.deletePhotos(
        place.photoUrls.where((u) => !urls.contains(u)),
      );
    }
  }

  // ── CACHE AI SUMMARY ────────────────────────────────────────────────────
  /// Persist a generated summary so revisiting the place doesn't re-bill a
  /// model call. The stream echoes the write back into state.
  Future<void> saveSummary(String placeId, PlaceSummary summary) async {
    await FirestoreService.saveSummary(placeId, summary.toMap());
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
