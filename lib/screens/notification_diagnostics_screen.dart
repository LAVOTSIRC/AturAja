import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/roasting_intensity.dart';
import '../data/roasting_notification.dart';
import '../providers/app_provider.dart';
import '../services/local_notification_service.dart';
import '../services/notification_diag_log.dart';
import '../services/notification_ids.dart';
import '../services/roasting_ai_service.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

/// Halaman Notification Diagnostics untuk pengujian dan pemantauan sistem
/// notifikasi secara langsung pada perangkat Android.
///
/// Hanya aktif dan dapat digunakan pada mode debug ([kDebugMode]).
class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends State<NotificationDiagnosticsScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  // Status sistem
  bool? _isInitialized;
  bool? _notificationsEnabled;
  bool? _canExactAlarms;
  List<AndroidNotificationChannel>? _channels;
  List<PendingNotificationRequest> _pendingRequests = <PendingNotificationRequest>[];

  // Roasting AI testing state
  RoastingIntensity _testIntensity = RoastingIntensity.seimbang;
  String? _generatedRoastText;
  bool? _lastGeneratedByAi;
  bool _isGenerating = false;

  // Debug Budget alert state
  int? _debugBudgetThresholdSent;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  LocalNotificationService? _getService(BuildContext context) {
    final AppNotificationService? service =
        context.read<AppProvider>().notifications;
    if (service is LocalNotificationService) {
      return service;
    }
    return null;
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
    });

    final LocalNotificationService? service = _getService(context);
    if (service != null) {
      _isInitialized = service.isInitialized;
      _notificationsEnabled = await service.areNotificationsEnabled();
      _canExactAlarms = await service.canScheduleExactNotifications();
      _channels = await service.getNotificationChannels();
      _pendingRequests = await service.getPendingNotificationRequests();
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _debugBudgetThresholdSent = prefs.getInt('debug_budget_alert_threshold');

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _isError = isError;
    });
  }

  // --- ACTIONS ---

  Future<void> _requestNotificationPermission() async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;
    final bool granted = await service.requestPermissions();
    _setMessage(granted ? 'Izin notifikasi diberikan.' : 'Izin notifikasi ditolak.');
    await _refreshStatus();
  }

  Future<void> _requestExactAlarmPermission() async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;
    final bool alreadyGranted = await service.requestExactAlarmPermissionIfNeeded();
    if (alreadyGranted) {
      _setMessage('Izin exact alarm sudah aktif.');
    } else {
      _setMessage('Membuka pengaturan Android untuk izin exact alarm...');
    }
    await _refreshStatus();
  }

  Future<void> _testImmediateNotification() async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;
    final int notifId = stableNotificationId('debug:immediate_test');
    try {
      await service.showTestNotification(
        id: notifId,
        title: 'Test Notifikasi AturAja',
        body: 'Notifikasi langsung berhasil ditampilkan! ✓',
        payload: 'debug:immediate',
      );
      _setMessage('✓ Notifikasi langsung ID $notifId berhasil dikirim.');
    } catch (e) {
      _setMessage('Gagal mengirim notifikasi langsung: $e', isError: true);
    }
    await _refreshStatus();
  }

  Future<void> _testScheduleDeadline() async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;

    final DateTime now = DateTime.now();
    // Task due in 7 minutes: with the 5-minute rule, reminder is scheduled 2 minutes from now.
    final DateTime dueDate = now.add(const Duration(minutes: 7));
    final TaskItem debugTask = TaskItem(
      id: '__debug_deadline__',
      title: 'Test Deadline AturAja',
      done: false,
      dueDate: dueDate,
      deadline: '7 menit lagi',
    );

    final DateTime? reminderTime =
        LocalNotificationService.reminderTimeFor(debugTask, now);
    final int notifId = taskNotificationId(debugTask.id);

    try {
      await service.scheduleTaskReminder(debugTask);
      _setMessage(
        '✓ Test deadline dijadwalkan!\n'
        'Deadline: ${dueDate.hour}:${dueDate.minute.toString().padLeft(2, '0')}\n'
        'Waktu Pengingat: ${reminderTime != null ? "${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}:${reminderTime.second.toString().padLeft(2, '0')}" : "-"}\n'
        'Notif ID: $notifId',
      );
    } catch (e) {
      _setMessage('Gagal menjadwalkan test deadline: $e', isError: true);
    }
    await _refreshStatus();
  }

  Future<void> _cancelTestDeadline() async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;
    try {
      await service.cancelTaskReminder('__debug_deadline__');
      _setMessage('✓ Test deadline dibatalkan.');
    } catch (e) {
      _setMessage('Gagal membatalkan test deadline: $e', isError: true);
    }
    await _refreshStatus();
  }

  Future<void> _testBudgetAlert({required int threshold, required int spent, required int limit}) async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const String debugKey = 'debug_budget_alert_threshold';
    final int prevThreshold = prefs.getInt(debugKey) ?? 0;

    if (prevThreshold >= threshold) {
      _setMessage(
        'Ambang $threshold% sudah pernah dikirim sebelumnya (penanda debug: $prevThreshold%). '
        'Tekan "Reset Penanda Debug" jika ingin menguji ulang.',
        isError: true,
      );
      return;
    }

    final int notifId = stableNotificationId('debug:budget:$threshold');
    final String title = threshold >= 100
        ? 'Limit anggaran tercapai (Debug)'
        : 'Budget alert 80% (Debug)';
    final String body = threshold >= 100
        ? 'Pengeluaran Rp$spent telah mencapai limit Rp$limit.'
        : 'Pengeluaran Rp$spent telah mencapai 80% dari limit Rp$limit.';

    try {
      await service.showBudgetAlert(
        id: notifId,
        title: title,
        body: body,
      );
      await prefs.setInt(debugKey, threshold);
      _setMessage('✓ Budget Alert $threshold% berhasil dikirim (ID: $notifId).');
    } catch (e) {
      _setMessage('Gagal mengirim Budget Alert $threshold%: $e', isError: true);
    }
    await _refreshStatus();
  }

  Future<void> _resetDebugBudgetMarkers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('debug_budget_alert_threshold');
    _setMessage('✓ Penanda debug Budget Alert telah direset.');
    await _refreshStatus();
  }

  Future<void> _testGenerateRoasting() async {
    final AppProvider app = context.read<AppProvider>();
    final RoastingNotificationGenerator? generator = app.roastingGenerator;

    setState(() {
      _isGenerating = true;
      _generatedRoastText = null;
    });

    try {
      final RoastingNotificationGenerator gen = generator ?? RoastingAiService();
      final RoastingNotificationMessage result =
          await gen.generateDeadlineNotification(
        intensity: _testIntensity,
        taskTitle: 'Laporan Tugas Akhir',
        dueAt: DateTime.now().add(const Duration(minutes: 5)),
        remaining: const Duration(minutes: 5),
        recentMessages: const <String>[],
        userName: app.profile.fullName,
      );

      setState(() {
        _generatedRoastText = result.body;
        _lastGeneratedByAi = result.generatedByAi;
        _isGenerating = false;
      });
      _setMessage(
        '✓ Roasting berhasil digenerate (${result.generatedByAi ? "Gemini AI" : "Fallback Lokal"}).',
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _setMessage('Gagal generate roasting: $e', isError: true);
    }
  }

  Future<void> _testSendRoastingNotification({required String type}) async {
    final LocalNotificationService? service = _getService(context);
    if (service == null) return;
    final AppProvider app = context.read<AppProvider>();
    final RoastingNotificationGenerator gen =
        app.roastingGenerator ?? RoastingAiService();

    setState(() {
      _isLoading = true;
    });

    try {
      final String profileName = app.profile.fullName;
      RoastingNotificationMessage msg;
      int notifId;
      String category;
      String notifTitle;

      if (type == 'budget') {
        msg = await gen.generateBudgetNotification(
          intensity: _testIntensity,
          threshold: 80,
          spent: 800000,
          limit: 1000000,
          recentMessages: const <String>[],
          userName: profileName,
        );
        notifId = stableNotificationId('debug:roast:budget');
        category = 'Budget Roasting';
        notifTitle = 'Budget Roasting (80%)';
      } else if (type == 'deadline') {
        msg = await gen.generateDeadlineNotification(
          intensity: _testIntensity,
          taskTitle: 'Tugas Mobile Programming',
          dueAt: DateTime.now().add(const Duration(minutes: 5)),
          remaining: const Duration(minutes: 5),
          recentMessages: const <String>[],
          userName: profileName,
        );
        notifId = stableNotificationId('debug:roast:deadline');
        category = 'Deadline Roasting';
        notifTitle = 'Deadline Roasting';
      } else {
        msg = await gen.generateDailyNotification(
          intensity: _testIntensity,
          summary: const DailyRoastingSummary(
            pendingTasks: 3,
            dueTodayTasks: 1,
            overdueTasks: 1,
            completedToday: 2,
            todayExpense: 75000,
            todayTransactionCount: 4,
          ),
          recentMessages: const <String>[],
          userName: profileName,
        );
        notifId = stableNotificationId('debug:roast:daily');
        category = 'Daily Roasting';
        notifTitle = 'Daily Roasting';
      }

      await service.showTestNotification(
        id: notifId,
        title: notifTitle,
        body: msg.body,
        payload: 'debug:roast:$type',
      );

      _setMessage(
        '✓ Notifikasi $category terkirim (ID: $notifId)!\n'
        'Sumber: ${msg.generatedByAi ? "Gemini AI" : "Fallback Lokal"}\n'
        'Pesan: "${msg.body}"',
      );
    } catch (e) {
      _setMessage('Gagal mengirim notifikasi roasting: $e', isError: true);
    }

    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostics')),
        body: const Center(
          child: Text('Halaman ini hanya tersedia pada mode debug (kDebugMode).'),
        ),
      );
    }

    final theme = ThemeScope.of(context).colors;
    final DateTime now = DateTime.now();
    final String tzOffsetStr =
        '${now.timeZoneOffset.isNegative ? "-" : "+"}${now.timeZoneOffset.inHours.abs().toString().padLeft(2, "0")}:${(now.timeZoneOffset.inMinutes.abs() % 60).toString().padLeft(2, "0")}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (_statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _isError
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isError ? Colors.red : Colors.green,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: _isError ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 1. STATUS SISTEM
                _buildSectionHeader('1. Status Sistem & Perangkat', theme.blue),
                AppCard(
                  child: Column(
                    children: [
                      _buildInfoRow('LocalNotificationService', _isInitialized == true ? 'Terinisialisasi ✓' : 'Belum Terinisialisasi ✗', isOk: _isInitialized == true),
                      const Divider(height: 1),
                      _buildInfoRow('Izin Notifikasi OS', _notificationsEnabled == true ? 'Diizinkan ✓' : 'Ditolak / Belum Ada ✗', isOk: _notificationsEnabled == true),
                      const Divider(height: 1),
                      _buildInfoRow('Izin Exact Alarm', _canExactAlarms == true ? 'Diizinkan (Exact) ✓' : 'Tidak Tersedia (Inexact Mode) ⚠️', isOk: _canExactAlarms == true),
                      const Divider(height: 1),
                      _buildInfoRow('Mode Penjadwalan', _canExactAlarms == true ? 'Exact (Presisi)' : 'Inexact (Fallback)', isOk: _canExactAlarms == true),
                      const Divider(height: 1),
                      _buildInfoRow('Zona Waktu Perangkat', '${now.timeZoneName} (UTC$tzOffsetStr)'),
                      const Divider(height: 1),
                      _buildInfoRow('Zona Waktu Scheduling', '${tz.local.name} (Valid IANA ✓)'),
                      const Divider(height: 1),
                      _buildInfoRow('Waktu Lokal Sekarang', '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")} WIB/Lokal'),
                      if (_channels != null) ...[
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Notification Channels',
                          _channels!.isEmpty
                              ? 'Belum ada channel terdaftar'
                              : _channels!.map((c) => '${c.name} (${c.importance.name})').join(', '),
                          isOk: _channels!.any((c) => c.id == 'aturaja_reminders'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.notifications_active, size: 16),
                              label: const Text('Minta Izin Notif', style: TextStyle(fontSize: 12)),
                              onPressed: _requestNotificationPermission,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.alarm, size: 16),
                              label: const Text('Minta Exact Alarm', style: TextStyle(fontSize: 12)),
                              onPressed: _requestExactAlarmPermission,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 2. TOMBOL PENGUJIAN NOTIFIKASI LANGSUNG & DEADLINE
                _buildSectionHeader('2. Pengujian Notifikasi Nyata', theme.blue),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Kirim Test Notification (Langsung)'),
                        onPressed: _testImmediateNotification,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Menguji apakah Android dapat menerima dan menampilkan notifikasi langsung dari aplikasi.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Divider(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: theme.blue),
                        icon: const Icon(Icons.timer),
                        label: const Text('Jadwalkan Test Deadline (2 Menit Lagi)'),
                        onPressed: _testScheduleDeadline,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Membuat tugas uji coba dengan deadline 7 menit ke depan. Notifikasi dijadwalkan tepat 2 menit dari sekarang (aturan 5 menit).',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Batalkan Test Deadline', style: TextStyle(color: Colors.red)),
                        onPressed: _cancelTestDeadline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 3. PENGUJIAN BUDGET ALERT
                _buildSectionHeader('3. Pengujian Budget Alert (Data Simulasi)', theme.blue),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Status Penanda Debug: ${_debugBudgetThresholdSent != null ? "$_debugBudgetThresholdSent% terkirim" : "Belum ada penanda"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _testBudgetAlert(threshold: 80, spent: 80000, limit: 100000),
                              child: const Text('Test Budget 80%'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                              onPressed: () => _testBudgetAlert(threshold: 100, spent: 100000, limit: 100000),
                              child: const Text('Test Budget 100%'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Penanda Debug Budget'),
                        onPressed: _resetDebugBudgetMarkers,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Pengujian menggunakan SharedPreferences terisolasi (debug) tanpa mengubah pengeluaran asli pengguna.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 4. PENGUJIAN ROASTING AI
                _buildSectionHeader('4. Pengujian Roasting AI (Gemini)', theme.blue),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Pilih Intensitas Roasting:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<RoastingIntensity>(
                        segments: const [
                          ButtonSegment(value: RoastingIntensity.santai, label: Text('Santai', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: RoastingIntensity.seimbang, label: Text('Seimbang', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: RoastingIntensity.pedas, label: Text('Pedas', style: TextStyle(fontSize: 12))),
                        ],
                        selected: {_testIntensity},
                        onSelectionChanged: (Set<RoastingIntensity> selection) {
                          setState(() {
                            _testIntensity = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating ? 'Menghubungi Gemini...' : 'Generate Test Roasting'),
                        onPressed: _isGenerating ? null : _testGenerateRoasting,
                      ),
                      if (_generatedRoastText != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade700),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _lastGeneratedByAi == true ? '✨ Hasil Gemini AI' : '⚙️ Fallback Lokal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _lastGeneratedByAi == true ? Colors.purple : Colors.brown,
                                    ),
                                  ),
                                  Text(
                                    _testIntensity.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _generatedRoastText!,
                                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      const Text('Kirim Sebagai Notifikasi OS Nyata:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.attach_money, size: 16),
                            label: const Text('Budget Roasting', style: TextStyle(fontSize: 12)),
                            onPressed: () => _testSendRoastingNotification(type: 'budget'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.assignment_late, size: 16),
                            label: const Text('Deadline Roasting', style: TextStyle(fontSize: 12)),
                            onPressed: () => _testSendRoastingNotification(type: 'deadline'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.wb_sunny, size: 16),
                            label: const Text('Daily Roasting', style: TextStyle(fontSize: 12)),
                            onPressed: () => _testSendRoastingNotification(type: 'daily'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 5. PENDING NOTIFICATIONS
                _buildSectionHeader('5. Pending Notifications (${_pendingRequests.length})', theme.blue),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_pendingRequests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Text(
                            'Tidak ada notifikasi yang sedang menunggu jadwal.',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingRequests.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final PendingNotificationRequest req = _pendingRequests[index];
                            final DateTime? actualSchedule =
                                NotificationDiagLog.instance.getScheduledTime(req.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                req.title ?? 'Tanpa Judul',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(req.body ?? '-', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${req.id} | Payload: ${req.payload ?? "-"}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                  ),
                                  if (actualSchedule != null)
                                    Text(
                                      'Jadwal Aktual: ${actualSchedule.hour.toString().padLeft(2, "0")}:${actualSchedule.minute.toString().padLeft(2, "0")}:${actualSchedule.second.toString().padLeft(2, "0")} (${actualSchedule.day}/${actualSchedule.month})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                    )
                                  else
                                    const Text(
                                      'Jadwal: waktu aktual tidak disediakan OS API',
                                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 6. RIWAYAT DIAGNOSTIK
                _buildSectionHeader('6. Riwayat Diagnostik (${NotificationDiagLog.instance.getAll().length})', theme.blue),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Riwayat Kejadian Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          TextButton(
                            onPressed: () {
                              NotificationDiagLog.instance.clear();
                              setState(() {});
                            },
                            child: const Text('Clear Log', style: TextStyle(fontSize: 12, color: Colors.red)),
                          ),
                        ],
                      ),
                      if (NotificationDiagLog.instance.getAll().isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Text(
                            'Belum ada riwayat tercatat dalam sesi ini.',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: NotificationDiagLog.instance.getAll().take(20).length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final NotificationDiagEntry entry =
                                NotificationDiagLog.instance.getAll().toList()[index];
                            final Color resultColor = entry.result == 'error'
                                ? Colors.red
                                : (entry.result == 'scheduled' || entry.result == 'shown'
                                    ? Colors.green
                                    : Colors.orange);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '[${entry.category.toUpperCase()}] ID ${entry.notifId}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: resultColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          entry.result.toUpperCase(),
                                          style: TextStyle(color: resultColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry.message,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${entry.timestamp.hour.toString().padLeft(2, "0")}:${entry.timestamp.minute.toString().padLeft(2, "0")}:${entry.timestamp.second.toString().padLeft(2, "0")} | Mode: ${entry.mode}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool? isOk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOk == null
                    ? null
                    : (isOk ? Colors.green.shade700 : Colors.red.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
