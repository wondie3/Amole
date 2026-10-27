import 'package:flutter/material.dart';

/// Amole brand tokens.
///
/// Contrast notes (approximate, WCAG ratios):
/// - cream on forest is about 6.5:1 (good for buttons and text).
/// - white or forest text on [orange] is too low for small text, so orange is
///   an accent for icons, indicators and large shapes only.
/// - [orangeDeep] on cream is about 4.7:1 and is safe for small orange text.
abstract final class AppColors {
  static const Color orange = Color(0xFFE56B35);
  static const Color orangeDeep = Color(0xFFB8481C);
  static const Color forest = Color(0xFF263D32);
  static const Color cream = Color(0xFFF7F0E6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E2A24);
  static const Color textSecondary = Color(0xFF5B665F);
  static const Color outline = Color(0xFFE3D9CA);
  static const Color error = Color(0xFFB3261E);
}
