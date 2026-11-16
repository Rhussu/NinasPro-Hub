import 'package:file_picker/file_picker.dart';

import '../repositories/alumnas_repository.dart';

/// Abre el selector de archivos del dispositivo y devuelve el archivo con su
/// contenido, o null si se canceló. Es una variable para que las pruebas lo
/// reemplacen (no hay selector nativo en el entorno de pruebas).
Future<ArchivoAdjunto?> Function(List<String> extensiones) elegirArchivo = _elegirConFilePicker;

Future<ArchivoAdjunto?> _elegirConFilePicker(List<String> extensiones) async {
  final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensiones);
  if (archivo == null) return null;
  return ArchivoAdjunto(nombre: archivo.name, bytes: await archivo.readAsBytes());
}

/// Abre la cámara o la galería del celular (en el navegador, `accept="image/*"`
/// ofrece ambas sin apps externas, US-18 escenario 1) y devuelve la foto, o
/// null si se canceló. Es una variable para que las pruebas la reemplacen.
Future<ArchivoAdjunto?> Function() elegirFoto = _elegirFotoConFilePicker;

Future<ArchivoAdjunto?> _elegirFotoConFilePicker() async {
  final archivo = await FilePicker.pickFile(type: FileType.image);
  if (archivo == null) return null;
  return ArchivoAdjunto(nombre: archivo.name, bytes: await archivo.readAsBytes());
}
