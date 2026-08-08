import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ReceiptCaptureHelper {
  static const double width4Inch = 384;
  static const double width4InchMm = 101.6;
  static const double capturePixelRatio4Inch = 2.12;
  static const double width80mm = 576;
  static const double width58mm = 420;

  static Future<Uint8List> captureAsPng(
    GlobalKey repaintKey, {
    double pixelRatio = 4.0,
  }) async {
    await WidgetsBinding.instance.endOfFrame;

    final context = repaintKey.currentContext;
    if (context == null) {
      throw Exception('RepaintBoundary context not available.');
    }
    if (!context.mounted) {
      throw Exception('RepaintBoundary context is no longer mounted.');
    }

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('RenderRepaintBoundary not found.');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to convert captured receipt to PNG bytes.');
    }

    return byteData.buffer.asUint8List();
  }

  static Future<String> captureAsBase64(
    GlobalKey repaintKey, {
    double pixelRatio = 4.0,
  }) async {
    final bytes = await captureAsPng(repaintKey, pixelRatio: pixelRatio);
    return base64Encode(bytes);
  }
}
