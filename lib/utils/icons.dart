import 'package:flutter/material.dart';
import '../data/models.dart';

/// Maps a transaction to a representative outlined Material icon.
/// Falls back to a per-category icon when there's no specific keyword match.
IconData transactionIcon(TransactionItem t) {
  final label = t.label.toLowerCase();
  if (label.contains('kampus')) return Icons.account_balance_outlined;
  if (label.contains('spotify')) return Icons.music_note_outlined;
  if (label.contains('kiriman') || label.contains('orang tua')) return Icons.credit_card_outlined;
  if (label.contains('grab') || label.contains('food')) return Icons.fastfood_outlined;
  if (label.contains('kopi')) return Icons.local_cafe_outlined;

  switch (t.cat) {
    case 'food':
      return Icons.fastfood_outlined;
    case 'entertainment':
      return Icons.music_note_outlined;
    case 'income':
      return Icons.credit_card_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}
