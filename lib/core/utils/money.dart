/// Formats an amount stored in santim (1 birr = 100 santim) for display.
/// Money is always stored as integers to avoid floating-point errors.
String formatEtb(int santim) {
  final negative = santim < 0;
  final abs = santim.abs();
  final birr = abs ~/ 100;
  final rem = abs % 100;
  final body = rem == 0 ? '$birr' : '$birr.${rem.toString().padLeft(2, '0')}';
  return 'ETB ${negative ? '-' : ''}$body';
}
