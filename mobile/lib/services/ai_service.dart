import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

/// Result of POST /ai/summarize-notes
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

  // ─── shared: attach Firebase ID token as Bearer header ────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── POST /ai/summarize-notes ─────────────────────────────────────────────
  /// Sends the raw notes text; backend returns structured summary.
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

  // ─── POST /ai/suggest-tags ────────────────────────────────────────────────
  /// Sends a photoUrl (already uploaded to Firebase Storage);
  /// backend returns a list of suggested tag strings.
  Future<List<String>> suggestTags({
    required String photoUrl,
    required String title,
    required String category,
  }) async {
    final url = Uri.parse('${AppConfig.backendUrl}/ai/suggest-tags');
    final headers = await _authHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'photoUrl': photoUrl,
        'title': title,
        'category': category,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI suggest-tags failed: ${response.statusCode} – ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['tags'] as List).map((t) => t as String).toList();
  }
}
