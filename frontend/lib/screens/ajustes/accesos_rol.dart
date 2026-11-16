import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/ninaspro_ajustes.dart';

/// Ajustes como acceso a todo lo de cada perfil (PR 8).
///
/// La pantalla principal de cada rol es un resumen con accesos rápidos
/// (tarjetas y Speed Dial). Para que Ajustes llegue a todo lo que el rol puede
/// ver o hacer sin copiar pantallas, cada pantalla principal registra en
/// [RegistroAccesos] las mismas acciones que usan sus tarjetas y su Speed Dial,
/// y Ajustes las dibuja con [AjustesAccesos].

/// Una entrada de Ajustes que abre una vista del rol.
@immutable
class AccesoRol {
  final IconData icono;
  final String titulo;
  final String? subtitulo;

  /// Abre la vista; null si necesita la conexión y no la hay (se explica con [sinConexion])
  final FutureOr<void> Function()? abrir;
  final String sinConexion;

  const AccesoRol({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.abrir,
    this.sinConexion = 'Necesita la conexión con la base de datos.',
  });
}

/// Grupo de entradas con su título (ej. "La clase de hoy")
@immutable
class SeccionAccesos {
  final String titulo;
  final List<AccesoRol> accesos;

  const SeccionAccesos(this.titulo, this.accesos);
}

typedef ConstructorAccesos = List<SeccionAccesos> Function();

/// Puente entre la pantalla principal del rol y sus Ajustes.
///
/// La pantalla principal registra cómo armar sus secciones (con su estado y sus
/// acciones) y avisa cuando cambian; Ajustes las lee al dibujarse.
class RegistroAccesos extends ChangeNotifier {
  ConstructorAccesos? _constructor;

  List<SeccionAccesos> get secciones => _constructor?.call() ?? const [];

  void registrar(ConstructorAccesos constructor) => _constructor = constructor;

  /// Se llama al desmontar la pantalla principal; no avisa porque el árbol se está cerrando
  void retirar(ConstructorAccesos constructor) {
    if (_constructor == constructor) _constructor = null;
  }

  /// El estado de la pantalla principal cambió (curso elegido, pendientes…)
  void avisar() => notifyListeners();
}

/// Las secciones registradas, cada una con [AjustesSeccion] y sus [AjustesTile]
class AjustesAccesos extends StatelessWidget {
  final RegistroAccesos registro;

  const AjustesAccesos({super.key, required this.registro});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registro,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final seccion in registro.secciones)
            if (seccion.accesos.isNotEmpty) SeccionAccesosAjustes(seccion: seccion),
        ],
      ),
    );
  }
}

/// Una [SeccionAccesos] dibujada como sección de Ajustes
class SeccionAccesosAjustes extends StatelessWidget {
  final SeccionAccesos seccion;

  const SeccionAccesosAjustes({super.key, required this.seccion});

  @override
  Widget build(BuildContext context) {
    return AjustesSeccion(
      titulo: seccion.titulo,
      children: [
        for (final acceso in seccion.accesos)
          switch (acceso.abrir) {
            final abrir? => AjustesTile(
              icono: acceso.icono,
              titulo: acceso.titulo,
              subtitulo: acceso.subtitulo,
              onTap: () => abrir(),
            ),
            // Sin conexión la entrada se explica en vez de esconderse
            null => AjustesTile(
              icono: acceso.icono,
              titulo: acceso.titulo,
              subtitulo: acceso.sinConexion,
              trailing: const Icon(Icons.cloud_off_rounded, size: 18),
            ),
          },
      ],
    );
  }
}
