import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sesion_usuario.dart';
import 'url_navegador.dart';

/// Etapas del ciclo de autenticación que la app debe mostrar.
enum EtapaAuth {
  /// Restaurando la sesión guardada al abrir la app
  iniciando,

  /// Sin sesión: se muestra el acceso (login / crear cuenta / recuperar)
  sinSesion,

  /// Sesión activa con perfil cargado
  conSesion,

  /// Se envió el código de recuperación al correo; se espera que lo ingresen
  codigoEnviado,

  /// El código se verificó: falta definir la contraseña nueva
  recuperandoContrasena,

  /// La Directiva debe verificar su segundo factor (o inscribirlo la primera vez)
  verificandoMfa,
}

@immutable
class EstadoAuth {
  final EtapaAuth etapa;
  final SesionUsuario? sesion;

  /// Aviso para la pantalla de acceso (ej. cuenta bloqueada o enlace vencido)
  final String? aviso;

  /// Correo de la recuperación en curso o de la cuenta que verifica su segundo factor
  final String? correo;

  /// [EtapaAuth.verificandoMfa]: ya tiene un autenticador inscrito (si no, hay que inscribirlo)
  final bool mfaInscrita;

  const EstadoAuth(this.etapa, {this.sesion, this.aviso, this.correo, this.mfaInscrita = false});

  static const iniciando = EstadoAuth(EtapaAuth.iniciando);

  @override
  bool operator ==(Object other) =>
      other is EstadoAuth &&
      other.etapa == etapa &&
      other.sesion?.perfilId == sesion?.perfilId &&
      other.sesion?.rol == sesion?.rol &&
      other.aviso == aviso &&
      other.correo == correo &&
      other.mfaInscrita == mfaInscrita;

  @override
  int get hashCode => Object.hash(etapa, sesion?.perfilId, sesion?.rol, aviso, correo, mfaInscrita);
}

/// Datos para inscribir el autenticador (TOTP) de la Directiva.
@immutable
class InscripcionMfa {
  /// URI `otpauth://` que se muestra como código QR
  final String uri;

  /// Clave para ingresarla a mano si no se puede escanear el QR
  final String secreto;

  const InscripcionMfa({required this.uri, required this.secreto});
}

/// Falla de una operación de autenticación, con un mensaje listo para mostrar.
class ErrorAuth implements Exception {
  final String mensaje;

  const ErrorAuth(this.mensaje);

  @override
  String toString() => mensaje;
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
/// La recuperación se hace con un código que llega al correo y se ingresa en la
/// misma pantalla donde se pidió. La sesión que da el código nunca cuenta como
/// sesión iniciada: primero hay que definir la contraseña nueva.
abstract class AuthService {
  ValueListenable<EstadoAuth> get estado;

  /// Restaura la sesión guardada, procesa el enlace de activación (si la app se
  /// abrió desde uno) y comienza a escuchar cambios de Auth
  Future<void> iniciar();

  Future<ResultadoAuth> iniciarSesion({required String correo, required String contrasena});

  /// Crea la cuenta de un correo autorizado. Queda activa al abrir el enlace del correo.
  Future<ResultadoAuth> crearCuenta({required String correo, required String contrasena});

  /// Envía (o reenvía) el código de recuperación al correo
  Future<ResultadoAuth> enviarRecuperacion({required String correo});

  /// Verifica el código del correo; si es correcto, pasa a definir la contraseña nueva
  Future<ResultadoAuth> verificarCodigo({required String codigo});

  /// Abandona la recuperación y vuelve al acceso
  Future<void> cancelarRecuperacion();

  /// Define la contraseña nueva después de verificar el código
  Future<ResultadoAuth> actualizarContrasena({required String contrasena});

  /// Prepara la inscripción del autenticador de la Directiva. Lanza [ErrorAuth] si falla.
  Future<InscripcionMfa> iniciarInscripcionMfa();

  /// Verifica el código de 6 dígitos del autenticador; si es correcto, entra a la app
  Future<ResultadoAuth> verificarMfa({required String codigo});

  Future<void> cerrarSesion();

  void dispose();
}

/// Largo del código de recuperación: el mismo `otp_length` de `config.toml`
const largoCodigo = 6;

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

/// El código se puede pegar con espacios (ej. "123 456"); se valida sin ellos
String limpiarCodigo(String codigo) => codigo.replaceAll(RegExp(r'\s'), '');

String? validarCodigo(String codigo) {
  final limpio = limpiarCodigo(codigo);
  if (limpio.isEmpty) return 'Ingresa el código que te enviamos.';
  if (!RegExp('^[0-9]{$largoCodigo}\$').hasMatch(limpio)) return 'El código tiene $largoCodigo números.';
  return null;
}

const mensajeCuentaBloqueada =
    'Tu cuenta está bloqueada por 3 intentos fallidos. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
const mensajeEnlaceInvalido = 'El enlace ya se usó o venció. Pide uno nuevo.';
const mensajeCodigoInvalido = 'El código no es correcto o ya venció. Revísalo o pide uno nuevo.';
const mensajeMfaInvalido = 'El código no es correcto. Revisa que la hora de tu teléfono esté al día o espera el siguiente código.';

/// El hook de Auth avisa así el intento que acaba de bloquear la cuenta (ver migración 08)
bool esBloqueoNuevo(String mensaje) => mensaje.contains('quedó bloqueada');

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

  /// URL a la que vuelve el enlace de activación de la cuenta
  final String? redirectTo;

  /// URL con la que se abrió la app (para leer el enlace de activación)
  final Uri? urlInicial;

  /// Quita el token del enlace de la barra de direcciones
  final void Function() _limpiarUrl;

  final _estado = ValueNotifier<EstadoAuth>(EstadoAuth.iniciando);
  StreamSubscription<AuthState>? _suscripcion;

  SupabaseAuthService(
    this._client, {
    this.redirectTo,
    this.urlInicial,
    void Function()? limpiarUrl,
  }) : _limpiarUrl = limpiarUrl ?? limpiarUrlDelNavegador;

  @override
  ValueListenable<EstadoAuth> get estado => _estado;

  void _emitir(EstadoAuth e) => _estado.value = e;

  @override
  Future<void> iniciar() async {
    _suscripcion ??= _client.auth.onAuthStateChange.listen(_alCambiarAuth, onError: (_) {});

    final url = urlInicial ?? Uri.base;
    final tokenHash = url.queryParameters['token_hash'];
    if (tokenHash != null) {
      _limpiarUrl();
      if (url.queryParameters['type'] == 'email') {
        await _activarCuenta(tokenHash);
        return;
      }
    }
    await _evaluar();
  }

  /// Decide la etapa a partir de la sesión guardada
  Future<void> _evaluar() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Esperando el código todavía no hay sesión: no se sale de esa pantalla
      if (_estado.value.etapa == EtapaAuth.codigoEnviado) return;
      _emitir(EstadoAuth(EtapaAuth.sinSesion, aviso: _estado.value.aviso));
      return;
    }
    await _cargarSesion(user.id);
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
      // El segundo factor se verificó en otra pestaña
      case AuthChangeEvent.mfaChallengeVerified:
        if (_estado.value.etapa == EtapaAuth.verificandoMfa) _evaluar();
      // verificarCodigo ya pasa a la contraseña nueva
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
        // Recarga u otra pestaña con la sesión del código: primero la contraseña nueva
        _emitir(EstadoAuth(EtapaAuth.recuperandoContrasena, correo: _client.auth.currentUser?.email));
        return;
      }
      if (cuenta?['mfa_requerida'] == true) {
        // Sin el segundo factor la base no entrega datos a la Directiva
        _emitir(EstadoAuth(
          EtapaAuth.verificandoMfa,
          correo: _client.auth.currentUser?.email,
          mfaInscrita: cuenta?['mfa_inscrita'] == true,
        ));
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
      final etapa = _estado.value.etapa;
      if (etapa == EtapaAuth.conSesion || etapa == EtapaAuth.verificandoMfa) return const ResultadoAuth.ok();
      return ResultadoAuth.error(_estado.value.aviso);
    } on AuthException catch (e) {
      final mensaje = mensajeErrorAuth(e);
      // El tercer fallo bloqueó la cuenta: se envía en ese momento el código para desbloquearla (US-06)
      if (esBloqueoNuevo(e.message)) {
        final limpio = correo.trim().toLowerCase();
        final envio = await enviarRecuperacion(correo: limpio);
        if (envio.ok) _emitir(EstadoAuth(EtapaAuth.codigoEnviado, correo: limpio, aviso: e.message));
      }
      return ResultadoAuth.error(mensaje);
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
    final limpio = correo.trim().toLowerCase();
    try {
      await _client.auth.resetPasswordForEmail(limpio);
      _emitir(EstadoAuth(EtapaAuth.codigoEnviado, correo: limpio));
      return const ResultadoAuth.ok();
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  @override
  Future<ResultadoAuth> verificarCodigo({required String codigo}) async {
    final correo = _estado.value.correo;
    if (_estado.value.etapa != EtapaAuth.codigoEnviado || correo == null) {
      return const ResultadoAuth.error('Pide un código nuevo para continuar.');
    }
    try {
      final r = await _client.auth.verifyOTP(type: OtpType.recovery, email: correo, token: limpiarCodigo(codigo));
      if (r.session == null) return const ResultadoAuth.error(mensajeCodigoInvalido);
      // Aunque la cuenta esté bloqueada se sigue: la contraseña nueva la desbloquea
      _emitir(EstadoAuth(EtapaAuth.recuperandoContrasena, correo: correo));
      return const ResultadoAuth.ok();
    } on AuthException catch (e) {
      return ResultadoAuth.error(e.code == 'otp_expired' ? mensajeCodigoInvalido : mensajeErrorAuth(e));
    }
  }

  @override
  Future<void> cancelarRecuperacion() async {
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
      return const ResultadoAuth.error('Verifica primero el código que te enviamos.');
    }
    try {
      final r = await _client.auth.updateUser(UserAttributes(password: contrasena));
      // La base cierra la recuperación y desbloquea la cuenta al cambiar la contraseña
      final user = r.user;
      if (user != null) await _cargarSesion(user.id);
      return const ResultadoAuth.ok('Tu contraseña quedó actualizada.');
    } on AuthException catch (e) {
      return ResultadoAuth.error(mensajeErrorAuth(e));
    }
  }

  /// Factor TOTP recién inscrito, a la espera de su primer código
  String? _factorPendiente;

  @override
  Future<InscripcionMfa> iniciarInscripcionMfa() async {
    try {
      // Un intento de inscripción abandonado deja un factor sin verificar con el mismo nombre
      final factores = await _client.auth.mfa.listFactors();
      for (final f in factores.all) {
        if (f.factorType == FactorType.totp && f.status != FactorStatus.verified) {
          await _client.auth.mfa.unenroll(f.id);
        }
      }
      final r = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'NiñasPro Hub',
        friendlyName: 'NiñasPro Hub',
      );
      final totp = r.totp;
      if (totp == null) throw const ErrorAuth('No pudimos preparar el autenticador. Inténtalo nuevamente.');
      _factorPendiente = r.id;
      return InscripcionMfa(uri: totp.uri, secreto: totp.secret);
    } on AuthException catch (e) {
      throw ErrorAuth(mensajeErrorAuth(e));
    }
  }

  @override
  Future<ResultadoAuth> verificarMfa({required String codigo}) async {
    if (_estado.value.etapa != EtapaAuth.verificandoMfa) {
      return const ResultadoAuth.error('Inicia sesión nuevamente.');
    }
    try {
      final String? factorId;
      if (_estado.value.mfaInscrita) {
        final factores = await _client.auth.mfa.listFactors();
        factorId = factores.totp.firstOrNull?.id;
      } else {
        factorId = _factorPendiente;
      }
      if (factorId == null) return const ResultadoAuth.error('Vuelve a escanear el código QR para inscribir tu autenticador.');

      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: limpiarCodigo(codigo));
      _factorPendiente = null;
      final user = _client.auth.currentUser;
      if (user != null) await _cargarSesion(user.id);
      return const ResultadoAuth.ok();
    } on AuthException catch (e) {
      return ResultadoAuth.error(
        e.code == 'mfa_verification_failed' || e.code == 'mfa_challenge_expired' ? mensajeMfaInvalido : mensajeErrorAuth(e),
      );
    }
  }

  @override
  Future<void> cerrarSesion() async {
    _emitir(const EstadoAuth(EtapaAuth.sinSesion));
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _estado.dispose();
  }
}
