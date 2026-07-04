import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/util/name_monogram.dart';

void main() {
  test('uses first + last initials', () {
    expect(nameMonogram(firstName: 'Kunal', lastName: 'Sharma', email: 'k@x.com'), 'KS');
  });
  test('single name falls back to its initial', () {
    expect(nameMonogram(firstName: 'Kunal', lastName: '', email: 'k@x.com'), 'K');
  });
  test('no name falls back to email first+middle', () {
    expect(nameMonogram(firstName: null, lastName: null, email: 'kunal@essentia.dev'), 'KN');
  });
  test('empty local part yields ?', () {
    expect(nameMonogram(firstName: '', lastName: '', email: '@x.com'), '?');
  });
}
