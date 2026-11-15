import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'almacen_compartido.dart';

AlmacenCompartido crearAlmacenDePlataforma() => AlmacenNavegador();

/// [AlmacenCompartido] sobre `localStorage` y el evento `storage` del navegador.
class AlmacenNavegador implements AlmacenCompartido {
  static const _claveIdPestana = 'ninaspro.pestana';

  final _cambios = StreamController<String>.broadcast();
  late final JSFunction _oyente;

  @override
  late final String idPestana;

  AlmacenNavegador() {
    final sesion = web.window.sessionStorage;
    idPestana = sesion.getItem(_claveIdPestana) ??
        'pestana-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    sesion.setItem(_claveIdPestana, idPestana);

    // El evento storage solo llega a las OTRAS pestañas del mismo origen
    _oyente = ((web.StorageEvent e) {
      final clave = e.key;
      if (clave != null) _cambios.add(clave);
    }).toJS;
    web.window.addEventListener('storage', _oyente);
  }

  @override
  String? leer(String clave) => web.window.localStorage.getItem(clave);

  @override
  void escribir(String clave, String? valor) {
    if (valor == null) {
      web.window.localStorage.removeItem(clave);
    } else {
      web.window.localStorage.setItem(clave, valor);
    }
  }

  @override
  Stream<String> get cambios => _cambios.stream;

  @override
  void limpiarUrl() {
    final ubicacion = web.window.location;
    web.window.history.replaceState(null, '', '${ubicacion.pathname}${ubicacion.hash}');
  }

  @override
  void dispose() {
    web.window.removeEventListener('storage', _oyente);
    _cambios.close();
  }
}
