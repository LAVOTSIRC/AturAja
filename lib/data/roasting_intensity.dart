/// Tingkat intensitas gaya Roasting AI yang bisa dipilih pengguna.
enum RoastingIntensity {
  santai(
    label: 'Santai',
    description: 'Ramah, suportif, dan humor ringan tanpa sindiran tajam.',
    preview:
        'Pengeluaranmu mulai mendekati batas anggaran. Coba lebih bijak '
        'memilih pengeluaran agar keuanganmu tetap terjaga.',
    instruction:
        'Gaya SANTAI: gunakan bahasa yang ramah, suportif, dan humor ringan. '
        'Utamakan motivasi daripada sindiran. Jangan gunakan sarkasme yang tajam.',
  ),
  seimbang(
    label: 'Seimbang',
    description: 'Humor dan sindiran ringan yang tetap memotivasi.',
    preview:
        'Dek, anggaranmu sudah mulai menipis. Dompetmu sudah memberi '
        'peringatan. Jangan sampai saldo tinggal kenangan sebelum akhir bulan.',
    instruction:
        'Gaya SEIMBANG: gunakan humor, sindiran ringan, dan motivasi. Boleh '
        'menyentil kebiasaan buruk pengguna secara wajar, tetapi jaga '
        'keseimbangan antara candaan dan dorongan untuk memperbaiki diri.',
  ),
  pedas(
    label: 'Pedas',
    description:
        'Sarkasme tajam yang menyentil kebiasaan, bukan menyerang pribadi.',
    preview:
        'Anggaranmu hampir habis, Dek. Sepertinya tombol checkout lebih sering '
        'kamu kunjungi daripada halaman pengaturan keuangan. Saatnya berhenti!',
    instruction:
        'Gaya PEDAS: gunakan sarkasme dan sindiran yang lebih tajam, langsung, '
        'dan kreatif. Berani menyentil kebiasaan menunda pekerjaan, pengeluaran '
        'impulsif, atau kurang disiplin. Tetap berikan arahan atau motivasi, '
        'dan jangan pernah berubah menjadi penghinaan atau serangan personal.',
  );

  const RoastingIntensity({
    required this.label,
    required this.description,
    required this.preview,
    required this.instruction,
  });

  /// Nilai default aplikasi.
  static const RoastingIntensity defaultIntensity = RoastingIntensity.seimbang;

  final String label;
  final String description;
  final String preview;

  /// Panduan gaya yang dipakai pada system instruction Gemini.
  final String instruction;

  /// Membaca nilai dari penyimpanan lama maupun baru.
  ///
  /// Nilai yang tidak tersedia atau tidak dikenal akan memakai [seimbang].
  static RoastingIntensity fromStorage(Object? value) {
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      for (final RoastingIntensity intensity in values) {
        if (intensity.name == normalized) {
          return intensity;
        }
      }
    }
    return defaultIntensity;
  }
}
