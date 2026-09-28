import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class FirestoreService {
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> get _places =>
      FirebaseFirestore.instance.collection('places');

  static Future<String> uploadPhoto(XFile image) async {
    final ref = FirebaseStorage.instance
        .ref('users/$_uid/photos/${_uuid.v4()}.jpg');
    await ref.putData(
      await image.readAsBytes(),
      SettableMetadata(contentType: image.mimeType ?? 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  static Future<List<String>> uploadPhotos(List<XFile> images) async {
    final urls = <String>[];
    for (final img in images) {
      urls.add(await uploadPhoto(img));
    }
    return urls;
  }

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

  static Future<void> saveSummary(String id, Map<String, dynamic> summary) async {
    await _places.doc(id).update({'summary': summary});
  }

  static Future<void> toggleFavorite(String id, bool value) async {
    await _places.doc(id).update({'isFavorite': value});
  }

  static Future<void> deletePhotos(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {
      }
    }
  }

  static Future<void> deletePlace(String id) async {
    try {
      final doc = await _places.doc(id).get();
      await deletePhotos(
        ((doc.data()?['photoUrls'] as List?) ?? const []).map((u) => u as String),
      );
    } catch (_) {}

    await _places.doc(id).delete();
  }

  static Future<int> deleteSamplePlaces({FirebaseFirestore? db, String? uid}) async {
    final store = db ?? FirebaseFirestore.instance;
    final snap = await store
        .collection('places')
        .where('userId', isEqualTo: uid ?? _uid)
        .where('isSample', isEqualTo: true)
        .get();
    final batch = store.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  static Future<List<Map<String, dynamic>>> exportAllPlaces() async {
    final snap = await _places.where('userId', isEqualTo: _uid).get();
    return snap.docs.map((doc) {
      final d = doc.data();
      d['id'] = doc.id;
      return d;
    }).toList();
  }
}
