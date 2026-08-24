import 'package:firebase_auth/firebase_auth.dart';

/// Single letter for the avatar circle.
///
/// `??` alone is not enough here: Firebase returns an empty *string* (not null)
/// for a Google account with no name set, and for an email account whose
/// `updateDisplayName` hasn't propagated yet — and `''[0]` throws RangeError.
String avatarInitial(User? user) {
  // Anonymous accounts have neither a name nor an email by definition.
  if (user?.isAnonymous ?? false) return 'G';
  final name = user?.displayName?.trim() ?? '';
  final source = name.isNotEmpty ? name : (user?.email?.trim() ?? '');
  return source.isEmpty ? 'U' : source[0].toUpperCase();
}

/// Display name falling back to the email local-part, then a generic label.
String displayNameOrFallback(User? user) {
  final name = user?.displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;

  final email = user?.email?.trim() ?? '';
  if (email.isNotEmpty) return email.split('@').first;

  return (user?.isAnonymous ?? false) ? 'Guest' : 'User';
}

/// Subtitle under the name. Guests have no email to show, so explain what
/// their session is instead of leaving a blank line.
String accountSubtitle(User? user) {
  final email = user?.email?.trim() ?? '';
  if (email.isNotEmpty) return email;
  return (user?.isAnonymous ?? false)
      ? 'Exploring a sample account'
      : '';
}
