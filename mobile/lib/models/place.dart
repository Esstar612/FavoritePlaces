import 'dart:io';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

enum PlaceCategory {
  restaurant, cafe, park, museum, shopping,
  entertainment, hotel, bar, gym, other;

  String get displayName {
    switch (this) {
      case restaurant: return 'Restaurant';
      case cafe:       return 'Cafe';
      case park:       return 'Park';
      case museum:     return 'Museum';
      case shopping:   return 'Shopping';
      case entertainment: return 'Entertainment';
      case hotel:      return 'Hotel';
      case bar:        return 'Bar';
      case gym:        return 'Gym';
      case other:      return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case restaurant:    return '🍽️';
      case cafe:          return '☕';
      case park:          return '🌳';
      case museum:        return '🏛️';
      case shopping:      return '🛍️';
      case entertainment: return '🎭';
      case hotel:         return '🏨';
      case bar:           return '🍺';
      case gym:           return '💪';
      case other:         return '📍';
    }
  }
}

class PlaceLocation {
  const PlaceLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
  final double latitude;
  final double longitude;
  final String address;
}

class Place {
  Place({
    required this.title,
    required this.location,
    this.images    = const [],   // local File objects — only populated right after camera pick
    this.photoUrls = const [],   // Firebase Storage download URLs — persisted source of truth
    this.category  = PlaceCategory.other,
    this.tags      = const [],
    this.notes     = '',
    this.rating    = 0,
    this.isFavorite = false,
    DateTime? visitDate,
    DateTime? createdAt,
    String?   id,
  })  : id        = id ?? uuid.v4(),
        visitDate = visitDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final List<File>   images;     // transient — cleared after upload
  final List<String> photoUrls;  // persisted
  final PlaceLocation location;
  final PlaceCategory category;
  final List<String> tags;
  final String notes;
  final int    rating;
  final bool   isFavorite;
  final DateTime visitDate;
  final DateTime createdAt;

  File   get primaryImage => images.isNotEmpty ? images.first : File('');
  bool   get hasPhoto     => images.isNotEmpty || photoUrls.isNotEmpty;

  Place copyWith({
    String? title, List<File>? images, List<String>? photoUrls,
    PlaceLocation? location, PlaceCategory? category, List<String>? tags,
    String? notes, int? rating, bool? isFavorite, DateTime? visitDate,
  }) => Place(
    id: id, createdAt: createdAt,
    title:      title      ?? this.title,
    images:     images     ?? this.images,
    photoUrls:  photoUrls  ?? this.photoUrls,
    location:   location   ?? this.location,
    category:   category   ?? this.category,
    tags:       tags       ?? this.tags,
    notes:      notes      ?? this.notes,
    rating:     rating     ?? this.rating,
    isFavorite: isFavorite ?? this.isFavorite,
    visitDate:  visitDate  ?? this.visitDate,
  );

  // ── hydrate from a Firestore document map ─────────────────────────────────
  static Place fromFirestore(Map<String, dynamic> data) {
    PlaceCategory cat = PlaceCategory.other;
    try {
      final s = data['category'] as String?;
      if (s != null) cat = PlaceCategory.values.firstWhere((c) => c.name == s, orElse: () => PlaceCategory.other);
    } catch (_) {}

    DateTime? vd, ca;
    try { final v = data['visitDate'];  if (v is String) vd = DateTime.parse(v); } catch (_) {}
    try { final c = data['createdAt'];  if (c is String) ca = DateTime.parse(c); } catch (_) {}

    return Place(
      id:        data['id'] as String,
      title:     data['title'] as String,
      photoUrls: (data['photoUrls'] as List?)?.map((u) => u as String).toList() ?? [],
      location:  PlaceLocation(
        latitude:  (data['lat']  as num).toDouble(),
        longitude: (data['lng']  as num).toDouble(),
        address:   data['address'] as String,
      ),
      category:   cat,
      tags:       (data['tags'] as List?)?.map((t) => t as String).toList() ?? [],
      notes:      (data['notes'] as String?) ?? '',
      rating:     (data['rating'] as int?) ?? 0,
      isFavorite: (data['isFavorite'] as bool?) ?? false,
      visitDate:  vd,
      createdAt:  ca,
    );
  }
}
