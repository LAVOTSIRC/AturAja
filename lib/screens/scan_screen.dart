import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../providers/app_provider.dart';
import '../services/receipt_camera.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

enum _ScanStep { scan, confirm }

String _shortDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _ScanStep step = _ScanStep.scan;
  final TextEditingController amountController = TextEditingController(
    text: '28500',
  );
  bool isProcessing = false;
  bool _isCameraInitializing = false;
  String? errorMessage;
  String? _receiptImagePath;
  CameraController? _cameraController;
  int _cameraSession = 0;

  // Scanning line animation
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSession++;
    final CameraController? controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    amountController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed && step == _ScanStep.scan) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitializing || _cameraController != null) {
      return;
    }
    final int session = ++_cameraSession;
    if (mounted) {
      setState(() {
        _isCameraInitializing = true;
        errorMessage = null;
      });
    }

    try {
      final CameraController? controller =
          await ReceiptCamera.createController();
      if (!mounted || session != _cameraSession) {
        if (controller != null) {
          unawaited(controller.dispose());
        }
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitializing = false;
      });
    } on ReceiptCameraException catch (error) {
      if (!mounted || session != _cameraSession) {
        return;
      }
      setState(() {
        _isCameraInitializing = false;
        errorMessage = error.message;
      });
      if (error.permanentlyDenied) {
        _showCameraSettingsAction();
      }
    } catch (_) {
      if (!mounted || session != _cameraSession) {
        return;
      }
      setState(() {
        _isCameraInitializing = false;
        errorMessage =
            'Kamera gagal dibuka. Pastikan izin kamera aktif lalu coba lagi.';
      });
    }
  }

  Future<void> _releaseCamera() async {
    _cameraSession++;
    final CameraController? controller = _cameraController;
    if (controller == null) {
      if (mounted && _isCameraInitializing) {
        setState(() => _isCameraInitializing = false);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _cameraController = null;
        _isCameraInitializing = false;
      });
    } else {
      _cameraController = null;
      _isCameraInitializing = false;
    }

    try {
      await controller.dispose();
    } catch (_) {
      // Controller may already be detached by the platform.
    }
  }

  void _showCameraSettingsAction() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Izin kamera diblokir permanen.'),
        action: SnackBarAction(
          label: 'Pengaturan',
          onPressed: ReceiptCamera.openSettings,
        ),
      ),
    );
  }

  void _clearError() {
    if (errorMessage != null) {
      setState(() => errorMessage = null);
    }
  }

  Future<void> _captureReceipt() async {
    if (isProcessing || _isCameraInitializing) return;

    if (_cameraController == null && !ReceiptCamera.isDebugOverrideActive) {
      setState(() {
        isProcessing = true;
        errorMessage = null;
      });
      await _initializeCamera();
      if (!mounted) return;
      if (_cameraController == null) {
        setState(() => isProcessing = false);
        return;
      }
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      final String? path = await ReceiptCamera.capture(_cameraController);
      if (!mounted) return;

      if (path == null) {
        setState(() => isProcessing = false);
        return;
      }

      setState(() {
        isProcessing = false;
        _receiptImagePath = path;
        step = _ScanStep.confirm;
      });
      await _releaseCamera();
    } on ReceiptCameraException catch (error) {
      if (!mounted) return;
      setState(() {
        isProcessing = false;
        errorMessage = error.message;
      });
      if (error.permanentlyDenied) {
        _showCameraSettingsAction();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isProcessing = false;
        errorMessage = 'Kamera gagal mengambil foto. Pastikan izin kamera aktif lalu coba lagi.';
      });
    }
  }

  Future<void> _confirmScan() async {
    if (isProcessing) return;
    final String rawValue = amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final int? amount = int.tryParse(rawValue);
    if (amount == null || amount <= 0) {
      setState(
        () => errorMessage = 'Nominal tidak valid. Masukkan angka positif.',
      );
      return;
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (amountController.text.replaceAll(RegExp(r'[^0-9]'), '') != rawValue) {
        throw StateError('nominal berubah');
      }
      if (!mounted) return;

      // OCR masih disimulasikan, tetapi foto struk yang diambil dari kamera
      // asli ikut disimpan pada transaksi.
      final TransactionItem transaction = TransactionItem(
        id: DateTime.now().millisecondsSinceEpoch,
        label: 'Belanja di Indomaret',
        amount: -amount,
        cat: 'belanja',
        time: TimeOfDay.now().format(context),
        date: 'Hari ini',
        receiptImagePath: _receiptImagePath,
      );
      context.read<AppProvider>().addTransaction(transaction);
      Navigator.of(context).pop<TransactionItem>(transaction);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isProcessing = false;
        errorMessage = 'Nominal belum bisa diproses. Periksa kembali angka yang dimasukkan.';
      });
    }
  }

  void _scanAgain() {
    setState(() {
      step = _ScanStep.scan;
      isProcessing = false;
      errorMessage = null;
      _receiptImagePath = null;
    });
    if (!_scanLineController.isAnimating) {
      _scanLineController.repeat(reverse: true);
    }
    unawaited(_initializeCamera());
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: step == _ScanStep.scan ? _cameraViewBody(c) : _confirmBody(c),
      ),
    );
  }

  // ── Camera view (scan step) ──────────────────────────────────────────────

  Widget _cameraBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0D1520)],
        ),
      ),
      child: CustomPaint(painter: _NoisePainter()),
    );
  }

  Widget _buildCameraPreview(AppColors c) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _cameraBackground(),
          if (_isCameraInitializing)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            Center(
              child: Icon(
                Icons.no_photography_outlined,
                size: AppSpacing.xl,
                color: c.textMuted,
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = constraints.biggest;
        if (viewport.width <= 0 || viewport.height <= 0) {
          return CameraPreview(controller);
        }

        // CameraPreview keeps the sensor aspect ratio inside the available
        // space. Scale it up until it covers the viewfinder box, cropping the
        // excess instead of showing black letterbox bars.
        final double viewportAspect = viewport.width / viewport.height;
        final double previewAspect = viewport.width > viewport.height
            ? controller.value.aspectRatio
            : 1 / controller.value.aspectRatio;
        final double scale = previewAspect >= viewportAspect
            ? previewAspect / viewportAspect
            : viewportAspect / previewAspect;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }

  String get _cameraStatusLabel {
    if (_cameraController != null) {
      return 'KAMERA AKTIF';
    }
    if (_isCameraInitializing) {
      return 'MENYIAPKAN';
    }
    if (ReceiptCamera.isDebugOverrideActive) {
      return 'KAMERA SIAP';
    }
    return 'KAMERA OFFLINE';
  }

  Widget _cameraViewBody(AppColors c) {
    return Stack(
      children: [
        Positioned.fill(child: _cameraBackground()),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  semanticLabel: 'Tutup pemindaian struk',
                  tooltip: 'Tutup',
                  child: Container(
                    width: AppSpacing.target,
                    height: AppSpacing.target,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: AppSpacing.iconSmall,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Scan Struk', style: AppTypography.title(Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.huge),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: AppSpacing.xs,
                        color: _cameraController != null
                            ? const Color(0xFF2BD9A8)
                            : Colors.white54,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        _cameraStatusLabel,
                        style: AppTypography.micro(Colors.white)
                            .copyWith(letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Viewfinder frame + scan line
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: AppSpacing.scanFrame + 40,
                height: AppSpacing.scanFrame + 80,
                child: Stack(
                  children: [
                    // Camera preview is confined to the center viewfinder
                    // cutout; the rest of the screen stays dark.
                    Positioned(
                      left: AppSpacing.xl,
                      top: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: AppSpacing.xl,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        child: _buildCameraPreview(c),
                      ),
                    ),
                    // Dim overlay outside the frame
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ViewfinderOverlayPainter(c.success),
                      ),
                    ),
                    // Animated scan line
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _scanLineAnim,
                        builder: (ctx2, snap) {
                          return CustomPaint(
                            painter: _ScanLinePainter(
                              progress: _scanLineAnim.value,
                              color: c.success,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ketuk tombol untuk memotret struk',
                style: AppTypography.caption(
                  Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Pastikan seluruh struk terlihat jelas',
                style: AppTypography.meta(Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),

        // Error message
        if (errorMessage != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 140,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: AppSpacing.iconSmall,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: AppTypography.caption(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom controls — shutter button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: isProcessing || _isCameraInitializing
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _isCameraInitializing
                              ? 'Menyiapkan kamera...'
                              : 'Memproses struk...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shutter button
                      Center(
                        child: PressableScale(
                          onTap: _captureReceipt,
                          semanticLabel: 'Ambil foto struk',
                          tooltip: 'Ambil foto',
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Ambil Foto Struk',
                        style: AppTypography.meta(
                          Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Confirm step body ────────────────────────────────────────────────────

  Widget _confirmBody(AppColors c) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  PressableScale(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Tutup pemindaian struk',
                    tooltip: 'Tutup pemindaian',
                    child: Container(
                      width: AppSpacing.target,
                      height: AppSpacing.target,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(
                        Icons.close,
                        size: AppSpacing.iconSmall,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Konfirmasi Struk', style: AppTypography.title(c.text)),
                ],
              ),
            ),
            Expanded(child: _confirmBodyContent(c)),
          ],
        ),
      ),
    );
  }

  Widget _confirmBodyContent(AppColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_receiptImagePath != null &&
              File(_receiptImagePath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              child: Image.file(
                File(_receiptImagePath!),
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 170,
                  color: c.surfaceHigh,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: AppSpacing.xl,
                    color: c.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSpacing.iconSmall,
                      height: AppSpacing.iconSmall,
                      decoration: BoxDecoration(
                        color: c.success,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: AppSpacing.sm,
                        color: c.onAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Foto struk berhasil diambil',
                      style: AppTypography.meta(c.success)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INDOMARET · ${_shortDate(DateTime.now())}',
                        style: AppTypography.mono(c.textSub),
                      ),
                      Text(
                        'Aqua 600ml ......... 5.000',
                        style: AppTypography.mono(c.textSub),
                      ),
                      Text(
                        'Roti Tawar ......... 12.500',
                        style: AppTypography.mono(c.textSub),
                      ),
                      Text(
                        'Chitato ............ 11.000',
                        style: AppTypography.mono(c.textSub),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Container(
                          height: AppSpacing.xxs,
                          color: c.border,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          'TOTAL .............. 28.500',
                          style: AppTypography.mono(c.text)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nominal',
                          style: AppTypography.micro(c.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text('Rp28.500', style: AppTypography.display(c.text)),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kategori',
                          style: AppTypography.micro(c.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: AppSpacing.sm,
                              color: c.blue,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              'Belanja',
                              style: AppTypography.label(c.blue)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hasil OCR masih disimulasikan. Foto asli tetap disimpan bersama transaksi.',
            style: AppTypography.micro(c.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Koreksi nominal jika perlu',
            style: AppTypography.meta(c.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _clearError(),
            style: AppTypography.display(c.text),
            decoration: InputDecoration(
              labelText: 'Nominal struk',
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide(color: c.borderAccent, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide(color: c.focus, width: 1.5),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppErrorMessage(message: errorMessage!),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (isProcessing)
            AppProcessingState(message: 'Menyimpan transaksi...', color: c.blue)
          else
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                onTap: _confirmScan,
                semanticLabel: 'Konfirmasi dan catat hasil pemindaian',
                tooltip: 'Konfirmasi transaksi',
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.target,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.blue,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    'Konfirmasi & Catat',
                    style: AppTypography.button(c.onAccent),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isProcessing ? null : _scanAgain,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppSpacing.target, AppSpacing.target),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: Text('Scan Ulang', style: AppTypography.label(c.textSub)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom painters ──────────────────────────────────────────────────────────

/// Paints a semi-transparent overlay with a clear rectangular cutout (viewfinder).
class _ViewfinderOverlayPainter extends CustomPainter {
  final Color accentColor;
  _ViewfinderOverlayPainter(this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    const double frameInset = AppSpacing.xl;
    final Rect outer = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        frameInset,
        frameInset,
        size.width - frameInset,
        size.height - frameInset,
      ),
      const Radius.circular(AppSpacing.md),
    );

    // Dim the area outside the frame
    final Paint dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final Path path = Path.combine(
      PathOperation.difference,
      Path()..addRect(outer),
      Path()..addRRect(inner),
    );
    canvas.drawPath(path, dimPaint);

    // Draw the frame border
    final Paint borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(inner, borderPaint);

    // Corner accents
    const double cornerLen = AppSpacing.xl;
    final Paint cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double l = inner.left;
    final double t = inner.top;
    final double r = inner.right;
    final double b = inner.bottom;

    // Top-left
    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cornerLen, t), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - cornerLen, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cornerLen, b), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - cornerLen, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_ViewfinderOverlayPainter old) =>
      old.accentColor != accentColor;
}

/// Paints a horizontal scanning line that moves top-to-bottom inside the frame.
class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double frameInset = AppSpacing.xl;
    final double top = frameInset;
    final double bottom = size.height - frameInset;
    final double y = top + (bottom - top) * progress;

    final Paint paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTRB(frameInset, y, size.width - frameInset, y + 2),
          )
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(frameInset, y),
      Offset(size.width - frameInset, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

/// Very simple noise/grain texture painter to simulate a camera view.
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.015);
    for (int i = 0; i < 200; i++) {
      final double x = (i * 137.5) % size.width;
      final double y = (i * 53.7) % size.height;
      canvas.drawCircle(Offset(x, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_NoisePainter old) => false;
}
