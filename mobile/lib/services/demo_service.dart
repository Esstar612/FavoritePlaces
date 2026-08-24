import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

/// Populates a brand-new guest account with sample places.
class DemoService {
  /// Asks the backend to seed the signed-in account.
  ///
  /// The backend is idempotent — it refuses if the account already has places
  /// — so calling this on every guest sign-in is safe. Failure is non-fatal:
  /// the guest just lands on an empty list.
  static Future<bool> seed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/user/seed-demo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
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
