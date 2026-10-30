import 'package:amole/features/auth/auth_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email validation', () {
    expect(validateEmail(null), 'Enter your email');
    expect(validateEmail('  '), 'Enter your email');
    expect(validateEmail('abebe'), isNotNull);
    expect(validateEmail('abebe@'), isNotNull);
    expect(validateEmail('abebe@example'), isNotNull);
    expect(validateEmail('a b@example.com'), isNotNull);
    expect(validateEmail('abebe@example.com'), isNull);
    expect(validateEmail('  abebe@example.com '), isNull);
    expect(validateEmail('${'a' * 250}@example.com'), isNotNull);
  });

  test('new passwords need 10 to 128 characters', () {
    expect(validatePassword(''), 'Enter a password');
    expect(validatePassword('short'), isNotNull);
    expect(validatePassword('123456789'), isNotNull);
    expect(validatePassword('1234567890'), isNull);
    expect(validatePassword('x' * 128), isNull);
    expect(validatePassword('x' * 129), isNotNull);
  });

  test('sign-in only needs a non-empty password', () {
    expect(validateSignInPassword(''), isNotNull);
    expect(validateSignInPassword(null), isNotNull);
    expect(validateSignInPassword('old'), isNull);
  });

  test('confirmation must match', () {
    expect(validateConfirmPassword('abc', 'abc'), isNull);
    expect(validateConfirmPassword('abc', 'abd'), 'Passwords do not match');
  });
}
