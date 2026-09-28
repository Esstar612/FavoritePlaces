import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

class DemoService {
  static Future<bool> seed({
    http.Client? client,
    Future<String?> Function()? idToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final getToken = idToken ?? () async => FirebaseAuth.instance.currentUser?.getIdToken();
    try {
      final token = await getToken();
      if (token == null) return false;
      final post = client?.post ?? http.post;
      final response = await post(
        Uri.parse('${AppConfig.backendUrl}/user/seed-demo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint('Demo seed failed: ${response.statusCode} ${response.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Demo seed failed: $e');
      return false;
    }
  }
}
