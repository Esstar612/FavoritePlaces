import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─── Stream provider: re-emits the current User (or null) ───────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── Notifier: exposes sign-in / sign-up / sign-out actions ─────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  // ── Email / Password sign-up ─────────────────────────────────────────────
// ── Email / Password sign-up ─────────────────────────────────────────────
Future<void> signUpWithEmail(String email, String password, String displayName) async {
  state = const AsyncValue.loading();
  try {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    // Set the display name on the new user
    await credential.user?.updateDisplayName(displayName);
    await credential.user?.reload();

    state = const AsyncValue.data(null);
    
    // User is now automatically signed in!
    // AuthGate will detect the auth state change and navigate to PlacesScreen
  } on FirebaseAuthException catch (e) {
    state = AsyncValue.error(e, StackTrace.empty);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}

  // ── Email / Password sign-in ─────────────────────────────────────────────
  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.empty);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled
        state = const AsyncValue.data(null);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Sign-out (works for both providers) ──────────────────────────────────
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Password reset ───────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
      (ref) => AuthNotifier(),
    );

// ─── Convenience: human-readable Firebase error messages ────────────────────
String firebaseAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      case 'requires-recent-login':
        return 'Please log out and log back in to perform this action.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'invalid-verification-id':
        return 'Invalid verification ID.';
      default:
        // For any unhandled errors, show a friendly generic message
        return 'Sign in failed. Please check your email and password.';
    }
  }
  return 'An error occurred. Please try again.';
}
