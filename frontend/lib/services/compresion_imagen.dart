import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'compresion_imagen_stub.dart' if (dart.library.js_interop) 'compresion_imagen_web.dart';

/// Peso máximo de la foto de evidencia ya comprimida (US-18 escenario 2: menos de 1,5 MB)
const pesoMaximoFoto = 1500000;

/// Lado mayor de la foto comprimida: suficiente para la rendición y las redes
const ladoMaximoFoto = 1920;

/// Lado mínimo al que se reduce una foto que no baja del peso máximo
const _ladoMinimo = 480;

/// Calidades JPEG que se prueban en cada tamaño, de mayor a menor
const calidadesJpeg = [0.85, 0.75, 0.65, 0.55];

/// Comprime la foto en el dispositivo antes de subirla: JPEG de a lo más
/// [ladoMaximoFoto] px por lado y menos de [pesoMaximoFoto] bytes. Devuelve
/// null si no se pudo leer la imagen. En el navegador usa un canvas; es una
/// variable para que las pruebas la reemplacen.
Future<Uint8List?> Function(Uint8List original) comprimirFoto = comprimirEnPlataforma;

/// Lados a probar, del máximo al mínimo, reduciendo un 25 % cada vez
Iterable<int> ladosCompresion() sync* {
  for (var lado = ladoMaximoFoto; lado >= _ladoMinimo; lado = (lado * 0.75).round()) {
    yield lado;
  }
}

/// Compresión en Dart puro (fuera del navegador o si el canvas no lee la foto)
Uint8List? comprimirConImage(Uint8List original) {
  final leida = img.decodeImage(original);
  if (leida == null) return null;
  // Endereza las fotos del celular según su EXIF (el JPEG nuevo no lo conserva)
  final imagen = img.bakeOrientation(leida);
  Uint8List? ultima;
  for (final lado in ladosCompresion()) {
    final mayor = imagen.width > imagen.height ? imagen.width : imagen.height;
    final escalada = mayor <= lado
        ? imagen
        : img.copyResize(
            imagen,
            width: imagen.width >= imagen.height ? lado : null,
            height: imagen.width >= imagen.height ? null : lado,
            interpolation: img.Interpolation.average,
          );
    for (final calidad in calidadesJpeg) {
      ultima = img.encodeJpg(escalada, quality: (calidad * 100).round());
      if (ultima.length < pesoMaximoFoto) return ultima;
    }
  }
  return ultima != null && ultima.length < pesoMaximoFoto ? ultima : null;
}
