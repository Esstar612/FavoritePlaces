const minPasswordLength = 8;

enum PasswordStrength {
  tooShort('Too short'),
  weak('Weak'),
  fair('Fair'),
  good('Good'),
  strong('Strong');

  const PasswordStrength(this.label);
  final String label;

  int get segments => index;

  bool get allowsSignUp => this != tooShort;
}

PasswordStrength passwordStrength(String password) {
  if (password.length < minPasswordLength) return PasswordStrength.tooShort;
  var score = 1;
  if (password.contains(RegExp('[a-z]')) && password.contains(RegExp('[A-Z]'))) score++;
  if (password.contains(RegExp(r'\d'))) score++;
  if (password.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
  return PasswordStrength.values[score];
}
