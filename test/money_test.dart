import 'package:amole/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats whole birr without decimals', () {
    expect(formatEtb(25000), 'ETB 250');
    expect(formatEtb(0), 'ETB 0');
  });

  test('formats santim with two digits', () {
    expect(formatEtb(25005), 'ETB 250.05');
    expect(formatEtb(25050), 'ETB 250.50');
  });

  test('formats negative amounts', () {
    expect(formatEtb(-150), 'ETB -1.50');
  });
}
