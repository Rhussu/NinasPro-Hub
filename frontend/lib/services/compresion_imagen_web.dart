import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'compresion_imagen.dart';

/// Compresión con un canvas del navegador: rápida y sin bloquear la pantalla
/// con fotos de 8 a 12 MB. Si el navegador no lee el formato, prueba en Dart.
Future<Uint8List?> comprimirEnPlataforma(Uint8List original) async {
  try {
    final blob = web.Blob([original.toJS].toJS);
    final bitmap = await web.window
        .createImageBitmap(blob, web.ImageBitmapOptions(imageOrientation: 'from-image'))
        .toDart;
    try {
      for (final lado in ladosCompresion()) {
        final escala = math.min(1.0, lado / math.max(bitmap.width, bitmap.height));
        final ancho = math.max(1, (bitmap.width * escala).round());
        final alto = math.max(1, (bitmap.height * escala).round());
        final canvas = web.HTMLCanvasElement()
          ..width = ancho
          ..height = alto;
        (canvas.getContext('2d') as web.CanvasRenderingContext2D).drawImage(bitmap, 0, 0, ancho, alto);
        for (final calidad in calidadesJpeg) {
          final jpg = await _jpeg(canvas, calidad);
          if (jpg != null && jpg.size < pesoMaximoFoto) {
            return (await jpg.arrayBuffer().toDart).toDart.asUint8List();
          }
        }
      }
      return null;
    } finally {
      bitmap.close();
    }
  } catch (_) {
    return comprimirConImage(original);
  }
}

Future<web.Blob?> _jpeg(web.HTMLCanvasElement canvas, double calidad) {
  final listo = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? b) => listo.complete(b)).toJS, 'image/jpeg', calidad.toJS);
  return listo.future;
}
