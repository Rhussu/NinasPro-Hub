import 'dart:typed_data';

import 'compresion_imagen.dart';

Future<Uint8List?> comprimirEnPlataforma(Uint8List original) async => comprimirConImage(original);
