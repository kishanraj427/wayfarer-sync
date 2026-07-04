import 'package:flutter/services.dart';

// Emoji / pictograph / regional-indicator / ZWJ / variation-selector ranges.
// Named (not inline) per the no-hardcode rule; lowerCamel to satisfy the Dart
// `constant_identifier_names` lint.
final RegExp _emojiRegExp = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}'
  r'\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}\u{20E3}\u{2122}\u{2139}]',
  unicode: true,
);

class _NoEmojiFormatter extends TextInputFormatter {
  const _NoEmojiFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!_emojiRegExp.hasMatch(newValue.text)) return newValue;
    final cleaned = newValue.text.replaceAll(_emojiRegExp, '');
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// Blocks emoji so nothing that can crash the backend/DB reaches a request body.
const TextInputFormatter noEmojiFormatter = _NoEmojiFormatter();

/// Baseline formatters every text input opts into, plus any screen-specific extras.
List<TextInputFormatter> inputRules([List<TextInputFormatter>? extra]) =>
    [noEmojiFormatter, ...?extra];
