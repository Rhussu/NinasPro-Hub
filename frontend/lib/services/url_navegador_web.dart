import 'package:web/web.dart' as web;

void limpiarUrlDePlataforma() {
  final ubicacion = web.window.location;
  web.window.history.replaceState(null, '', '${ubicacion.pathname}${ubicacion.hash}');
}
