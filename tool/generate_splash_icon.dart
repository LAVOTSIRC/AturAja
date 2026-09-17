// One-off build tool: pads the AturAja logo onto a solid navy canvas so it
// fits safely inside the circular mask that Android 12+ applies to the
// `android_12.image` splash icon (see flutter_native_splash docs). Without
// this padding, the corners of the square logo get clipped by the OS.
//
// Run with: dart run tool/generate_splash_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final sourceBytes = File('assets/images/maketh1.jpg').readAsBytesSync();
  final source = img.decodeImage(sourceBytes);
  if (source == null) {
    stderr.writeln('Could not decode assets/images/maketh1.jpg');
    exit(1);
  }

  // Android 12+ "with icon background" spec: 960x960 canvas, content must
  // fit within a circle 640px in diameter. We scale the logo down further
  // for a safety margin so none of its square corners are clipped.
  const canvasSize = 960;
  const logoSize = 420; // diagonal ~594px, comfortably inside the 640px circle
  const navy = 0xFF070F1C;

  final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(
    (navy >> 16) & 0xFF,
    (navy >> 8) & 0xFF,
    navy & 0xFF,
    255,
  ));

  final resizedLogo = img.copyResize(
    source,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.average,
  );

  final offset = ((canvasSize - logoSize) / 2).round();
  img.compositeImage(canvas, resizedLogo, dstX: offset, dstY: offset);

  final outFile = File('assets/images/maketh1_android12_icon.png');
  outFile.writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('Wrote ${outFile.path} (${canvasSize}x$canvasSize canvas, logo ${logoSize}x$logoSize)');
}
