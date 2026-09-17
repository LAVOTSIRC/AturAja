import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class _SettingItem {
  final IconData icon;
  final String label;
  final String sub;
  const _SettingItem(this.icon, this.label, this.sub);
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem(this.icon, this.value, this.label);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const stats = [
    _StatItem(Icons.task_alt_outlined, '12', 'Tugas Selesai'),
    _StatItem(Icons.savings_outlined, '874rb', 'Total Hemat'),
    _StatItem(Icons.local_fire_department_outlined, '7 hari', 'Streak'),
  ];

  static const settings = [
    _SettingItem(Icons.notifications_none, 'Notifikasi & Roasting AI', 'Aktif'),
    _SettingItem(Icons.cloud_outlined, 'Cadangan Cloud', 'Sinkron 10 mnt lalu'),
    _SettingItem(Icons.credit_card_outlined, 'Limit Anggaran', 'Rp1.200.000/bulan'),
    _SettingItem(Icons.psychology_outlined, 'Konfigurasi NLP', 'Model Offline v2.1'),
    _SettingItem(Icons.lock_outline, 'Privasi & Keamanan', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
                    const ThemeToggleSwitch(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text('ZR', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.blue, letterSpacing: -0.5)),
                      ),
                      Text('M Zidan Ruriano A.G', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                      const SizedBox(height: 2),
                      Text('241401063 · Ilmu Komputer', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: c.tealDim, borderRadius: BorderRadius.circular(99)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Mode Luring Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.teal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: stats
                      .map((s) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Column(
                                  children: [
                                    Icon(s.icon, size: 20, color: c.blue),
                                    const SizedBox(height: 8),
                                    Text(s.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                                    const SizedBox(height: 2),
                                    Text(s.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textMuted, height: 1.3)),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Pengaturan'),
                    Column(
                      children: settings
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(item.icon, size: 19, color: c.blue),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                                            if (item.sub.isNotEmpty) ...[
                                              const SizedBox(height: 1),
                                              Text(item.sub, style: TextStyle(fontSize: 10, color: c.textMuted)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, size: 16, color: c.textMuted),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
