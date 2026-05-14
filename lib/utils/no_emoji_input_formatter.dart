import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

/// Removes emoji and related pictographic / modifier sequences from text input.
///
/// Uses grapheme clusters so multi-codepoint emoji (e.g. skin tone, ZWJ) are
/// removed as a unit. Safe for name and plain-text fields.
class NoEmojiInputFormatter extends TextInputFormatter {
  const NoEmojiInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final filtered = _stripEmojis(newValue.text);
    if (filtered == newValue.text) return newValue;

    final sel = newValue.selection;
    int newOffset;
    if (sel.isValid) {
      final end = sel.end.clamp(0, newValue.text.length);
      newOffset = _stripEmojis(newValue.text.substring(0, end)).length;
    } else {
      newOffset = filtered.length;
    }
    newOffset = newOffset.clamp(0, filtered.length);

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  static String _stripEmojis(String input) {
    final out = StringBuffer();
    for (final g in input.characters) {
      if (!_graphemeIsEmojiLike(g)) out.write(g);
    }
    return out.toString();
  }

  /// True if this user-perceived character is emoji / pictographic / flag piece.
  static bool _graphemeIsEmojiLike(String g) {
    for (final r in g.runes) {
      if (_runeIsEmojiOrEmojiRelated(r)) return true;
    }
    return false;
  }

  static bool _runeIsEmojiOrEmojiRelated(int r) {
    // ZWJ and variation selectors (emoji composition)
    if (r == 0x200D || r == 0xFE0F) return true;
    // Skin tone modifiers
    if (r >= 0x1F3FB && r <= 0x1F3FF) return true;
    // Regional indicator symbols (flags)
    if (r >= 0x1F1E6 && r <= 0x1F1FF) return true;
    // Tags (subdivision flags)
    if (r >= 0xE0020 && r <= 0xE007F) return true;
    // Misc symbols & dingbats (common emoji blocks)
    if (r >= 0x2600 && r <= 0x26FF) return true;
    if (r >= 0x2700 && r <= 0x27BF) return true;
    // Emoticons
    if (r >= 0x1F600 && r <= 0x1F64F) return true;
    // Transport & map
    if (r >= 0x1F680 && r <= 0x1F6FF) return true;
    // Misc symbols & pictographs, supplemental symbols
    if (r >= 0x1F300 && r <= 0x1F5FF) return true;
    if (r >= 0x1F900 && r <= 0x1FAFF) return true;
    // Chess/checker symbols etc. often used as emoji
    if (r >= 0x1F000 && r <= 0x1F02F) return true;
    return false;
  }
}

/// Use on [CustomTextField] / [PasswordTextField] `inputFormatters`.
const List<TextInputFormatter> kNoEmojiInputFormatters = [NoEmojiInputFormatter()];
