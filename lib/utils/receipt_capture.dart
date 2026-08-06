import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// Capture a RepaintBoundary referenced by [key] to PNG bytes.
/// Use a high pixelRatio (e.g., 3.0 or 4.0) for high-DPI printers.
Future<Uint8List> capturePngBytes(
  GlobalKey repaintKey, {
  double pixelRatio = 3.0,
}) async {
  final context = repaintKey.currentContext;
  if (context == null) throw Exception('RepaintBoundary context is null');

  final boundary = context.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found');

  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('Failed to convert image to bytes');
  return byteData.buffer.asUint8List();
}
