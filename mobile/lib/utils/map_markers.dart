import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> savedPlaceMarker({
  required Color fill,
  required Color ring,
  required Color heart,
}) async {
  const logical = 24.0;
  const ratio = 3.0;
  const size = logical * ratio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(size / 2, size / 2);
  canvas.drawCircle(center, size / 2 - 2 * ratio, Paint()..color = fill);
  canvas.drawCircle(
    center,
    size / 2 - 2 * ratio,
    Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * ratio,
  );
  final glyph = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(Icons.favorite.codePoint),
      style: TextStyle(
        fontFamily: Icons.favorite.fontFamily,
        package: Icons.favorite.fontPackage,
        fontSize: 12 * ratio,
        color: heart,
      ),
    ),
  )..layout();
  glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(png!.buffer.asUint8List(), imagePixelRatio: ratio);
}
