import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sesion_usuario.dart';

/// Etapas del ciclo de autenticación que la app debe mostrar.
enum EtapaAuth {
  /// Restaurando la sesión guardada al abrir la app
  iniciando,

  /// Sin sesión: se muestra el acceso (login / crear cuenta)
  sinSesion,

  /// Sesión activa con perfil cargado
  conSesion,

  /// Llegó desde el enlace de recuperación: debe definir una contraseña nueva
  recuperandoContrasena,
}

@immutable
class EstadoAuth {
  final EtapaAuth etapa;
  final SesionUsuario? sesion;

  /// Aviso para la pantalla de acceso (ej. cuenta sin perfil activo)
  final String? aviso;

  const EstadoAuth(this.etapa, {this.sesion, this.aviso});

  static const iniciando = EstadoAuth(EtapaAuth.iniciando);
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
abstract class AuthService {
  ValueListenable<EstadoAuth> get estado;

  /// Restaura la sesión guardada y comienza a escuchar cambios de Auth
  Future<void> iniciar();

  Future<ResultadoAuth> iniciarSesion({required String correo, required String contrasena});

  /// Crea la cuenta de un correo autorizado. Queda activa al confirmar el enlace del correo.
  Future<ResultadoAuth> crearCuenta({required String correo, required String contrasena});

  Future<ResultadoAuth> enviarRecuperacion({required String correo});

  /// Define la contraseña nueva tras abrir el enlace de recuperación
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
  }
  if (e.statusCode == '403') return mensaje;
  return 'No pudimos completar la operación. Inténtalo nuevamente.';
}

/// Implementación sobre Supabase Auth + tablas `perfiles`, `usuarios_sedes` y `alumnas`.
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;

  /// URL a la que vuelven los enlaces de confirmación y recuperación
  final String? redirectTo;

  final _estado = ValueNotifier<EstadoAuth>(EstadoAuth.iniciando);
  StreamSubscription<AuthState>? _suscripcion;

  SupabaseAuthService(this._client, {this.redirectTo});

  @override
  ValueListenable<EstadoAuth> get estado => _estado;

  @override
  Future<void> iniciar() async {
    _suscripcion ??= _client.auth.onAuthStateChange.listen(_alCambiarAuth, onError: (_) {});
    final user = _client.auth.currentUser;
    if (user == null) {
      _estado.value = const EstadoAuth(EtapaAuth.sinSesion);
    } else {
      await _cargarSesion(user.id);
    }
  }

  Future<void> _alCambiarAuth(AuthState cambio) async {
    switch (cambio.event) {
      case AuthChangeEvent.passwordRecovery:
        _estado.value = EstadoAuth(EtapaAuth.recuperandoContrasena, sesion: _estado.value.sesion);
      case AuthChangeEvent.signedIn:
        // Durante la recuperación también llega signedIn: se mantiene la pantalla de contraseña nueva
        if (_estado.value.etapa == EtapaAuth.recuperandoContrasena) return;
        final user = cambio.session?.user;
        if (user != null && _estado.value.sesion?.perfilId != user.id) await _cargarSesion(user.id);
      case AuthChangeEvent.signedOut:
        _estado.value = EstadoAuth(EtapaAuth.sinSesion, aviso: _estado.value.aviso);
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

      _estado.value = EstadoAuth(
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
      );
    } on PostgrestException {
      await _cerrarConAviso('No pudimos cargar tu perfil. Revisa tu conexión e inténtalo nuevamente.');
    }
  }

  Future<void> _cerrarConAviso(String aviso) async {
    _estado.value = EstadoAuth(EtapaAuth.sinSesion, aviso: aviso);
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
      return const ResultadoAuth.ok(
        'Si el correo tiene una cuenta, te enviamos un enlace para crear una contraseña nueva.',
      );
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<ResultadoAuth> actualizarContrasena({required String contrasena}) async {
    try {
      final r = await _client.auth.updateUser(UserAttributes(password: contrasena));
      final user = r.user;
      if (user != null) await _cargarSesion(user.id);
      return const ResultadoAuth.ok('Tu contraseña quedó actualizada.');
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<void> cerrarSesion() async {
    _estado.value = const EstadoAuth(EtapaAuth.sinSesion);
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _estado.dispose();
  }
}
