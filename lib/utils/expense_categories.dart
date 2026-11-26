const Map<String, String> expenseCategoryKeys = {
  'Makan & Minum': 'food',
  'Hiburan': 'entertainment',
  'Transport': 'transport',
  'Belanja': 'belanja',
  'Lainnya': 'other',
};

String receiptExpenseCategory(String name, {String? suggestedKey}) {
  if (expenseCategoryKeys.containsValue(suggestedKey)) return suggestedKey!;
  final String item = name.toLowerCase();
  if (RegExp(r'\b(pajak|ppn|pb1|service|layanan|tip|diskon|potongan|voucher)\b')
      .hasMatch(item)) {
    return 'other';
  }
  if (RegExp(r'\b(parkir|tol|bensin|pertalite|pertamax|solar|tiket kereta)\b')
      .hasMatch(item)) {
    return 'transport';
  }
  if (RegExp(r'\b(bioskop|konser|game|karaoke|spotify)\b').hasMatch(item)) {
    return 'entertainment';
  }
  if (RegExp(
    r'\b(nasi|ayam|mie|mi|kopi|teh|susu|roti|gula|beras|telur|minyak goreng|'
    r'jus|air mineral|aqua|snack|biskuit|cokelat|yogurt|cimory|frestea|indomie|'
    r'makan|minum|sambal|bakso|soto|gorengan|es krim|keju|buah|sayur)\b',
  ).hasMatch(item)) {
    return 'food';
  }
  return 'belanja';
}
