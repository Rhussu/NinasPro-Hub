import 'dart:typed_data';

import 'descargas_stub.dart' if (dart.library.js_interop) 'descargas_web.dart';

/// Último archivo pedido para descargar (lo revisan las pruebas, donde no hay navegador)
({String nombre, Uint8List bytes})? ultimaDescarga;

/// Descarga un archivo generado en la app (plantillas y reportes)
void descargarArchivo(String nombre, Uint8List bytes, {String tipo = 'text/csv;charset=utf-8'}) {
  ultimaDescarga = (nombre: nombre, bytes: bytes);
  descargarEnPlataforma(nombre, bytes, tipo);
}
