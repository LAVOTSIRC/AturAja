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
