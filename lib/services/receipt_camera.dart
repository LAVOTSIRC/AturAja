import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Error yang bisa ditampilkan langsung ke pengguna saat kamera gagal dibuka.
class ReceiptCameraException implements Exception {
  final String message;
  final bool permanentlyDenied;

  const ReceiptCameraException(this.message, {this.permanentlyDenied = false});

  @override
  String toString() => message;
}

/// Mengelola kamera belakang untuk preview langsung di halaman Scan.
///
/// Controller sengaja dikembalikan ke screen agar `CameraPreview` bisa
/// ditampilkan di dalam viewfinder. Widget test dapat memakai
/// [debugCaptureOverride] supaya tidak menyentuh plugin platform asli.
class ReceiptCamera {
  ReceiptCamera._();

  /// Dipakai oleh widget test untuk mensimulasikan hasil jepretan.
  @visibleForTesting
  static Future<String?> Function()? debugCaptureOverride;

  /// Dipakai oleh widget test untuk mensimulasikan pilih dari galeri.
  @visibleForTesting
  static Future<String?> Function()? debugPickGalleryOverride;

  static bool get isDebugOverrideActive => debugCaptureOverride != null;

  static Future<CameraController?> createController() async {
    if (isDebugOverrideActive) {
      return null;
    }

    await _requestPermissionIfNeeded();

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const ReceiptCameraException('Kamera tidak ditemukan pada perangkat ini.');
      }

      final CameraDescription description = cameras.firstWhere(
        (CameraDescription camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Coba resolusi tertinggi dulu, fallback ke high jika tidak didukung
      CameraController? controller;
      for (final ResolutionPreset preset in [ResolutionPreset.veryHigh, ResolutionPreset.high]) {
        final CameraController candidate = CameraController(
          description,
          preset,
          enableAudio: false,
        );
        try {
          await candidate.initialize();
          controller = candidate;
          break;
        } on CameraException {
          await candidate.dispose();
          // Lanjut ke preset berikutnya
        }
      }

      if (controller == null) {
        throw const ReceiptCameraException(
          'Kamera tidak dapat diinisialisasi. '
          'Pastikan tidak ada aplikasi lain yang sedang memakai kamera.',
        );
      }

      return controller;
    } on ReceiptCameraException {
      rethrow;
    } on CameraException catch (error) {
      throw ReceiptCameraException(
        'Kamera tidak dapat dibuka (${error.code}). '
        'Pastikan izin kamera aktif dan coba lagi.',
        permanentlyDenied: error.code.toLowerCase().contains('accessdenied'),
      );
    } catch (_) {
      throw const ReceiptCameraException(
        'Kamera tidak tersedia. Coba tutup aplikasi lain yang memakai kamera.',
      );
    }
  }

  static Future<String?> capture(CameraController? controller) async {
    final Future<String?> Function()? override = debugCaptureOverride;
    if (override != null) return override();

    if (controller == null || !controller.value.isInitialized) {
      throw const ReceiptCameraException('Kamera belum siap. Tunggu sebentar lalu coba lagi.');
    }

    try {
      final XFile photo = await controller.takePicture();
      return photo.path;
    } on CameraException catch (error) {
      throw ReceiptCameraException('Gagal mengambil foto (${error.code}). Coba lagi.');
    }
  }

  static Future<String?> pickFromGallery() async {
    final Future<String?> Function()? override = debugPickGalleryOverride;
    if (override != null) return override();

    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      return photo?.path;
    } on PlatformException catch (e) {
      throw ReceiptCameraException(
        'Galeri tidak dapat dibuka: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw ReceiptCameraException('Galeri tidak dapat dibuka: $e');
    }
  }

  /// Toggle flash/torch pada kamera.
  static Future<void> toggleFlash(CameraController? controller, FlashMode mode) async {
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(mode);
    } on CameraException catch (e) {
      if (kDebugMode) debugPrint('[ReceiptCamera] Flash error: ${e.code}');
    }
  }

  /// Set focus point dan exposure point pada posisi tap dalam layar.
  /// [tapPosition] adalah posisi dalam koordinat widget preview.
  /// [previewSize] adalah ukuran widget preview (lebar × tinggi).
  static Future<void> setFocusAndExposure(
    CameraController? controller,
    Offset tapPosition,
    Size previewSize,
  ) async {
    if (controller == null || !controller.value.isInitialized) return;
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    final Offset normalized = Offset(
      (tapPosition.dx / previewSize.width).clamp(0.0, 1.0),
      (tapPosition.dy / previewSize.height).clamp(0.0, 1.0),
    );

    try {
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(normalized);
      }
      if (controller.value.focusPointSupported) {
        await controller.setFocusPoint(normalized);
      }
    } on CameraException catch (e) {
      if (kDebugMode) debugPrint('[ReceiptCamera] Focus/Exposure error: ${e.code}');
    }
  }

  static Future<void> openSettings() => openAppSettings();

  static Future<void> _requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) return;

    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      throw ReceiptCameraException(
        status.isPermanentlyDenied
            ? 'Izin kamera diblokir. Buka pengaturan aplikasi untuk mengaktifkannya.'
            : 'Izin kamera diperlukan untuk memindai struk.',
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }
  }
}
