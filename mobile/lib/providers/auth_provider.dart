import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:favorite_places/services/demo_service.dart';
import 'package:favorite_places/utils/password_strength.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

final guestSeedingProvider = StateProvider<bool>((ref) => false);

final Future<void> _googleSignInReady = GoogleSignIn.instance.initialize();

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

 
Future<void> signUpWithEmail(String email, String password, String displayName) async {
  state = const AsyncValue.loading();
  try {
    final guest = FirebaseAuth.instance.currentUser;
    final credential = guest != null && guest.isAnonymous
        ? await guest.linkWithCredential(EmailAuthProvider.credential(email: email, password: password))
        : await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

    await credential.user?.updateDisplayName(displayName);
    
    await credential.user?.reload();
    
    final updatedUser = FirebaseAuth.instance.currentUser;
    
    state = const AsyncValue.data(null);

    debugPrint('Sign up successful! User: ${updatedUser?.email}');
  } on FirebaseAuthException catch (e) {
    state = AsyncValue.error(e, StackTrace.empty);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}

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

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    if (kIsWeb) {
      try {
        final guest = FirebaseAuth.instance.currentUser;
        if (guest != null && guest.isAnonymous) {
          await guest.linkWithPopup(GoogleAuthProvider());
        } else {
          await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        }
        state = const AsyncValue.data(null);
      } on FirebaseAuthException catch (e, st) {
        const cancelled = {'popup-closed-by-user', 'cancelled-popup-request', 'user-cancelled'};
        state = cancelled.contains(e.code) ? const AsyncValue.data(null) : AsyncValue.error(e, st);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
      return;
    }
    try {
      await _googleSignInReady;
      final account = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
      final guest = FirebaseAuth.instance.currentUser;
      if (guest != null && guest.isAnonymous) {
        await guest.linkWithCredential(credential);
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      state = const AsyncValue.data(null);
    } on GoogleSignInException catch (e, st) {
      state = e.code == GoogleSignInExceptionCode.canceled ? const AsyncValue.data(null) : AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> continueAsGuest() async {
    state = const AsyncValue.loading();
    _ref.read(guestSeedingProvider.notifier).state = true;
    try {
      await FirebaseAuth.instance.signInAnonymously();
      await DemoService.seed();
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.empty);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _ref.read(guestSeedingProvider.notifier).state = false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.isAnonymous) {
        try {
          await user.delete();
        } catch (_) {
        }
      }
      if (!kIsWeb) {
        await _googleSignInReady;
        await GoogleSignIn.instance.signOut();
      }
      await FirebaseAuth.instance.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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
      (ref) => AuthNotifier(ref),
    );

const _accountExistsCodes = {'email-already-in-use', 'credential-already-in-use'};

bool isAccountExistsError(Object error) =>
    error is FirebaseAuthException && _accountExistsCodes.contains(error.code);

String firebaseAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least $minPasswordLength characters.';
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
      case 'admin-restricted-operation':
        return 'Guest sign-in is not enabled for this app.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  return 'An error occurred. Please try again.';
}
