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
