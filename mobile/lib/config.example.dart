// Copy this file to `config.dart` and fill in your own values.
// `config.dart` is gitignored — it holds the keys this app ships to clients.
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // ─── Google Maps ────────────────────────────────────────────────────────
  // Two keys, because a Google API key can only carry ONE application
  // restriction and these two surfaces need different ones:
  //
  //   web    — restrict by HTTP referrer to your hosting domain.
  //            Enable: Maps JavaScript, Maps Static, Places API (New).
  //   mobile — REST calls from a phone carry no identity a key can be
  //            restricted to, so restrict this one by API only.
  //            Enable: Maps Static, Places API (New).
  //
  // Neither needs Geocoding — that runs on the backend, which holds its own
  // server-side key (see backend/.env.example).
  //
  // The native Android Maps SDK uses a third, separate key set in
  // android/app/src/main/AndroidManifest.xml, restricted to your package name
  // and signing certificate.
  static const String _webMapsKey = 'YOUR_WEB_MAPS_API_KEY';
  static const String _mobileMapsKey = 'YOUR_MOBILE_MAPS_API_KEY';

  static String get googleMapsApiKey => kIsWeb ? _webMapsKey : _mobileMapsKey;

  // ─── Backend ────────────────────────────────────────────────────────────
  // Local dev:  http://10.0.2.2:8080   (Android emulator → host machine)
  // Production: https://your-service.a.run.app
  static const String backendUrl = 'YOUR_BACKEND_URL';

  // ─── App constants ──────────────────────────────────────────────────────
  static const String appName = 'Favorite Places';

  // ─── Firestore collection names ─────────────────────────────────────────
  static const String placesCollection = 'places';
  static const String usersCollection = 'users';
}
