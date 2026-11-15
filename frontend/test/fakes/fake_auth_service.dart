import 'package:flutter/foundation.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/services/auth_service.dart';

/// Sesiones de ejemplo por rol, con los mismos nombres del seed y del mock.
class SesionesDemo {
  static const directiva = SesionUsuario(
    perfilId: 'perfil-directiva',
    rol: RolUsuario.directorio,
    nombres: 'Directiva',
    apellidos: 'Nacional',
    correo: 'directiva@ninaspro.cl',
  );

  static const gestion = SesionUsuario(
    perfilId: 'perfil-camila',
    rol: RolUsuario.equipoGestion,
    nombres: 'Camila',
    apellidos: 'Sepúlveda Rivas',
    correo: 'camila.sepulveda@ninaspro.cl',
    sedes: [SedeAsignada(id: 'sede-beauchef', nombre: 'Sede Beauchef', esLider: true)],
  );

  static const tutora = SesionUsuario(
    perfilId: 'perfil-daniela',
    rol: RolUsuario.tutora,
    nombres: 'Daniela',
    apellidos: 'Valenzuela Castro',
    correo: 'daniela.valenzuela@ninaspro.cl',
    sedes: [SedeAsignada(id: 'sede-beauchef', nombre: 'Sede Beauchef')],
  );

  static const alumna = SesionUsuario(
    perfilId: 'perfil-valentina',
    rol: RolUsuario.alumna,
    nombres: 'Valentina',
    apellidos: 'Soto Morales',
    correo: 'valentina.soto@correo.cl',
    sedes: [SedeAsignada(id: 'sede-beauchef', nombre: 'Sede Beauchef')],
    alumnaId: 'alumna-1',
  );

  static const comunicacion = SesionUsuario(
    perfilId: 'perfil-comunicacion',
    rol: RolUsuario.comunicacion,
    nombres: 'Ana',
    apellidos: 'Prensa',
    correo: 'comunicaciones@ninaspro.cl',
    sedes: [SedeAsignada(id: 'sede-beauchef', nombre: 'Sede Beauchef')],
  );
}

/// [AuthService] en memoria: cada operación devuelve el resultado configurado
/// y registra las llamadas para verificarlas en los tests.
class FakeAuthService implements AuthService {
  final _estado = ValueNotifier<EstadoAuth>(EstadoAuth.iniciando);

  /// Sesión que se restaura en [iniciar] (null = sin sesión guardada)
  SesionUsuario? sesionGuardada;

  /// Sesión que se abre si [iniciarSesion] tiene éxito
  SesionUsuario? sesionAlIngresar;

  ResultadoAuth resultadoIngreso = const ResultadoAuth.ok();
  ResultadoAuth resultadoCrearCuenta = const ResultadoAuth.ok('Te enviamos un correo para activar tu cuenta.');
  ResultadoAuth resultadoRecuperacion = const ResultadoAuth.ok();
  ResultadoAuth resultadoNuevaContrasena = const ResultadoAuth.ok();

  final llamadas = <String>[];

  FakeAuthService({this.sesionGuardada, this.sesionAlIngresar});

  @override
  ValueListenable<EstadoAuth> get estado => _estado;

  /// Simula un cambio de Auth (ej. una sesión que se cierra desde otra pestaña)
  void emitir(EstadoAuth estado) => _estado.value = estado;

  @override
  Future<void> iniciar() async {
    llamadas.add('iniciar');
    final s = sesionGuardada;
    _estado.value = s == null ? const EstadoAuth(EtapaAuth.sinSesion) : EstadoAuth(EtapaAuth.conSesion, sesion: s);
  }

  @override
  Future<ResultadoAuth> iniciarSesion({required String correo, required String contrasena}) async {
    llamadas.add('iniciarSesion:$correo');
    if (resultadoIngreso.ok && sesionAlIngresar != null) {
      _estado.value = EstadoAuth(EtapaAuth.conSesion, sesion: sesionAlIngresar);
    }
    return resultadoIngreso;
  }

  @override
  Future<ResultadoAuth> crearCuenta({required String correo, required String contrasena}) async {
    llamadas.add('crearCuenta:$correo');
    return resultadoCrearCuenta;
  }

  @override
  Future<ResultadoAuth> enviarRecuperacion({required String correo}) async {
    llamadas.add('enviarRecuperacion:$correo');
    if (resultadoRecuperacion.ok) _estado.value = EstadoAuth(EtapaAuth.codigoEnviado, correo: correo);
    return resultadoRecuperacion;
  }

  ResultadoAuth resultadoCodigo = const ResultadoAuth.ok();

  @override
  Future<ResultadoAuth> verificarCodigo({required String codigo}) async {
    llamadas.add('verificarCodigo:$codigo');
    if (resultadoCodigo.ok) {
      _estado.value = EstadoAuth(EtapaAuth.recuperandoContrasena, correo: _estado.value.correo);
    }
    return resultadoCodigo;
  }

  @override
  Future<void> cancelarRecuperacion() async {
    llamadas.add('cancelarRecuperacion');
    _estado.value = const EstadoAuth(EtapaAuth.sinSesion);
  }

  @override
  Future<ResultadoAuth> actualizarContrasena({required String contrasena}) async {
    llamadas.add('actualizarContrasena');
    if (resultadoNuevaContrasena.ok) {
      _estado.value = EstadoAuth(EtapaAuth.conSesion, sesion: _estado.value.sesion ?? sesionAlIngresar ?? sesionGuardada);
    }
    return resultadoNuevaContrasena;
  }

  @override
  Future<void> cerrarSesion() async {
    llamadas.add('cerrarSesion');
    _estado.value = const EstadoAuth(EtapaAuth.sinSesion);
  }

  @override
  void dispose() {}
}
