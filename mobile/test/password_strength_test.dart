import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/utils/password_strength.dart';

void main() {
  test('under 8 characters is too short and blocks sign-up', () {
    final strength = passwordStrength('abc1234');
    expect(strength, PasswordStrength.tooShort);
    expect(strength.allowsSignUp, isFalse);
    expect(strength.segments, 0);
  });

  test('scores length, mixed case, digit and symbol', () {
    expect(passwordStrength('abcdefgh'), PasswordStrength.weak);
    expect(passwordStrength('abcdEFGH'), PasswordStrength.fair);
    expect(passwordStrength('abcdEFG1'), PasswordStrength.good);
    expect(passwordStrength('abcdEF1!'), PasswordStrength.strong);
    expect(passwordStrength('12345678!'), PasswordStrength.good);
  });

  test('every scored password allows sign-up', () {
    expect(passwordStrength('abcdefgh').allowsSignUp, isTrue);
    expect(passwordStrength('abcdEF1!').segments, 4);
  });
}
