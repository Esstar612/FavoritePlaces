import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

class SmartSearchResult {
  const SmartSearchResult({required this.matchingIds, required this.explanation});

  final List<String> matchingIds;
  final String explanation;

  factory SmartSearchResult.fromJson(Map<String, dynamic> json) => SmartSearchResult(
        matchingIds: ((json['matchingIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        explanation: json['explanation'] as String? ?? '',
      );
}

class NoteSummary {
  const NoteSummary({
    required this.whyILikedIt,
    required this.tips,
    required this.bestTimeToGo,
  });

  final String whyILikedIt;
  final String tips;
  final String bestTimeToGo;

  factory NoteSummary.fromJson(Map<String, dynamic> json) => NoteSummary(
        whyILikedIt: json['whyILikedIt'] as String? ?? '',
        tips: json['tips'] as String? ?? '',
        bestTimeToGo: json['bestTimeToGo'] as String? ?? '',
      );
}

class AIService {
  AIService();

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<NoteSummary> summarizeNotes({
    required String title,
    required String notes,
    required String category,
    required String address,
  }) async {
    final url = Uri.parse('${AppConfig.backendUrl}/ai/summarize-notes');
    final headers = await _authHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'title': title,
        'notes': notes,
        'category': category,
        'address': address,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI summarize failed: ${response.statusCode} – ${response.body}');
    }

    return NoteSummary.fromJson(jsonDecode(response.body));
  }

  Future<List<String>> suggestTags({
    String? photoUrl,
    required String title,
    required String category,
  }) async {
    final url = Uri.parse('${AppConfig.backendUrl}/ai/suggest-tags');
    final headers = await _authHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'photoUrl': ?photoUrl,
        'title': title,
        'category': category,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI suggest-tags failed: ${response.statusCode} – ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['tags'] as List?) ?? const [])
        .map((t) => t.toString())
        .where((t) => t.trim().isNotEmpty)
        .toList();
  }

  Future<SmartSearchResult> smartSearch({
    required String query,
    required List<Map<String, dynamic>> places,
  }) async {
    final url = Uri.parse('${AppConfig.backendUrl}/ai/smart-search');
    final headers = await _authHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'query': query, 'places': places}),
    );

    if (response.statusCode != 200) {
      throw Exception('AI smart-search failed: ${response.statusCode} – ${response.body}');
    }

    return SmartSearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      '${AppConfig.backendUrl}/maps/reverse-geocode?lat=$latitude&lng=$longitude',
    );
    final headers = await _authHeaders();

    final response = await http.get(url, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Reverse geocode failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final address = body['address'];
    return address is String && address.isNotEmpty ? address : null;
  }
}
