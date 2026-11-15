import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'almacen_compartido.dart';

/// Etapas de una recuperación de contraseña compartida entre pestañas.
enum FaseRecuperacion {
  /// Se pidió el correo; se espera que abran el enlace
  solicitada,

  /// Se abrió el enlace en otra pestaña; falta elegir dónde cambiar la contraseña
  enlaceAbierto,

  /// Una sola pestaña (la dueña) está cambiando la contraseña
  cambiando,

  /// La contraseña ya se cambió
  completada,
}

/// Estado de la recuperación guardado en el almacenamiento compartido.
@immutable
class EstadoRecuperacion {
  final FaseRecuperacion fase;
  final String? correo;

  /// Pestaña donde se pidió el correo y su último latido (ms desde epoch)
  final String? solicitante;
  final int latido;

  /// Pestaña que abrió el enlace del correo y el token del enlace (aún sin canjear)
  final String? enlaceAbiertoPor;
  final String? tokenHash;

  /// Única pestaña que puede canjear el token y mostrar el formulario
  final String? duenia;

  const EstadoRecuperacion({
    required this.fase,
    this.correo,
    this.solicitante,
    this.latido = 0,
    this.enlaceAbiertoPor,
    this.tokenHash,
    this.duenia,
  });

  EstadoRecuperacion copiar({
    FaseRecuperacion? fase,
    int? latido,
    String? enlaceAbiertoPor,
    String? Function()? tokenHash,
    String? Function()? duenia,
  }) {
    return EstadoRecuperacion(
      fase: fase ?? this.fase,
      correo: correo,
      solicitante: solicitante,
      latido: latido ?? this.latido,
      enlaceAbiertoPor: enlaceAbiertoPor ?? this.enlaceAbiertoPor,
      tokenHash: tokenHash != null ? tokenHash() : this.tokenHash,
      duenia: duenia != null ? duenia() : this.duenia,
    );
  }

  Map<String, dynamic> toJson() => {
        'fase': fase.name,
        'correo': correo,
        'solicitante': solicitante,
        'latido': latido,
        'enlaceAbiertoPor': enlaceAbiertoPor,
        'tokenHash': tokenHash,
        'duenia': duenia,
      };

  static EstadoRecuperacion? fromJson(String? texto) {
    if (texto == null) return null;
    try {
      final m = jsonDecode(texto) as Map<String, dynamic>;
      return EstadoRecuperacion(
        fase: FaseRecuperacion.values.byName(m['fase'] as String),
        correo: m['correo'] as String?,
        solicitante: m['solicitante'] as String?,
        latido: (m['latido'] as num?)?.toInt() ?? 0,
        enlaceAbiertoPor: m['enlaceAbiertoPor'] as String?,
        tokenHash: m['tokenHash'] as String?,
        duenia: m['duenia'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Coordina la recuperación de contraseña entre la pestaña donde se pidió el
/// correo y la pestaña que abre el enlace, para que solo una de ellas canjee el
/// enlace y muestre el formulario de contraseña nueva.
class CoordinadorRecuperacion {
  static const clave = 'ninaspro.recuperacion';

  final AlmacenCompartido almacen;
  final Duration intervaloLatido;
  final DateTime Function() _ahora;

  Timer? _temporizador;

  CoordinadorRecuperacion(
    this.almacen, {
    this.intervaloLatido = const Duration(seconds: 2),
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now {
    _programarLatido();
  }

  String get idPestana => almacen.idPestana;

  EstadoRecuperacion? get estado => EstadoRecuperacion.fromJson(almacen.leer(clave));

  /// Cambios hechos por otras pestañas
  Stream<void> get cambios => almacen.cambios.where((c) => c == clave);

  void _guardar(EstadoRecuperacion? e) => almacen.escribir(clave, e == null ? null : jsonEncode(e.toJson()));

  int get _ms => _ahora().millisecondsSinceEpoch;

  /// Esta pestaña pidió el correo de recuperación
  void registrarSolicitud(String correo) {
    _guardar(EstadoRecuperacion(
      fase: FaseRecuperacion.solicitada,
      correo: correo.trim().toLowerCase(),
      solicitante: idPestana,
      latido: _ms,
    ));
    _programarLatido();
  }

  /// Esta pestaña se abrió desde el enlace del correo
  void registrarEnlace(String tokenHash) {
    final previo = estado;
    final mismaPestana = previo?.solicitante == idPestana;
    _guardar(EstadoRecuperacion(
      // Si el enlace se abrió en la misma pestaña donde se pidió, se cambia ahí mismo
      fase: mismaPestana ? FaseRecuperacion.cambiando : FaseRecuperacion.enlaceAbierto,
      correo: previo?.correo,
      solicitante: previo?.fase == FaseRecuperacion.completada ? null : previo?.solicitante,
      latido: previo?.latido ?? 0,
      enlaceAbiertoPor: idPestana,
      tokenHash: tokenHash,
      duenia: mismaPestana ? idPestana : null,
    ));
  }

  /// La pestaña donde se pidió el correo sigue abierta (y no es esta)
  bool get solicitanteActivo {
    final e = estado;
    if (e == null || e.solicitante == null || e.solicitante == idPestana) return false;
    return _ms - e.latido < intervaloLatido.inMilliseconds * 3;
  }

  /// Entrega el cambio de contraseña a una sola pestaña
  void elegirDuenia(String pestana) {
    final e = estado;
    if (e == null) return;
    _guardar(e.copiar(fase: FaseRecuperacion.cambiando, duenia: () => pestana));
  }

  /// El token ya se canjeó: no debe quedar a la vista en el almacenamiento
  void olvidarToken() {
    final e = estado;
    if (e == null || e.tokenHash == null) return;
    _guardar(e.copiar(tokenHash: () => null));
  }

  void completar() {
    final e = estado;
    if (e == null) return;
    _guardar(e.copiar(fase: FaseRecuperacion.completada, tokenHash: () => null));
  }

  void limpiar() => _guardar(null);

  /// La pestaña solicitante avisa que sigue abierta mientras se espera el enlace
  void _programarLatido() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(intervaloLatido, (_) {
      final e = estado;
      final esperando = e != null &&
          e.solicitante == idPestana &&
          (e.fase == FaseRecuperacion.solicitada || e.fase == FaseRecuperacion.enlaceAbierto);
      if (esperando) {
        _guardar(e.copiar(latido: _ms));
      } else {
        _temporizador?.cancel();
        _temporizador = null;
      }
    });
  }

  void dispose() => _temporizador?.cancel();
}
