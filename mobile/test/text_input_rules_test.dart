import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/util/text_input_rules.dart';

TextEditingValue _apply(String text) => noEmojiFormatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
    );

void main() {
  test('strips emoji, keeps letters/digits/punctuation', () {
    expect(_apply('Kunal😀 Sharma!').text, 'Kunal Sharma!');
  });
  test('leaves plain text untouched', () {
    expect(_apply('alex.w@x.com').text, 'alex.w@x.com');
  });
  test('inputRules includes the no-emoji formatter', () {
    expect(inputRules().contains(noEmojiFormatter), isTrue);
  });
}
