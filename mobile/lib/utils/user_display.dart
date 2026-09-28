import 'package:firebase_auth/firebase_auth.dart';

String initialFor({String? displayName, String? email, bool isAnonymous = false}) {
  if (isAnonymous) return 'G';
  final name = displayName?.trim() ?? '';
  final source = name.isNotEmpty ? name : (email?.trim() ?? '');
  return source.isEmpty ? 'U' : source[0].toUpperCase();
}

String nameFor({String? displayName, String? email, bool isAnonymous = false}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;

  final address = email?.trim() ?? '';
  if (address.isNotEmpty) return address.split('@').first;

  return isAnonymous ? 'Guest' : 'User';
}

String subtitleFor({String? email, bool isAnonymous = false}) {
  final address = email?.trim() ?? '';
  if (address.isNotEmpty) return address;
  return isAnonymous ? 'Exploring a sample account' : '';
}

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
