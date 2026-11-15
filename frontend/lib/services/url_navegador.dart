import 'url_navegador_stub.dart' if (dart.library.js_interop) 'url_navegador_web.dart';

/// Quita de la barra de direcciones los parámetros del enlace del correo
/// (en la web; en otras plataformas no hace nada).
void limpiarUrlDelNavegador() => limpiarUrlDePlataforma();
