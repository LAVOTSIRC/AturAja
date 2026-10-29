import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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

  static bool get isDebugOverrideActive => debugCaptureOverride != null;

  static Future<CameraController?> createController() async {
    if (isDebugOverrideActive) {
      return null;
    }

    await _requestPermissionIfNeeded();

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const ReceiptCameraException(
          'Kamera tidak ditemukan pada perangkat ini.',
        );
      }

      final CameraDescription description = cameras.firstWhere(
        (CameraDescription camera) =>
            camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await controller.initialize();
      } on CameraException catch (error) {
        await controller.dispose();
        throw ReceiptCameraException(
          'Kamera tidak dapat diinisialisasi (${error.code}). '
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
    if (override != null) {
      return override();
    }

    if (controller == null || !controller.value.isInitialized) {
      throw const ReceiptCameraException(
        'Kamera belum siap. Tunggu sebentar lalu coba lagi.',
      );
    }

    try {
      final XFile photo = await controller.takePicture();
      return photo.path;
    } on CameraException catch (error) {
      throw ReceiptCameraException(
        'Gagal mengambil foto (${error.code}). Coba lagi.',
      );
    }
  }

  static Future<void> openSettings() => openAppSettings();

  static Future<void> _requestPermissionIfNeeded() async {
    // Di Android, minta izin runtime secara eksplisit sebelum membuat
    // controller. Di iOS, plugin kamera akan menampilkan prompt
    // NSCameraUsageDescription saat controller diinisialisasi.
    if (!Platform.isAndroid) {
      return;
    }

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
