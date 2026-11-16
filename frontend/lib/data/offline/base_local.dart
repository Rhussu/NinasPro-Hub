import 'package:sembast/sembast.dart';

import 'base_local_stub.dart' if (dart.library.js_interop) 'base_local_web.dart';

/// Base local del dispositivo para la cola de sincronización: IndexedDB en el
/// navegador; en memoria en las pruebas y plataformas sin navegador.
Future<Database> abrirBaseLocal(String nombre) => abrirBaseLocalEnPlataforma(nombre);
