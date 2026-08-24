import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Injects the Google Maps JavaScript API.
///
/// google_maps_flutter_web expects `window.google.maps` to exist before a
/// GoogleMap widget builds. Loading it from here rather than a hardcoded
/// <script> in web/index.html keeps the API key in config.dart, which is
/// gitignored — index.html is tracked, so a key placed there would be
/// committed.
Future<void> loadGoogleMapsJs(String apiKey) {
  const id = 'google-maps-js';
  // Already injected (hot restart, or a second call).
  if (web.document.getElementById(id) != null) return Future.value();

  final completer = Completer<void>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..id = id
    ..type = 'text/javascript'
    ..async = true
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey';

  script.onload = (web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }.toJS;

  script.onerror = (web.Event _) {
    // Non-fatal: the app still works, maps just won't render.
    if (!completer.isCompleted) completer.complete();
  }.toJS;

  web.document.head!.appendChild(script);

  // Don't let a hung network block startup forever.
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {},
  );
}
