import 'dart:async';
import 'dart:math';

import 'almacen_compartido.dart';

AlmacenCompartido crearAlmacenDePlataforma() => AlmacenEnMemoria();

/// Datos compartidos por varias [AlmacenEnMemoria], como el `localStorage` de un navegador.
class MemoriaCompartida {
  final datos = <String, String>{};
  final _escrituras = StreamController<({String origen, String clave})>.broadcast();
}

/// [AlmacenCompartido] en memoria. Dos instancias con la misma [MemoriaCompartida]
/// se comportan como dos pestañas: cada una recibe en [cambios] lo que escribe la otra.
class AlmacenEnMemoria implements AlmacenCompartido {
  final MemoriaCompartida memoria;

  @override
  final String idPestana;

  int urlLimpiada = 0;

  AlmacenEnMemoria({MemoriaCompartida? memoria, String? idPestana})
      : memoria = memoria ?? MemoriaCompartida(),
        idPestana = idPestana ?? 'pestana-${Random().nextInt(1 << 32)}';

  @override
  String? leer(String clave) => memoria.datos[clave];

  @override
  void escribir(String clave, String? valor) {
    if (valor == null) {
      memoria.datos.remove(clave);
    } else {
      memoria.datos[clave] = valor;
    }
    memoria._escrituras.add((origen: idPestana, clave: clave));
  }

  @override
  Stream<String> get cambios =>
      memoria._escrituras.stream.where((e) => e.origen != idPestana).map((e) => e.clave);

  @override
  void limpiarUrl() => urlLimpiada++;

  @override
  void dispose() {}
}
