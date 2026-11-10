import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

class RoastingAiService {
  RoastingAiService({FirebaseAI? firebaseAI})
    : _firebaseAI = firebaseAI ?? FirebaseAI.googleAI();

  final FirebaseAI _firebaseAI;

  late final GenerativeModel _model = _firebaseAI.generativeModel(
    model: 'gemini-3.5-flash-lite',
    generationConfig: GenerationConfig(
      responseMimeType: 'text/plain',
      temperature: 0.8,
      maxOutputTokens: 120,
    ),
    systemInstruction: Content.system(
      'Kamu adalah Roasting AI ringan untuk aplikasi produktivitas mahasiswa. '
      'Tulis satu kalimat roasting dalam Bahasa Indonesia yang lucu, singkat, '
      'dan tidak menghina identitas, kondisi fisik, atau hal sensitif. '
      'Gunakan hanya data ringkasan yang diberikan. Jangan mengarang fakta.',
    ),
  );

  Future<String> generate({
    required int totalExpense,
    required int pendingTasks,
    required int transactionCount,
  }) async {
    final GenerateContentResponse response = await _model
        .generateContent([
          Content.text(
            'Ringkasan pengguna: pengeluaran Rp$totalExpense, '
            '$pendingTasks tugas belum selesai, dan $transactionCount '
            'transaksi tercatat. Buat satu roasting produktif.',
          ),
        ])
        .timeout(const Duration(seconds: 8));
    final String? text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const FormatException('Gemini tidak mengembalikan roasting.');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
