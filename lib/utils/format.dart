import 'package:flutter/services.dart';

/// Formats a number as Indonesian Rupiah, e.g. 15000 -> "Rp15.000".
String formatRupiah(num value) {
  final n = value.abs().round();
  final digits = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp$buffer';
}

String formatRupiahSigned(num value) {
  final String sign = value < 0 ? '-' : '';
  return '$sign${formatRupiah(value)}';
}

/// Adds Indonesian thousands separators while preserving the cursor position.
class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final String digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final String formatted = digits.replaceAllMapped(
      RegExp(r'\d(?=(?:\d{3})+$)'),
      (Match match) => '${match[0]}.',
    );

    int offsetFor(int offset) {
      if (offset < 0) return formatted.length;
      final int digitsAfterCursor = newValue.text
          .substring(offset)
          .replaceAll(_nonDigits, '')
          .length;
      int remaining = digitsAfterCursor;
      int cursor = formatted.length;
      while (remaining > 0) {
        cursor--;
        if (formatted[cursor] != '.') remaining--;
      }
      return cursor;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: offsetFor(newValue.selection.baseOffset),
        extentOffset: offsetFor(newValue.selection.extentOffset),
      ),
    );
  }
}
