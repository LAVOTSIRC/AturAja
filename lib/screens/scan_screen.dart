import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

enum _ScanStep { scan, confirm }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _ScanStep step = _ScanStep.scan;
  final TextEditingController amountController = TextEditingController(
    text: '28500',
  );
  bool isProcessing = false;
  String? errorMessage;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (errorMessage != null) {
      setState(() => errorMessage = null);
    }
  }

  Future<void> _captureReceipt() async {
    if (isProcessing) {
      return;
    }
    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }
      setState(() {
        isProcessing = false;
        step = _ScanStep.confirm;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isProcessing = false;
        errorMessage =
            'Pemindaian gagal. Coba lagi dengan pencahayaan yang lebih baik.';
      });
    }
  }

  Future<void> _confirmScan() async {
    if (isProcessing) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
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
                  Text('Scan Struk', style: AppTypography.title(c.text)),
                ],
              ),
            ),
            Expanded(
              child: step == _ScanStep.scan ? _scanBody(c) : _confirmBody(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanBody(AppColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.huge,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSpacing.scanFrame),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _corner(c, top: true, left: true),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _corner(c, top: true, left: false),
                  ),
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _corner(c, top: false, left: true),
                  ),
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _corner(c, top: false, left: false),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: AppSpacing.iconLarge,
                        color: c.blue,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'Mode simulasi: area kamera akan membaca struk belanja',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Simulasi pembacaan struk lokal untuk membantu konfirmasi nominal sebelum mencatat.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(c.textSub).copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (errorMessage != null) ...[
            AppErrorMessage(message: errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (isProcessing)
            AppProcessingState(
              message: 'Memproses struk secara lokal...',
              color: c.success,
            )
          else
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                onTap: _captureReceipt,
                semanticLabel: 'Simulasikan foto struk',
                tooltip: 'Proses foto struk',
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.target,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    'Simulasikan Foto Struk',
                    style: AppTypography.button(c.onAccent)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner(AppColors c, {required bool top, required bool left}) {
    return Container(
      width: AppSpacing.scanCorner,
      height: AppSpacing.scanCorner,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: c.success, width: AppSpacing.xxs)
              : BorderSide.none,
          bottom: !top
              ? BorderSide(color: c.success, width: AppSpacing.xxs)
              : BorderSide.none,
          left: left
              ? BorderSide(color: c.success, width: AppSpacing.xxs)
              : BorderSide.none,
          right: !left
              ? BorderSide(color: c.success, width: AppSpacing.xxs)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _confirmBody(AppColors c) {
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
                      'Simulasi: struk terbaca — keyakinan 94%',
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
                        'INDOMARET · 13/09/2026',
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
