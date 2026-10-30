final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your email';
  if (v.length > 254 || !_email.hasMatch(v)) return 'Enter a valid email';
  return null;
}

/// For new passwords. The server enforces the same rules and also rejects
/// common passwords.
String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter a password';
  if (v.length < 10) return 'Use at least 10 characters';
  if (v.length > 128) return 'Password is too long';
  return null;
}

/// For signing in: only checks that something was typed, so accounts with
/// older passwords can still sign in.
String? validateSignInPassword(String? value) =>
    (value ?? '').isEmpty ? 'Enter a password' : null;

String? validateConfirmPassword(String? password, String? confirm) =>
    password == confirm ? null : 'Passwords do not match';
