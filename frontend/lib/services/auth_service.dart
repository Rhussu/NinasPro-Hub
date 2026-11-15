import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sesion_usuario.dart';
import 'almacen_compartido.dart';
import 'coordinador_recuperacion.dart';

/// Etapas del ciclo de autenticación que la app debe mostrar.
enum EtapaAuth {
  /// Restaurando la sesión guardada al abrir la app
  iniciando,

  /// Sin sesión: se muestra el acceso (login / crear cuenta / recuperar)
  sinSesion,

  /// Sesión activa con perfil cargado
  conSesion,

  /// Se envió el correo de recuperación; se espera que abran el enlace
  correoEnviado,

  /// Esta pestaña se abrió desde el enlace: elegir dónde cambiar la contraseña
  enlaceRecuperacion,

  /// Esta pestaña es la única que muestra el formulario de contraseña nueva
  recuperandoContrasena,

  /// Otra pestaña está cambiando la contraseña
  esperandoOtraPestana,
}

@immutable
class EstadoAuth {
  final EtapaAuth etapa;
  final SesionUsuario? sesion;

  /// Aviso para la pantalla de acceso (ej. cuenta bloqueada o enlace vencido)
  final String? aviso;

  /// Correo de la recuperación en curso
  final String? correo;

  /// [EtapaAuth.enlaceRecuperacion]: la pestaña donde se pidió el correo sigue abierta
  final bool otraPestanaDisponible;

  /// [EtapaAuth.esperandoOtraPestana]: esta es la pestaña del enlace y la otra cambia la contraseña
  final bool soyPestanaDelEnlace;

  const EstadoAuth(
    this.etapa, {
    this.sesion,
    this.aviso,
    this.correo,
    this.otraPestanaDisponible = false,
    this.soyPestanaDelEnlace = false,
  });

  static const iniciando = EstadoAuth(EtapaAuth.iniciando);

  @override
  bool operator ==(Object other) =>
      other is EstadoAuth &&
      other.etapa == etapa &&
      other.sesion?.perfilId == sesion?.perfilId &&
      other.sesion?.rol == sesion?.rol &&
      other.aviso == aviso &&
      other.correo == correo &&
      other.otraPestanaDisponible == otraPestanaDisponible &&
      other.soyPestanaDelEnlace == soyPestanaDelEnlace;

  @override
  int get hashCode =>
      Object.hash(etapa, sesion?.perfilId, sesion?.rol, aviso, correo, otraPestanaDisponible, soyPestanaDelEnlace);
}

/// Resultado de una operación de autenticación, con un mensaje listo para mostrar.
@immutable
class ResultadoAuth {
  final bool ok;
  final String? mensaje;

  const ResultadoAuth.ok([this.mensaje]) : ok = true;
  const ResultadoAuth.error(this.mensaje) : ok = false;
}

/// Contrato de autenticación de NiñasPro Hub.
///
/// El registro es cerrado: solo puede crear su cuenta quien tenga su correo
/// autorizado previamente por la Directiva o el Equipo de Gestión (US-04, US-05).
/// Una sesión obtenida con el enlace de recuperación nunca cuenta como sesión
/// iniciada: primero hay que definir la contraseña nueva.
abstract class AuthService {
  ValueListenable<EstadoAuth> get estado;

  /// Restaura la sesión guardada, procesa el enlace del correo (si la app se
  /// abrió desde uno) y comienza a escuchar cambios de Auth y de otras pestañas
  Future<void> iniciar();

  Future<ResultadoAuth> iniciarSesion({required String correo, required String contrasena});

  /// Crea la cuenta de un correo autorizado. Queda activa al abrir el enlace del correo.
  Future<ResultadoAuth> crearCuenta({required String correo, required String contrasena});

  Future<ResultadoAuth> enviarRecuperacion({required String correo});

  /// Desde la pestaña del enlace: cambiar la contraseña en esta pestaña
  Future<void> cambiarContrasenaAqui();

  /// Desde la pestaña del enlace: cambiarla en la pestaña donde se pidió el correo
  Future<ResultadoAuth> cambiarContrasenaEnOtraPestana();

  /// Abandona la recuperación y vuelve al acceso
  Future<void> cancelarRecuperacion();

  /// Define la contraseña nueva (solo en la pestaña dueña de la recuperación)
  Future<ResultadoAuth> actualizarContrasena({required String contrasena});

  Future<void> cerrarSesion();

  void dispose();
}

/// Reglas de contraseña: las mismas que `config.toml` exige en Auth
/// (mínimo 10 caracteres con minúsculas, mayúsculas y dígitos).
String? validarContrasena(String contrasena) {
  if (contrasena.length < 10) return 'Usa al menos 10 caracteres.';
  if (!RegExp('[a-z]').hasMatch(contrasena)) return 'Incluye al menos una letra minúscula.';
  if (!RegExp('[A-Z]').hasMatch(contrasena)) return 'Incluye al menos una letra mayúscula.';
  if (!RegExp('[0-9]').hasMatch(contrasena)) return 'Incluye al menos un número.';
  return null;
}

String? validarCorreo(String correo) {
  final limpio = correo.trim();
  if (limpio.isEmpty) return 'Ingresa tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(limpio)) return 'Revisa el formato del correo.';
  return null;
}

const mensajeCuentaBloqueada =
    'Tu cuenta está bloqueada por 3 intentos fallidos. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
const mensajeEnlaceInvalido = 'El enlace ya se usó o venció. Pide uno nuevo.';

/// Traduce los errores de Supabase Auth a mensajes en español para la usuaria.
String mensajeErrorAuth(AuthException e) {
  final mensaje = e.message;
  // Mensajes propios de los hooks de la base (registro cerrado y bloqueo), ya en español
  if (mensaje.contains('autorizado') || mensaje.contains('bloqueada')) return mensaje;

  switch (e.code) {
    case 'invalid_credentials':
      return 'Correo o contraseña incorrectos.';
    case 'email_not_confirmed':
      return 'Confirma tu cuenta con el enlace que te enviamos por correo.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Ya existe una cuenta con este correo. Inicia sesión o recupera tu contraseña.';
    case 'weak_password':
      return 'La contraseña es muy débil: usa 10 caracteres o más, con mayúsculas, minúsculas y números.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Hiciste demasiados intentos. Espera un momento y vuelve a probar.';
    case 'same_password':
      return 'La contraseña nueva debe ser distinta de la anterior.';
    case 'otp_expired':
    case 'otp_disabled':
      return mensajeEnlaceInvalido;
  }
  if (e.statusCode == '403') return mensaje;
  return 'No pudimos completar la operación. Inténtalo nuevamente.';
}

/// Implementación sobre Supabase Auth + tablas `perfiles`, `usuarios_sedes` y `alumnas`.
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final CoordinadorRecuperacion _coordinador;
  final AlmacenCompartido _almacen;

  /// URL a la que vuelven los enlaces de activación y recuperación
  final String? redirectTo;

  /// URL con la que se abrió la app (para leer el enlace del correo)
  final Uri? urlInicial;

  final _estado = ValueNotifier<EstadoAuth>(EstadoAuth.iniciando);
  StreamSubscription<AuthState>? _suscripcionAuth;
  StreamSubscription<void>? _suscripcionPestanas;
  bool _canjeando = false;

  factory SupabaseAuthService(
    SupabaseClient client, {
    String? redirectTo,
    Uri? urlInicial,
    AlmacenCompartido? almacen,
    Duration intervaloLatido = const Duration(seconds: 2),
  }) {
    final a = almacen ?? crearAlmacenCompartido();
    return SupabaseAuthService._(
      client,
      a,
      CoordinadorRecuperacion(a, intervaloLatido: intervaloLatido),
      redirectTo: redirectTo,
      urlInicial: urlInicial,
    );
  }

  SupabaseAuthService._(this._client, this._almacen, this._coordinador, {this.redirectTo, this.urlInicial});

  @override
  ValueListenable<EstadoAuth> get estado => _estado;

  void _emitir(EstadoAuth e) => _estado.value = e;

  @override
  Future<void> iniciar() async {
    _suscripcionAuth ??= _client.auth.onAuthStateChange.listen(_alCambiarAuth, onError: (_) {});
    _suscripcionPestanas ??= _coordinador.cambios.listen((_) => _alCambiarOtraPestana());

    final url = urlInicial ?? Uri.base;
    final tokenHash = url.queryParameters['token_hash'];
    final tipo = url.queryParameters['type'];
    if (tokenHash != null) _almacen.limpiarUrl();

    if (tokenHash != null && tipo == 'email') {
      await _activarCuenta(tokenHash);
      return;
    }
    if (tokenHash != null && tipo == 'recovery') _coordinador.registrarEnlace(tokenHash);
    await _evaluar();
  }

  /// Decide la etapa a partir de la recuperación en curso y de la sesión guardada
  Future<void> _evaluar() async {
    final r = _coordinador.estado;
    final yo = _coordinador.idPestana;
    final participo = r != null && (r.solicitante == yo || r.enlaceAbiertoPor == yo);

    if (participo && r.fase != FaseRecuperacion.completada) {
      final soyEnlace = r.enlaceAbiertoPor == yo;
      switch (r.fase) {
        case FaseRecuperacion.solicitada:
          _emitir(EstadoAuth(EtapaAuth.correoEnviado, correo: r.correo));
          return;
        case FaseRecuperacion.enlaceAbierto:
          _emitir(soyEnlace
              ? EstadoAuth(
                  EtapaAuth.enlaceRecuperacion,
                  correo: r.correo,
                  otraPestanaDisponible: _coordinador.solicitanteActivo,
                )
              : EstadoAuth(EtapaAuth.esperandoOtraPestana, correo: r.correo));
          return;
        case FaseRecuperacion.cambiando:
          if (r.duenia == yo) {
            await _tomarRecuperacion(r);
          } else {
            _emitir(EstadoAuth(EtapaAuth.esperandoOtraPestana, correo: r.correo, soyPestanaDelEnlace: soyEnlace));
          }
          return;
        case FaseRecuperacion.completada:
          break;
      }
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      _emitir(EstadoAuth(EtapaAuth.sinSesion, aviso: _estado.value.aviso));
      return;
    }
    await _cargarSesion(user.id);
  }

  static const _etapasRecuperacion = {
    EtapaAuth.correoEnviado,
    EtapaAuth.enlaceRecuperacion,
    EtapaAuth.recuperandoContrasena,
    EtapaAuth.esperandoOtraPestana,
  };

  /// Otra pestaña cambió la recuperación: solo importa a las pestañas que participan en ella
  void _alCambiarOtraPestana() {
    final r = _coordinador.estado;
    final yo = _coordinador.idPestana;
    final participo = r != null && (r.solicitante == yo || r.enlaceAbiertoPor == yo);
    if (participo || _etapasRecuperacion.contains(_estado.value.etapa)) _evaluar();
  }

  /// Esta pestaña es la dueña: canjea el enlace (una sola vez) y muestra el formulario
  Future<void> _tomarRecuperacion(EstadoRecuperacion r) async {
    if (_estado.value.etapa == EtapaAuth.recuperandoContrasena || _canjeando) return;

    final token = r.tokenHash;
    if (token != null) {
      _canjeando = true;
      try {
        await _client.auth.verifyOTP(type: OtpType.recovery, tokenHash: token);
        _coordinador.olvidarToken();
      } on AuthException catch (e) {
        _coordinador.limpiar();
        _emitir(EstadoAuth(EtapaAuth.sinSesion, aviso: mensajeErrorAuth(e)));
        return;
      } finally {
        _canjeando = false;
      }
    } else if (_client.auth.currentUser == null) {
      // El enlace se canjeó y la sesión se perdió: hay que pedir uno nuevo
      _coordinador.limpiar();
      _emitir(const EstadoAuth(EtapaAuth.sinSesion, aviso: mensajeEnlaceInvalido));
      return;
    }
    _emitir(EstadoAuth(EtapaAuth.recuperandoContrasena, correo: r.correo ?? _client.auth.currentUser?.email));
  }

  Future<void> _activarCuenta(String tokenHash) async {
    try {
      final r = await _client.auth.verifyOTP(type: OtpType.email, tokenHash: tokenHash);
      final user = r.user;
      if (user != null) {
        await _cargarSesion(user.id);
        return;
      }
    } on AuthException catch (e) {
      _emitir(EstadoAuth(
        EtapaAuth.sinSesion,
        aviso: e.code == 'otp_expired' ? 'El enlace de activación ya se usó o venció. Intenta iniciar sesión.' : mensajeErrorAuth(e),
      ));
      return;
    }
    await _evaluar();
  }

  void _alCambiarAuth(AuthState cambio) {
    switch (cambio.event) {
      // Las sesiones nuevas (también las que llegan desde otra pestaña) se vuelven a evaluar:
      // una sesión de recuperación nunca entra directo a la app
      case AuthChangeEvent.signedIn:
        if (_estado.value.sesion?.perfilId != cambio.session?.user.id) _evaluar();
      case AuthChangeEvent.signedOut:
        _evaluar();
      // La recuperación la coordina la app (ver CoordinadorRecuperacion), no este evento
      default:
        break;
    }
  }

  // Login y el evento signedIn piden cargar el mismo perfil a la vez: se comparte la carga
  Future<void>? _cargaEnCurso;
  String? _cargaUserId;

  Future<void> _cargarSesion(String userId) {
    if (_cargaEnCurso != null && _cargaUserId == userId) return _cargaEnCurso!;
    _cargaUserId = userId;
    return _cargaEnCurso = _leerPerfil(userId).whenComplete(() {
      _cargaEnCurso = null;
      _cargaUserId = null;
    });
  }

  Future<void> _leerPerfil(String userId) async {
    try {
      // La base dice si la cuenta está bloqueada o a mitad de una recuperación
      final cuenta = await _client.rpc('estado_mi_cuenta') as Map<String, dynamic>?;
      if (cuenta?['bloqueada'] == true) {
        await _cerrarConAviso(mensajeCuentaBloqueada);
        return;
      }
      if (cuenta?['recuperacion_pendiente'] == true) {
        final r = _coordinador.estado;
        final yo = _coordinador.idPestana;
        // Solo espera una pestaña que participa en la recuperación; una pestaña nueva
        // (la dueña pudo cerrarse) toma el cambio de contraseña
        final otraEsDuenia = r != null &&
            r.fase == FaseRecuperacion.cambiando &&
            r.duenia != null &&
            r.duenia != yo &&
            (r.solicitante == yo || r.enlaceAbiertoPor == yo);
        if (otraEsDuenia) {
          _emitir(EstadoAuth(
            EtapaAuth.esperandoOtraPestana,
            correo: r.correo,
            soyPestanaDelEnlace: r.enlaceAbiertoPor == _coordinador.idPestana,
          ));
        } else {
          // Recarga o sesión sin coordinación: esta pestaña toma el cambio de contraseña
          if (r != null && r.fase != FaseRecuperacion.completada) _coordinador.elegirDuenia(_coordinador.idPestana);
          _emitir(EstadoAuth(EtapaAuth.recuperandoContrasena, correo: _client.auth.currentUser?.email));
        }
        return;
      }

      final perfil = await _client
          .from('perfiles')
          .select('id, nombres, apellidos, correo, rol, activo, usuarios_sedes(sede_id, es_lider_sede, sedes(nombre))')
          .eq('id', userId)
          .maybeSingle();

      if (perfil == null || perfil['activo'] != true) {
        await _cerrarConAviso('Tu cuenta no tiene un perfil activo. Contacta a tu sede.');
        return;
      }

      final rol = RolUsuario.desdeDb(perfil['rol'] as String);
      final sedes = [
        for (final us in (perfil['usuarios_sedes'] as List? ?? const []).cast<Map<String, dynamic>>())
          SedeAsignada(
            id: us['sede_id'] as String,
            nombre: (us['sedes'] as Map<String, dynamic>?)?['nombre'] as String? ?? '',
            esLider: us['es_lider_sede'] == true,
          ),
      ];

      String? alumnaId;
      if (rol == RolUsuario.alumna) {
        final alumna = await _client.from('alumnas').select('id').eq('perfil_usuario_id', userId).maybeSingle();
        alumnaId = alumna?['id'] as String?;
        if (alumnaId == null) {
          await _cerrarConAviso('Tu cuenta no está vinculada a una ficha de alumna. Contacta a tu sede.');
          return;
        }
      }

      _emitir(EstadoAuth(
        EtapaAuth.conSesion,
        sesion: SesionUsuario(
          perfilId: perfil['id'] as String,
          rol: rol,
          nombres: perfil['nombres'] as String,
          apellidos: perfil['apellidos'] as String,
          correo: perfil['correo'] as String,
          sedes: sedes,
          alumnaId: alumnaId,
        ),
      ));
    } on PostgrestException {
      await _cerrarConAviso('No pudimos cargar tu perfil. Revisa tu conexión e inténtalo nuevamente.');
    }
  }

  Future<void> _cerrarConAviso(String aviso) async {
    _emitir(EstadoAuth(EtapaAuth.sinSesion, aviso: aviso));
    try {
      await _client.auth.signOut();
    } on AuthException {
      // La sesión local ya se descartó
    }
  }

  @override
  Future<ResultadoAuth> iniciarSesion({required String correo, required String contrasena}) async {
    try {
      final r = await _client.auth.signInWithPassword(email: correo.trim().toLowerCase(), password: contrasena);
      final user = r.user;
      if (user != null) await _cargarSesion(user.id);
      final aviso = _estado.value.aviso;
      return _estado.value.etapa == EtapaAuth.conSesion ? const ResultadoAuth.ok() : ResultadoAuth.error(aviso);
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<ResultadoAuth> crearCuenta({required String correo, required String contrasena}) async {
    try {
      final r = await _client.auth.signUp(
        email: correo.trim().toLowerCase(),
        password: contrasena,
        emailRedirectTo: redirectTo,
      );
      // Con confirmación de correo activa Auth no devuelve sesión hasta abrir el enlace
      if (r.session == null) {
        return const ResultadoAuth.ok('Te enviamos un correo para activar tu cuenta. Abre el enlace para terminar.');
      }
      return const ResultadoAuth.ok();
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<ResultadoAuth> enviarRecuperacion({required String correo}) async {
    try {
      await _client.auth.resetPasswordForEmail(correo.trim().toLowerCase(), redirectTo: redirectTo);
      _coordinador.registrarSolicitud(correo);
      await _evaluar();
      return const ResultadoAuth.ok();
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<void> cambiarContrasenaAqui() async {
    _coordinador.elegirDuenia(_coordinador.idPestana);
    await _evaluar();
  }

  @override
  Future<ResultadoAuth> cambiarContrasenaEnOtraPestana() async {
    final r = _coordinador.estado;
    if (r == null || r.solicitante == null || !_coordinador.solicitanteActivo) {
      await _evaluar();
      return const ResultadoAuth.error('La pestaña donde pediste el cambio ya no está abierta. Cámbiala aquí.');
    }
    _coordinador.elegirDuenia(r.solicitante!);
    await _evaluar();
    return const ResultadoAuth.ok();
  }

  @override
  Future<void> cancelarRecuperacion() async {
    _coordinador.limpiar();
    _emitir(const EstadoAuth(EtapaAuth.sinSesion));
    if (_client.auth.currentUser != null) {
      try {
        await _client.auth.signOut();
      } on AuthException {
        // La sesión local ya se descartó
      }
    }
  }

  @override
  Future<ResultadoAuth> actualizarContrasena({required String contrasena}) async {
    if (_estado.value.etapa != EtapaAuth.recuperandoContrasena) {
      return const ResultadoAuth.error('La contraseña se está cambiando en otra pestaña.');
    }
    try {
      final r = await _client.auth.updateUser(UserAttributes(password: contrasena));
      // La base cierra la recuperación y desbloquea la cuenta al cambiar la contraseña
      _coordinador.completar();
      final user = r.user;
      if (user != null) await _cargarSesion(user.id);
      return const ResultadoAuth.ok('Tu contraseña quedó actualizada.');
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<void> cerrarSesion() async {
    _coordinador.limpiar();
    _emitir(const EstadoAuth(EtapaAuth.sinSesion));
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _suscripcionAuth?.cancel();
    _suscripcionPestanas?.cancel();
    _coordinador.dispose();
    _estado.dispose();
  }
}
