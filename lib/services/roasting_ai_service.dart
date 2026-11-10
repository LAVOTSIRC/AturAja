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
      maxOutputTokens: 220,
    ),
    systemInstruction: Content.system(
      'Kamu adalah Roasting AI ringan untuk aplikasi produktivitas mahasiswa. '
      'Tulis 2 sampai 3 kalimat roasting dalam Bahasa Indonesia yang lucu, '
      'tegas, dan menyentil kebiasaan menunda. Boleh memakai sapaan "dek", '
      'tetapi jangan menghina identitas, kondisi fisik, keluarga, atau hal sensitif. '
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
            'transaksi tercatat. Buat roasting 2 sampai 3 kalimat yang '
            'menusuk kebiasaan menunda tetapi tetap memotivasi.',
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
