import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

// Injected from Dart rather than web/index.html so the key stays in the gitignored config.dart.
Future<void> loadGoogleMapsJs(String apiKey) {
  const id = 'google-maps-js';
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
    if (!completer.isCompleted) completer.complete();
  }.toJS;

  web.document.head!.appendChild(script);

  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {},
  );
}
