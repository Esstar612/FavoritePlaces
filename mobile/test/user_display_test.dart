import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/utils/user_display.dart';

void main() {
  group('initialFor', () {
    test('uses the first letter of the display name', () {
      expect(initialFor(displayName: 'Nicky Jay'), 'N');
    });

    test('uppercases a lowercase name', () {
      expect(initialFor(displayName: 'nicky'), 'N');
    });

    // The bug this helper exists for: Firebase returns an empty string rather
    // than null for a Google account with no name, and ''[0] throws RangeError.
    test('falls back to the email when the display name is empty', () {
      expect(initialFor(displayName: '', email: 'someone@example.com'), 'S');
    });

    test('falls back to the email when the display name is only whitespace', () {
      expect(initialFor(displayName: '   ', email: 'someone@example.com'), 'S');
    });

    test('returns U when nothing identifies the user', () {
      expect(initialFor(), 'U');
      expect(initialFor(displayName: '', email: ''), 'U');
    });

    test('returns G for a guest regardless of other fields', () {
      expect(initialFor(isAnonymous: true), 'G');
      expect(initialFor(displayName: 'Ignored', isAnonymous: true), 'G');
    });
  });

  group('nameFor', () {
    test('prefers the display name', () {
      expect(nameFor(displayName: 'Nicky Jay', email: 'n@example.com'), 'Nicky Jay');
    });

    test('falls back to the email local-part', () {
      expect(nameFor(displayName: '', email: 'nicky@example.com'), 'nicky');
    });

    test('names a guest Guest, and everyone else User', () {
      expect(nameFor(isAnonymous: true), 'Guest');
      expect(nameFor(), 'User');
    });
  });

  group('subtitleFor', () {
    test('shows the email when there is one', () {
      expect(subtitleFor(email: 'a@b.com'), 'a@b.com');
    });

    test('explains the session for a guest instead of leaving it blank', () {
      expect(subtitleFor(isAnonymous: true), 'Exploring a sample account');
    });

    test('is empty when there is nothing to say', () {
      expect(subtitleFor(), '');
    });
  });
}
