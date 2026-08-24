import 'package:firebase_auth/firebase_auth.dart';

// ─── Pure helpers ──────────────────────────────────────────────────────────
// The logic lives here, free of FirebaseAuth, so it can be exercised directly
// in tests. The User-taking wrappers below are the thin adapters the UI uses.

/// Single letter for the avatar circle.
///
/// `??` alone is not enough: Firebase returns an empty *string* (not null) for
/// a Google account with no name set, and for an email account whose
/// `updateDisplayName` hasn't propagated yet — and `''[0]` throws RangeError.
String initialFor({String? displayName, String? email, bool isAnonymous = false}) {
  // Anonymous accounts have neither a name nor an email by definition.
  if (isAnonymous) return 'G';
  final name = displayName?.trim() ?? '';
  final source = name.isNotEmpty ? name : (email?.trim() ?? '');
  return source.isEmpty ? 'U' : source[0].toUpperCase();
}

/// Display name falling back to the email local-part, then a generic label.
String nameFor({String? displayName, String? email, bool isAnonymous = false}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;

  final address = email?.trim() ?? '';
  if (address.isNotEmpty) return address.split('@').first;

  return isAnonymous ? 'Guest' : 'User';
}

/// Subtitle under the name. Guests have no email to show, so explain what
/// their session is instead of leaving a blank line.
String subtitleFor({String? email, bool isAnonymous = false}) {
  final address = email?.trim() ?? '';
  if (address.isNotEmpty) return address;
  return isAnonymous ? 'Exploring a sample account' : '';
}

// ─── FirebaseAuth adapters ─────────────────────────────────────────────────

String avatarInitial(User? user) => initialFor(
      displayName: user?.displayName,
      email: user?.email,
      isAnonymous: user?.isAnonymous ?? false,
    );

String displayNameOrFallback(User? user) => nameFor(
      displayName: user?.displayName,
      email: user?.email,
      isAnonymous: user?.isAnonymous ?? false,
    );

String accountSubtitle(User? user) => subtitleFor(
      email: user?.email,
      isAnonymous: user?.isAnonymous ?? false,
    );
