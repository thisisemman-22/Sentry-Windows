import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_parking_desktop/core/widgets/sentry_interactive_logo.dart';

/// Helper to render the SENTRY shield logo into an image.
///
/// If [backdrop] is true, draws a dark squircle tile background (for Android/PWA maskable).
/// If [inverted] is true, draws the inverted variant (white shield, crimson car).
Future<ui.Image> renderSentryLogoImage({
  required int width,
  required int height,
  bool backdrop = false,
  bool fullBleed = false,
  bool inverted = false,
  double shieldScale = 0.88,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  if (backdrop) {
    final bgPaint = Paint()..color = const Color(0xFF0B0F19);
    if (fullBleed) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.22),
      );
      canvas.drawRRect(rrect, bgPaint);

      final borderPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, size.width * 0.02);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  // Draw the SENTRY Shield
  canvas.save();
  // Center within the canvas:
  // Virtual geometry is 100x100. Shield center is (50, 48).
  final effectiveScale = (size.width / 100.0) * shieldScale;
  final dx = (size.width - (100.0 * effectiveScale)) / 2.0;
  final dy = (size.height - (100.0 * effectiveScale)) / 2.0 + (2.0 * effectiveScale);

  canvas.translate(dx, dy);
  canvas.scale(effectiveScale);

  final painter = SentryLogoPainter(
    shieldColor: inverted ? Colors.white : const Color(0xFFC8102E),
    carBodyColor: inverted ? const Color(0xFFC8102E) : Colors.white,
    eyeColor: const Color(0xFF14151A),
    eyeOffset: Offset.zero,
    lidFactor: 1.0,
  );
  painter.paint(canvas, const Size(100, 100));
  canvas.restore();

  final picture = recorder.endRecording();
  return await picture.toImage(width, height);
}

Future<Uint8List> imageToPngBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> imageToRgbaBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

/// Creates a 32bpp DIB bitmap frame for Windows ICO files.
Uint8List createDIBImage(int width, int height, Uint8List rgbaPixels) {
  const headerSize = 40;
  final imageSize = width * height * 4;
  final maskRowSize = ((width + 31) ~/ 32) * 4;
  final maskSize = maskRowSize * height;
  final totalSize = headerSize + imageSize + maskSize;

  final b = ByteData(totalSize);
  // BITMAPINFOHEADER
  b.setUint32(0, 40, Endian.little); // biSize
  b.setInt32(4, width, Endian.little); // biWidth
  b.setInt32(8, height * 2, Endian.little); // biHeight (doubled for ICO: color + mask)
  b.setUint16(12, 1, Endian.little); // biPlanes
  b.setUint16(14, 32, Endian.little); // biBitCount
  b.setUint32(16, 0, Endian.little); // biCompression (BI_RGB)
  b.setUint32(20, imageSize, Endian.little); // biSizeImage
  b.setInt32(24, 0, Endian.little); // biXPelsPerMeter
  b.setInt32(28, 0, Endian.little); // biYPelsPerMeter
  b.setUint32(32, 0, Endian.little); // biClrUsed
  b.setUint32(36, 0, Endian.little); // biClrImportant

  // Pixels: bottom-to-top, BGRA format
  var destOffset = 40;
  for (var y = height - 1; y >= 0; y--) {
    for (var x = 0; x < width; x++) {
      final srcOffset = (y * width + x) * 4;
      final r = rgbaPixels[srcOffset];
      final g = rgbaPixels[srcOffset + 1];
      final bVal = rgbaPixels[srcOffset + 2];
      final a = rgbaPixels[srcOffset + 3];

      b.setUint8(destOffset++, bVal);
      b.setUint8(destOffset++, g);
      b.setUint8(destOffset++, r);
      b.setUint8(destOffset++, a);
    }
  }

  // AND mask: all zeros (alpha channel handles transparency)
  return b.buffer.asUint8List();
}

class IcoFrame {
  final int width;
  final int height;
  final Uint8List data;

  IcoFrame({
    required this.width,
    required this.height,
    required this.data,
  });
}

Uint8List buildIco(List<IcoFrame> frames) {
  const headerSize = 6;
  const dirEntrySize = 16;
  final totalDirSize = headerSize + frames.length * dirEntrySize;

  var currentOffset = totalDirSize;
  final offsets = <int>[];
  for (final frame in frames) {
    offsets.add(currentOffset);
    currentOffset += frame.data.length;
  }

  final b = ByteData(currentOffset);
  // Header
  b.setUint16(0, 0, Endian.little); // reserved
  b.setUint16(2, 1, Endian.little); // type = icon (1)
  b.setUint16(4, frames.length, Endian.little); // frame count

  // Directory entries
  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    final entryOffset = headerSize + i * dirEntrySize;
    b.setUint8(entryOffset, frame.width >= 256 ? 0 : frame.width);
    b.setUint8(entryOffset + 1, frame.height >= 256 ? 0 : frame.height);
    b.setUint8(entryOffset + 2, 0); // color count
    b.setUint8(entryOffset + 3, 0); // reserved
    b.setUint16(entryOffset + 4, 1, Endian.little); // planes
    b.setUint16(entryOffset + 6, 32, Endian.little); // bit count
    b.setUint32(entryOffset + 8, frame.data.length, Endian.little); // bytes in res
    b.setUint32(entryOffset + 12, offsets[i], Endian.little); // image offset
  }

  // Image data blocks
  final resultList = b.buffer.asUint8List();
  for (var i = 0; i < frames.length; i++) {
    resultList.setRange(
      offsets[i],
      offsets[i] + frames[i].data.length,
      frames[i].data,
    );
  }

  return resultList;
}

const String sentrySvgString = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100%" height="100%">
  <!-- SENTRY BatStateU Crimson Shield -->
  <path d="M50 4 L84 15 V47 Q84 73 50 92 Q16 73 16 47 V15 Z" fill="#C8102E" />
  <!-- Car Cabin -->
  <path d="M35 41 L41 29 H59 L65 41 Z" fill="#FFFFFF" />
  <!-- Car Main Body -->
  <rect x="29" y="41" width="42" height="19" rx="6" ry="6" fill="#FFFFFF" />
  <!-- Wheels -->
  <rect x="33" y="60" width="9" height="6" rx="2.5" ry="2.5" fill="#FFFFFF" />
  <rect x="58" y="60" width="9" height="6" rx="2.5" ry="2.5" fill="#FFFFFF" />
  <!-- Headlight Eyes -->
  <rect x="34.75" y="44.5" width="7.5" height="12" rx="3.75" ry="3.75" fill="#14151A" transform="rotate(8 38.5 50.5)" />
  <rect x="57.75" y="44.5" width="7.5" height="12" rx="3.75" ry="3.75" fill="#14151A" transform="rotate(-8 61.5 50.5)" />
</svg>''';

void main() {
  test('Generate complete SENTRY brand logo asset suite', () async {
    // Ensure output directories exist
    final brandingDir = Directory('assets/branding');
    if (!brandingDir.existsSync()) {
      brandingDir.createSync(recursive: true);
    }

    // 1. Generate SVG vector file
    File('assets/branding/sentry_logo.svg').writeAsStringSync(sentrySvgString);

    // 2. Generate Master PNGs
    final img1024 = await renderSentryLogoImage(width: 1024, height: 1024);
    final png1024 = await imageToPngBytes(img1024);
    File('assets/branding/sentry_logo.png').writeAsBytesSync(png1024);

    final img512 = await renderSentryLogoImage(width: 512, height: 512);
    final png512 = await imageToPngBytes(img512);
    File('assets/branding/sentry_logo_512.png').writeAsBytesSync(png512);

    final img256 = await renderSentryLogoImage(width: 256, height: 256);
    final png256 = await imageToPngBytes(img256);
    File('assets/branding/sentry_logo_256.png').writeAsBytesSync(png256);

    // Inverted master
    final imgInv1024 = await renderSentryLogoImage(
      width: 1024,
      height: 1024,
      inverted: true,
    );
    final pngInv1024 = await imageToPngBytes(imgInv1024);
    File('assets/branding/sentry_logo_inverted.png').writeAsBytesSync(pngInv1024);

    // App card tile master
    final imgCard1024 = await renderSentryLogoImage(
      width: 1024,
      height: 1024,
      backdrop: true,
      shieldScale: 0.68,
    );
    final pngCard1024 = await imageToPngBytes(imgCard1024);
    File('assets/branding/sentry_logo_card.png').writeAsBytesSync(pngCard1024);

    // 3. Android Launcher Icons (mipmap-*)
    final androidMipmaps = <String, int>{
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    };

    for (final entry in androidMipmaps.entries) {
      final img = await renderSentryLogoImage(
        width: entry.value,
        height: entry.value,
        backdrop: true,
        shieldScale: 0.68,
      );
      final bytes = await imageToPngBytes(img);
      final file = File(entry.key);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }

    // 4. Web Favicons & PWA Icons
    final imgFavicon = await renderSentryLogoImage(width: 48, height: 48);
    File('web/favicon.png').writeAsBytesSync(await imageToPngBytes(imgFavicon));

    final imgWeb192 = await renderSentryLogoImage(width: 192, height: 192);
    File('web/icons/Icon-192.png').writeAsBytesSync(await imageToPngBytes(imgWeb192));

    final imgWeb512 = await renderSentryLogoImage(width: 512, height: 512);
    File('web/icons/Icon-512.png').writeAsBytesSync(await imageToPngBytes(imgWeb512));

    final imgMask192 = await renderSentryLogoImage(
      width: 192,
      height: 192,
      backdrop: true,
      fullBleed: true,
      shieldScale: 0.60,
    );
    File('web/icons/Icon-maskable-192.png')
        .writeAsBytesSync(await imageToPngBytes(imgMask192));

    final imgMask512 = await renderSentryLogoImage(
      width: 512,
      height: 512,
      backdrop: true,
      fullBleed: true,
      shieldScale: 0.60,
    );
    File('web/icons/Icon-maskable-512.png')
        .writeAsBytesSync(await imageToPngBytes(imgMask512));

    // 5. Windows Native Multi-Resolution .ico
    // Sizes to generate: 256, 128, 64, 48, 32, 24, 16
    final icoFrames = <IcoFrame>[];

    // Frame 0: 256x256 PNG
    icoFrames.add(IcoFrame(width: 256, height: 256, data: png256));

    // Frame 1: 128x128 PNG
    final img128 = await renderSentryLogoImage(width: 128, height: 128);
    final png128 = await imageToPngBytes(img128);
    icoFrames.add(IcoFrame(width: 128, height: 128, data: png128));

    // Frame 2: 64x64 PNG
    final img64 = await renderSentryLogoImage(width: 64, height: 64);
    final png64 = await imageToPngBytes(img64);
    icoFrames.add(IcoFrame(width: 64, height: 64, data: png64));

    // Frame 3: 48x48 32bpp DIB
    final img48 = await renderSentryLogoImage(width: 48, height: 48);
    final dib48 = createDIBImage(48, 48, await imageToRgbaBytes(img48));
    icoFrames.add(IcoFrame(width: 48, height: 48, data: dib48));

    // Frame 4: 32x32 32bpp DIB
    final img32 = await renderSentryLogoImage(width: 32, height: 32);
    final dib32 = createDIBImage(32, 32, await imageToRgbaBytes(img32));
    icoFrames.add(IcoFrame(width: 32, height: 32, data: dib32));

    // Frame 5: 24x24 32bpp DIB
    final img24 = await renderSentryLogoImage(width: 24, height: 24);
    final dib24 = createDIBImage(24, 24, await imageToRgbaBytes(img24));
    icoFrames.add(IcoFrame(width: 24, height: 24, data: dib24));

    // Frame 6: 16x16 32bpp DIB
    final img16 = await renderSentryLogoImage(width: 16, height: 16);
    final dib16 = createDIBImage(16, 16, await imageToRgbaBytes(img16));
    icoFrames.add(IcoFrame(width: 16, height: 16, data: dib16));

    // Also include PNG frames for 48, 32, 16 for modern Windows shell
    icoFrames.add(IcoFrame(width: 48, height: 48, data: await imageToPngBytes(img48)));
    icoFrames.add(IcoFrame(width: 32, height: 32, data: await imageToPngBytes(img32)));
    icoFrames.add(IcoFrame(width: 16, height: 16, data: await imageToPngBytes(img16)));

    final icoBytes = buildIco(icoFrames);
    File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoBytes);
    File('assets/branding/app_icon.ico').writeAsBytesSync(icoBytes);

    // Verify all generated files exist and have non-zero sizes
    expect(File('assets/branding/sentry_logo.svg').existsSync(), isTrue);
    expect(File('assets/branding/sentry_logo.png').lengthSync(), greaterThan(1000));
    expect(File('assets/branding/sentry_logo_512.png').lengthSync(), greaterThan(1000));
    expect(File('assets/branding/sentry_logo_256.png').lengthSync(), greaterThan(1000));
    expect(File('assets/branding/sentry_logo_card.png').lengthSync(), greaterThan(1000));
    expect(File('assets/branding/sentry_logo_inverted.png').lengthSync(), greaterThan(1000));
    expect(File('windows/runner/resources/app_icon.ico').lengthSync(), greaterThan(10000));
    expect(File('web/favicon.png').lengthSync(), greaterThan(500));
    expect(File('web/icons/Icon-192.png').lengthSync(), greaterThan(1000));
    expect(File('web/icons/Icon-512.png').lengthSync(), greaterThan(1000));
    expect(File('web/icons/Icon-maskable-192.png').lengthSync(), greaterThan(1000));
    expect(File('web/icons/Icon-maskable-512.png').lengthSync(), greaterThan(1000));

    for (final path in androidMipmaps.keys) {
      expect(File(path).lengthSync(), greaterThan(500));
    }
  });
}
