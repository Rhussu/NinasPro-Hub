import 'almacen_compartido_memoria.dart'
    if (dart.library.js_interop) 'almacen_compartido_web.dart';

/// Almacenamiento compartido entre las pestañas abiertas de la app.
///
/// En la web usa `localStorage` (compartido por todas las pestañas del mismo
/// origen) y el evento `storage` para enterarse de lo que escriben las otras.
/// El id de la pestaña vive en `sessionStorage`, así que se mantiene al recargar.
abstract class AlmacenCompartido {
  /// Identifica a esta pestaña; se conserva al recargar la página
  String get idPestana;

  String? leer(String clave);

  /// Escribe (o borra, con null) y avisa a las demás pestañas
  void escribir(String clave, String? valor);

  /// Claves que cambiaron en otra pestaña
  Stream<String> get cambios;

  /// Quita de la barra de direcciones los parámetros del enlace del correo
  void limpiarUrl();

  void dispose();
}

/// Almacenamiento del navegador en la web; en memoria en otras plataformas y en tests.
AlmacenCompartido crearAlmacenCompartido() => crearAlmacenDePlataforma();
