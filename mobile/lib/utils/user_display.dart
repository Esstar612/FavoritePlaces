import 'package:firebase_auth/firebase_auth.dart';

/// Single letter for the avatar circle.
///
/// `??` alone is not enough here: Firebase returns an empty *string* (not null)
/// for a Google account with no name set, and for an email account whose
/// `updateDisplayName` hasn't propagated yet — and `''[0]` throws RangeError.
String avatarInitial(User? user) {
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

  return 'User';
}
