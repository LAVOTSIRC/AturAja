import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/id_generator.dart';
import '../data/models.dart';
import '../providers/app_provider.dart';
import '../services/receipt_camera.dart';
import '../services/receipt_ocr_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/expense_categories.dart';
import 'finance_screen.dart';
import '../widgets/common.dart';

enum _ScanStep { scan, confirm }

String _shortDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

String _formatReceiptAmount(int amount) {
  final String digits = amount.abs().toString();
  final StringBuffer formatted = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write('.');
    }
    formatted.write(digits[index]);
  }
  return amount < 0 ? '-$formatted' : formatted.toString();
}

class _EditableItem {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;

  /// true = biaya tambahan (pajak, service charge, tip, diskon, dll)
  bool isCharge;
  bool isDiscount;
  String category;

  int? get amount => int.tryParse(amountCtrl.text.replaceAll('.', '').trim());

  _EditableItem({
    String name = '',
    String amount = '',
    this.isCharge = false,
    this.isDiscount = false,
    this.category = 'belanja',
  }) : nameCtrl = TextEditingController(text: name),
       amountCtrl = TextEditingController(text: amount);

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _ScanStep step = _ScanStep.scan;
  final TextEditingController merchantController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final ReceiptOcrService _ocrService = ReceiptOcrService();
  bool isProcessing = false;
  bool _isCameraInitializing = false;
  String? errorMessage;
  String? _receiptImagePath;
  ReceiptOcrResult? _ocrResult;
  CameraController? _cameraController;
  int _cameraSession = 0;

  final List<_EditableItem> _editableItems = [];
  String? _processingStatus;
  bool _showAccuracyWarning = false;
  bool _usedLocalFallback = false;
  bool _isGuardrailError = false;

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
    merchantController.dispose();
    dateController.dispose();
    _disposeAllEditableItems();
    unawaited(_ocrService.close());
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

  void _disposeAllEditableItems() {
    for (final item in _editableItems) {
      item.dispose();
    }
    _editableItems.clear();
  }

  void _populateEditableItems(ReceiptOcrResult result) {
    final List<_EditableItem> previous = List<_EditableItem>.of(_editableItems);
    _editableItems.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final _EditableItem item in previous) {
        item.dispose();
      }
    });
    for (final item in result.items) {
      _editableItems.add(
        _EditableItem(
          name: item.name,
          amount: item.amount.toString(),
          isCharge: item.isCharge,
          isDiscount: item.isDiscount,
          category: receiptExpenseCategory(
            item.name,
            suggestedKey: item.categoryKey,
          ),
        ),
      );
    }
    if (_editableItems.isEmpty && (result.total ?? 0) > 0) {
      final String name = result.merchant.isEmpty
          ? 'Pengeluaran dari struk'
          : result.merchant;
      _editableItems.add(
        _EditableItem(
          name: name,
          amount: result.total.toString(),
          category: receiptExpenseCategory(name),
        ),
      );
    }
  }

  void _addItem() {
    setState(() {
      _editableItems.add(_EditableItem());
      errorMessage = null;
    });
  }

  void _removeItem(int index) {
    final _EditableItem removed = _editableItems[index];
    setState(() {
      _editableItems.removeAt(index);
      errorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  int get _previewTotal => _editableItems.fold<int>(0, (total, item) {
    final int amount = item.amount ?? 0;
    return total + (item.isDiscount ? -amount : amount);
  });

  Future<void> _runOcrOnPath(String imagePath) async {
    if (!mounted || _processingStatus != null) return;
    setState(() {
      _processingStatus = 'Membaca teks dari foto...';
      _isGuardrailError = false;
      _showAccuracyWarning = false;
      _usedLocalFallback = false;
      errorMessage = null;
    });

    try {
      final String text = await _ocrService.extractText(imagePath);
      if (!mounted) return;

      setState(() => _processingStatus = 'Menganalisis struk...');
      final ReceiptOcrResult result = await _ocrService.parseText(text);
      if (!mounted) return;

      setState(() {
        _populateEditableItems(result);
        merchantController.text = result.merchant;
        dateController.text = result.date == null
            ? ''
            : _shortDate(result.date!);
        _ocrResult = result;
        _showAccuracyWarning = _ocrService.isResultSuspicious(result);
        _usedLocalFallback = result.usedLocalFallback;
        _processingStatus = null;
        errorMessage = null;
      });
    } on ReceiptOcrException catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.message;
        _processingStatus = null;
        _isGuardrailError = error.isGuardrailError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processingStatus = null;
        errorMessage = 'Struk gagal dianalisis. Coba pindai ulang foto.';
      });
      debugPrint('Pemindaian struk gagal: $error');
    }
  }

  Future<void> _retryOcr() async {
    final String? path = _receiptImagePath;
    if (path == null || isProcessing || _processingStatus != null) return;
    if (_editableItems.isNotEmpty) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Scan ulang foto ini?'),
          content: const Text(
            'Hasil scan baru akan menggantikan daftar dan perubahan sebelumnya.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Scan Ulang'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    FocusScope.of(context).unfocus();
    await _runOcrOnPath(path);
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

      _scanLineController.stop();
      setState(() {
        isProcessing = false;
        _receiptImagePath = path;
        step = _ScanStep.confirm;
      });
      await _releaseCamera();
      await _runOcrOnPath(path);
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

  Future<void> _pickReceiptFromGallery() async {
    if (isProcessing || _isCameraInitializing) return;
    setState(() {
      isProcessing = true;
      errorMessage = null;
    });
    try {
      final String? path = await ReceiptCamera.pickFromGallery();
      if (!mounted || path == null) {
        if (mounted) setState(() => isProcessing = false);
        return;
      }
      _scanLineController.stop();
      setState(() {
        isProcessing = false;
        _receiptImagePath = path;
        step = _ScanStep.confirm;
      });
      await _releaseCamera();
      await _runOcrOnPath(path);
    } catch (error) {
      if (mounted) {
        setState(() {
          isProcessing = false;
          errorMessage = 'Foto dari galeri tidak dapat diproses: $error';
        });
      }
    }
  }

  void _confirmScan() {
    if (isProcessing || _processingStatus != null) return;
    if (_editableItems.isEmpty) {
      setState(
        () => errorMessage = 'Tambahkan minimal satu item sebelum menyimpan.',
      );
      return;
    }

    final String date = dateController.text.trim();
    final String time = TimeOfDay.now().format(context);
    final List<TransactionItem> transactions = [];
    for (final (index, item) in _editableItems.indexed) {
      final String label = item.nameCtrl.text.trim();
      final int? amount = item.amount;
      if (label.isEmpty ||
          label.length > 200 ||
          amount == null ||
          amount <= 0 ||
          amount > kMaxTransactionAmount) {
        setState(
          () => errorMessage =
              'Periksa nama (maksimal 200 karakter) dan nominal item ${index + 1}.',
        );
        return;
      }
      transactions.add(
        TransactionItem(
          id: newDocumentId(),
          label: item.isDiscount && !label.toLowerCase().startsWith('diskon')
              ? 'Diskon ${label.length > 193 ? label.substring(0, 193) : label}'
              : label,
          amount: item.isDiscount ? amount : -amount,
          cat: item.category,
          time: time,
          date: date.isEmpty ? _shortDate(DateTime.now()) : date,
        ),
      );
    }
    if (date.length > 50) {
      setState(() => errorMessage = 'Tanggal transaksi terlalu panjang.');
      return;
    }
    final AppProvider app = context.read<AppProvider>();
    unawaited(app.addTransactions(transactions));
    Navigator.of(context).pop<List<TransactionItem>>(transactions);
  }

  void _scanAgain() {
    if (isProcessing || _processingStatus != null) return;
    final List<_EditableItem> previous = List<_EditableItem>.of(_editableItems);
    setState(() {
      _editableItems.clear();
      step = _ScanStep.scan;
      isProcessing = false;
      errorMessage = null;
      _receiptImagePath = null;
      _ocrResult = null;
      merchantController.text = '';
      dateController.text = '';
      _processingStatus = null;
      _showAccuracyWarning = false;
      _usedLocalFallback = false;
      _isGuardrailError = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final _EditableItem item in previous) {
        item.dispose();
      }
    });
    if (!_scanLineController.isAnimating) {
      _scanLineController.repeat(reverse: true);
    }

    unawaited(_initializeCamera());
  }

  List<Widget> _buildReceiptItemLines(AppColors c) {
    final List<ReceiptItem> items = _ocrResult?.items ?? const <ReceiptItem>[];
    if (items.isEmpty) {
      return <Widget>[
        Text(
          'Detail produk tidak terbaca',
          style: AppTypography.mono(c.textMuted),
        ),
      ];
    }
    return items.map((ReceiptItem item) {
      if (item.isCharge) {
        return Text(
          '${item.name} - - - - ${_formatReceiptAmount(item.amount)}',
          style: AppTypography.mono(c.textMuted)
              .copyWith(fontStyle: FontStyle.italic),
        );
      }
      return Text(
        '${item.name} ......... ${_formatReceiptAmount(item.amount)}',
        style: AppTypography.mono(c.textSub),
      );
    }).toList();
  }

  /// Banner progress saat OCR masih berjalan di step konfirmasi.
  Widget _buildOcrLoadingBanner(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: c.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: AppSpacing.iconSmall,
                height: AppSpacing.iconSmall,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.blue),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _processingStatus ?? 'Memproses...',
                  style: AppTypography.label(c.blue)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              color: c.blue,
              backgroundColor: c.blue.withValues(alpha: 0.2),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFallbackBanner(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.blueDim,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: c.blue.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppSpacing.iconSmall,
            color: c.blue,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Gemini/App Check tidak tersedia, struk dibaca dengan parser '
              'lokal. Periksa kembali daftar item dan nominal sebelum menyimpan.',
              style: AppTypography.caption(c.blue),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner peringatan kuning saat hasil AI mungkin tidak akurat.
  Widget _buildAccuracyWarningBanner(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppSpacing.iconSmall,
            color: c.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periksa kembali sebelum menyimpan',
                  style: AppTypography.label(c.warning)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hasil analisis AI mungkin tidak 100% akurat — ada item yang '
                  'terlewat atau harga yang salah baca. Koreksi daftar item dan '
                  'nominal sebelum konfirmasi.',
                  style: AppTypography.caption(c.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner merah saat gambar bukan struk / foto tidak terbaca.
  Widget _buildGuardrailErrorBanner(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: c.expense.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.block_rounded,
            size: AppSpacing.iconSmall,
            color: c.expense,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gambar bukan struk atau tidak terbaca',
                  style: AppTypography.label(c.expense)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  errorMessage ??
                      'Pastikan memotret struk yang '
                          'memuat daftar item dan harga dengan jelas.',
                  style: AppTypography.caption(c.expense),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItemsSection(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                'Daftar Item',
                style: AppTypography.label(c.text)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _processingStatus == null ? _addItem : null,
              icon: const Icon(Icons.add, size: AppSpacing.iconSmall),
              label: const Text('Tambah Item'),
              style: TextButton.styleFrom(
                foregroundColor: c.blue,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_editableItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'Tidak ada item terdeteksi. Ketuk + Tambah Item untuk menambah manual.',
              style: AppTypography.caption(c.textMuted),
            ),
          )
        else
          ...List<Widget>.generate(
            _editableItems.length,
            (int index) => KeyedSubtree(
              key: ObjectKey(_editableItems[index]),
              child: _buildEditableItemRow(c, index, _editableItems[index]),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Total yang akan dicatat: Rp${_formatReceiptAmount(_previewTotal)}',
          style: AppTypography.label(c.text),
        ),
        if (_ocrResult?.total != null && _ocrResult!.total != _previewTotal)
          Text(
            'Total pada struk: Rp${_formatReceiptAmount(_ocrResult!.total!)}. '
            'Periksa jika ada item atau diskon yang terlewat.',
            style: AppTypography.caption(c.warning),
          ),
      ],
    );
  }

  Widget _buildEditableItemRow(AppColors c, int index, _EditableItem item) {
    final Color accentColor = item.isCharge ? c.warning : c.border;
    final Color fillColor = item.isCharge
        ? c.warning.withValues(alpha: 0.08)
        : c.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge baris: produk biasa vs biaya tambahan (tappable untuk toggle)
          GestureDetector(
            onTap: () => setState(() {
              if (item.isDiscount) {
                item.isDiscount = false;
                item.isCharge = false;
              } else if (item.isCharge) {
                item.isDiscount = true;
              } else {
                item.isCharge = true;
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: item.isCharge
                    ? c.warning.withValues(alpha: 0.15)
                    : c.surface,
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(AppSpacing.xxs),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isCharge
                        ? Icons.receipt_outlined
                        : Icons.shopping_bag_outlined,
                    size: 10,
                    color: item.isCharge ? c.warning : c.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    item.isDiscount
                        ? 'DISKON'
                        : item.isCharge
                        ? 'BIAYA / PAJAK'
                        : 'PRODUK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: item.isCharge ? c.warning : c.textMuted,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.swap_horiz,
                    size: 9,
                    color: item.isCharge ? c.warning : c.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: item.nameCtrl,
                  onChanged: (_) => _clearError(),
                  style: AppTypography.body(c.text),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: item.isCharge
                        ? 'Nama biaya / pajak'
                        : 'Nama item',
                    hintStyle: AppTypography.body(c.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: c.focus, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: item.amountCtrl,
                  onChanged: (_) => setState(() => errorMessage = null),
                  keyboardType: TextInputType.number,
                  style: AppTypography.body(item.isCharge ? c.warning : c.text),
                  decoration: InputDecoration(
                    hintText: 'Nominal',
                    hintStyle: AppTypography.body(c.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      borderSide: BorderSide(color: c.focus, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              SizedBox(
                width: AppSpacing.target,
                height: AppSpacing.target,
                child: IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline),
                  color: c.expense,
                  iconSize: AppSpacing.iconSmall,
                  padding: EdgeInsets.zero,
                  tooltip: 'Hapus item',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: item.category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori item'),
            items: [
              for (final entry in expenseCategoryKeys.entries)
                DropdownMenuItem(value: entry.value, child: Text(entry.key)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => item.category = value);
            },
          ),
        ],
      ),
    );
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
                              : (_processingStatus ??
                                    'Menganalisis struk dengan Gemini AI...'),
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
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: _pickReceiptFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Pilih dari galeri'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

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
                  Text('Pratinjau Struk', style: AppTypography.title(c.text)),
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
          if (_processingStatus != null) _buildOcrLoadingBanner(c),
          if (_usedLocalFallback && _processingStatus == null) ...[
            _buildLocalFallbackBanner(c),
          ],
          if (_showAccuracyWarning && _processingStatus == null) ...[
            _buildAccuracyWarningBanner(c),
          ],
          if (_isGuardrailError && _processingStatus == null) ...[
            _buildGuardrailErrorBanner(c),
          ],
          if (errorMessage != null && !_isGuardrailError) ...[
            AppErrorMessage(message: errorMessage!),
            const SizedBox(height: AppSpacing.sm),
          ],
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
                        color: _ocrResult?.hasFinancialInfo == true
                            ? c.success
                            : c.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _ocrResult?.hasFinancialInfo == true
                            ? Icons.check
                            : Icons.priority_high_rounded,
                        size: AppSpacing.sm,
                        color: c.onAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _ocrResult?.hasFinancialInfo == true
                            ? 'Foto struk berhasil diambil'
                            : 'Informasi struk tidak terdeteksi — silakan periksa manual',
                        style: AppTypography.meta(
                          _ocrResult?.hasFinancialInfo == true
                              ? c.success
                              : c.warning,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
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
                        '${merchantController.text.toUpperCase()} · ${dateController.text}',
                        style: AppTypography.mono(c.textSub),
                      ),
                      ..._buildReceiptItemLines(c),
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
                          'TOTAL .............. '
                          '${_formatReceiptAmount(_ocrResult?.total ?? 0)}',
                          style: AppTypography.mono(c.text)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Periksa nama, nominal, dan kategori. Setiap item akan dicatat sebagai transaksi tersendiri.',
            style: AppTypography.micro(c.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          AbsorbPointer(
            absorbing: _processingStatus != null,
            child: _buildEditableItemsSection(c),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: dateController,
            onChanged: (_) => _clearError(),
            style: AppTypography.body(c.text),
            decoration: InputDecoration(
              labelText: 'Tanggal transaksi',
              hintText: 'Contoh: 10/11/2026',
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide(color: c.borderAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (errorMessage != null && !_isGuardrailError) ...[
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
                onTap: _processingStatus != null ? null : _confirmScan,
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
              onPressed: isProcessing || _processingStatus != null
                  ? null
                  : _scanAgain,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppSpacing.target, AppSpacing.target),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: Text(
                'Ambil atau Pilih Foto Baru',
                style: AppTypography.label(c.textSub),
              ),
            ),
          ),
          if (_receiptImagePath != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _processingStatus != null ? null : _retryOcr,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: AppSpacing.iconSmall,
                ),
                label: const Text('Scan Ulang Foto Ini'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.blue,
                  side: BorderSide(color: c.blue.withValues(alpha: 0.5)),
                  minimumSize: const Size(AppSpacing.target, AppSpacing.target),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
