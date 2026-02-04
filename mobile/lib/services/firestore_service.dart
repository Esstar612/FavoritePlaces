import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Low-level Firestore + Storage operations.
/// All methods are scoped to the currently-signed-in user.
class FirestoreService {
  // ── helpers ──────────────────────────────────────────────────────────────
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Root 'places' collection (documents are keyed by place ID).
  static CollectionReference<Map<String, dynamic>> get _places =>
      FirebaseFirestore.instance.collection('places');

  // ── UPLOAD ───────────────────────────────────────────────────────────────
  /// Upload a single image → return its download URL.
  static Future<String> uploadPhoto(File image) async {
    final ref = FirebaseStorage.instance
        .ref('users/$_uid/photos/${_uuid.v4()}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  /// Upload every image in the list → return all URLs.
  static Future<List<String>> uploadPhotos(List<File> images) async {
    final urls = <String>[];
    for (final img in images) {
      urls.add(await uploadPhoto(img));
    }
    return urls;
  }

  // ── CREATE ───────────────────────────────────────────────────────────────
  /// Write a brand-new place document.  `photoUrls` must already be uploaded.
  static Future<void> addPlace({
    required String id,
    required String title,
    required List<String> photoUrls,
    required double lat,
    required double lng,
    required String address,
    required String category,
    required List<String> tags,
    required String notes,
    required int rating,
    required bool isFavorite,
    required String visitDate,
    required String createdAt,
  }) async {
    await _places.doc(id).set({
      'userId':    _uid,
      'title':      title,
      'photoUrls':  photoUrls,
      'lat':        lat,
      'lng':        lng,
      'address':    address,
      'category':   category,
      'tags':       tags,
      'notes':      notes,
      'rating':     rating,
      'isFavorite': isFavorite,
      'visitDate':  visitDate,
      'createdAt':  createdAt,
    });
  }

  // ── STREAM (real-time list for current user) ────────────────────────────
  static Stream<List<Map<String, dynamic>>> streamPlaces() {
    return _places
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              d['id'] = doc.id;
              return d;
            }).toList());
  }

  // ── UPDATE ───────────────────────────────────────────────────────────────
  static Future<void> updatePlace({
    required String id,
    required String title,
    required List<String> photoUrls,
    required double lat,
    required double lng,
    required String address,
    required String category,
    required List<String> tags,
    required String notes,
    required int rating,
    required bool isFavorite,
    required String visitDate,
  }) async {
    await _places.doc(id).update({
      'title':      title,
      'photoUrls':  photoUrls,
      'lat':        lat,
      'lng':        lng,
      'address':    address,
      'category':   category,
      'tags':       tags,
      'notes':      notes,
      'rating':     rating,
      'isFavorite': isFavorite,
      'visitDate':  visitDate,
    });
  }

  // ── TOGGLE FAVORITE (single-field update, cheap) ────────────────────────
  static Future<void> toggleFavorite(String id, bool value) async {
    await _places.doc(id).update({'isFavorite': value});
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  /// Delete the document AND its photos from Storage.
  static Future<void> deletePlace(String id) async {
    // Best-effort: delete photos first
    try {
      final doc = await _places.doc(id).get();
      for (final url in (doc.data()?['photoUrls'] as List?) ?? []) {
        try {
          await FirebaseStorage.instance.refFromURL(url as String).delete();
        } catch (_) {}
      }
    } catch (_) {}

    await _places.doc(id).delete();
  }

  // ── EXPORT (one-shot fetch of all user data) ────────────────────────────
  static Future<List<Map<String, dynamic>>> exportAllPlaces() async {
    final snap = await _places.where('userId', isEqualTo: _uid).get();
    return snap.docs.map((doc) {
      final d = doc.data();
      d['id'] = doc.id;
      return d;
    }).toList();
  }
}
