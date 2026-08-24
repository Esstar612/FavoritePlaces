import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for the web build.
///
/// Unlike an API secret, a Firebase web config is public by design — it ships
/// inside any deployed web bundle and merely identifies the project. Access is
/// controlled by the Firestore and Storage security rules, not by hiding this.
/// It lives here, tracked, rather than in the gitignored firebase_options.dart
/// so that CI can build the web target without an extra secret.
///
/// Native platforms don't use this: Android reads google-services.json and iOS
/// reads GoogleService-Info.plist at build time.
class FirebaseWebOptions {
  static const FirebaseOptions current = FirebaseOptions(
    apiKey: 'AIzaSyDi_bW2PBhnHJEB6iWbPtXXc4vSgfGHmuw',
    appId: '1:671529202846:web:8b01033d93a944e880b78f',
    messagingSenderId: '671529202846',
    projectId: 'favorite-places-app-94adb',
    authDomain: 'favorite-places-app-94adb.firebaseapp.com',
    storageBucket: 'favorite-places-app-94adb.firebasestorage.app',
    measurementId: 'G-VD1EQ4G17F',
  );
}
