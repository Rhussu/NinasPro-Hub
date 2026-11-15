import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/screens/auth/acceso_screen.dart';
import 'package:ninas_pro_hub/screens/auth/auth_gate.dart';
import 'package:ninas_pro_hub/screens/auth/nueva_contrasena_screen.dart';
import 'package:ninas_pro_hub/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_service.dart';

Widget _app(Widget home) => MaterialApp(theme: NinasProTheme.light, home: home);

void main() {
  group('Validaciones de acceso', () {
    test('validarContrasena exige 10 caracteres con minúsculas, mayúsculas y números', () {
      expect(validarContrasena('Corta1'), contains('10 caracteres'));
      expect(validarContrasena('SINMINUSCULA1'), contains('minúscula'));
      expect(validarContrasena('sinmayuscula1'), contains('mayúscula'));
      expect(validarContrasena('SinNumerosAqui'), contains('número'));
      expect(validarContrasena('NinasPro2026'), isNull);
    });

    test('validarCorreo revisa que exista y tenga formato de correo', () {
      expect(validarCorreo('  '), 'Ingresa tu correo.');
      expect(validarCorreo('sin-arroba'), 'Revisa el formato del correo.');
      expect(validarCorreo(' tutora@ninaspro.cl '), isNull);
    });

    test('mensajeErrorAuth traduce los códigos de Supabase y respeta los mensajes de los hooks', () {
      String m(String mensaje, {String? code, String? status}) =>
          mensajeErrorAuth(AuthException(mensaje, code: code, statusCode: status));

      expect(m('Invalid login credentials', code: 'invalid_credentials'), 'Correo o contraseña incorrectos.');
      expect(m('x', code: 'email_not_confirmed'), contains('Confirma tu cuenta'));
      expect(m('x', code: 'user_already_exists'), contains('Ya existe una cuenta'));
      expect(m('x', code: 'weak_password'), contains('muy débil'));
      expect(m('x', code: 'over_email_send_rate_limit'), contains('demasiados intentos'));
      expect(m('x', code: 'same_password'), contains('distinta'));
      expect(m('Forbidden por política', status: '403'), 'Forbidden por política');
      expect(m('algo raro'), contains('No pudimos completar'));
      // Hooks de la base: registro cerrado y bloqueo tras 3 intentos
      const bloqueo = 'Tu cuenta está bloqueada por 3 intentos fallidos.';
      expect(m(bloqueo, code: 'invalid_credentials'), bloqueo);
      const noAutorizado = 'Este correo no está autorizado para crear una cuenta.';
      expect(m(noAutorizado, status: '403'), noAutorizado);
    });

    test('RolUsuario se lee desde los valores del enum de la base', () {
      expect(RolUsuario.desdeDb('equipo_gestion'), RolUsuario.equipoGestion);
      expect(() => RolUsuario.desdeDb('rol_fantasma'), throwsArgumentError);
      expect(SesionesDemo.directiva.usaVistaEscritorio, isTrue);
      expect(SesionesDemo.tutora.sedePrincipal?.nombre, 'Sede Beauchef');
      expect(SesionesDemo.directiva.sedePrincipal, isNull);
    });
  });

  group('AccesoScreen', () {
    testWidgets('inicia sesión con correo y contraseña', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'tutora@ninaspro.cl');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'NinasPro2026');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(auth.llamadas, contains('iniciarSesion:tutora@ninaspro.cl'));
    });

    testWidgets('muestra el error del ingreso y valida campos vacíos', (tester) async {
      final auth = FakeAuthService()..resultadoIngreso = const ResultadoAuth.error('Correo o contraseña incorrectos.');
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu correo.'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
      expect(auth.llamadas, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'tutora@ninaspro.cl');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'mala');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    });

    testWidgets('muestra el aviso que dejó la sesión anterior', (tester) async {
      await tester.pumpWidget(_app(AccesoScreen(authService: FakeAuthService(), aviso: 'Tu cuenta no tiene un perfil activo.')));
      expect(find.text('Tu cuenta no tiene un perfil activo.'), findsOneWidget);
    });

    testWidgets('crea la cuenta de un correo autorizado validando la contraseña', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = FakeAuthService();
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));

      await tester.tap(find.text('Primera vez: crear mi cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Crea tu cuenta'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'valentina@correo.cl');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'debil');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'otra');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Usa al menos 10 caracteres.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(auth.llamadas, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'NinasPro2026');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'NinasPro2026');
      // Ver la contraseña escrita
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['crearCuenta:valentina@correo.cl']);
      expect(find.text('Te enviamos un correo para activar tu cuenta.'), findsOneWidget);

      await tester.tap(find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Te damos la bienvenida'), findsOneWidget);
    });

    testWidgets('envía el enlace de recuperación de contraseña', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Contraseña'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'tutora@ninaspro.cl');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['enviarRecuperacion:tutora@ninaspro.cl']);
      expect(find.text('Te enviamos un enlace.'), findsOneWidget);
    });
  });

  group('NuevaContrasenaScreen', () {
    testWidgets('guarda la contraseña nueva y muestra los errores', (tester) async {
      final auth = FakeAuthService()..resultadoNuevaContrasena = const ResultadoAuth.error('Debe ser distinta.');
      await tester.pumpWidget(_app(NuevaContrasenaScreen(authService: auth)));

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña nueva'), 'NinasPro2027');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'NinasPro2028');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'NinasPro2027');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['actualizarContrasena']);
      expect(find.text('Debe ser distinta.'), findsOneWidget);
    });
  });

  group('AuthGate', () {
    Widget gate(FakeAuthService auth) => _app(AuthGate(
          authService: auth,
          builder: (context, sesion) => Scaffold(body: Text('App de ${sesion.nombres}')),
        ));

    testWidgets('pasa del acceso a la app al iniciar sesión', (tester) async {
      final auth = FakeAuthService(sesionAlIngresar: SesionesDemo.tutora);
      await tester.pumpWidget(gate(auth));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['iniciar']);
      expect(find.text('Te damos la bienvenida'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'daniela.valenzuela@ninaspro.cl');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'NinasPro2026');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('App de Daniela'), findsOneWidget);
    });

    testWidgets('muestra la contraseña nueva al abrir el enlace de recuperación', (tester) async {
      final auth = FakeAuthService(sesionGuardada: SesionesDemo.alumna);
      await tester.pumpWidget(gate(auth));
      await tester.pumpAndSettle();
      expect(find.text('App de Valentina'), findsOneWidget);

      auth.emitir(const EstadoAuth(EtapaAuth.recuperandoContrasena, sesion: SesionesDemo.alumna));
      await tester.pumpAndSettle();
      expect(find.text('Crea tu contraseña nueva'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña nueva'), 'NinasPro2027');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'NinasPro2027');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('App de Valentina'), findsOneWidget);
    });

    testWidgets('muestra el aviso cuando la sesión se cierra por falta de perfil', (tester) async {
      final auth = FakeAuthService(sesionGuardada: SesionesDemo.gestion);
      await tester.pumpWidget(gate(auth));
      await tester.pumpAndSettle();

      auth.emitir(const EstadoAuth(EtapaAuth.sinSesion, aviso: 'Tu cuenta no tiene un perfil activo.'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta no tiene un perfil activo.'), findsOneWidget);
    });
  });

  group('SupabaseAuthService', () {
    const userId = '7a000000-0000-0000-0000-000000000001';

    String jwt() {
      String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': userId, 'exp': exp, 'role': 'authenticated'})}.firma';
    }

    Map<String, dynamic> usuario() => {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'daniela.valenzuela@ninaspro.cl',
          'app_metadata': {'provider': 'email'},
          'user_metadata': {},
          'created_at': '2026-11-01T00:00:00Z',
        };

    Map<String, dynamic> sesionJson() => {
          'access_token': jwt(),
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          'refresh_token': 'refresh',
          'user': usuario(),
        };

    /// Servidor simulado de Supabase: Auth + PostgREST
    ({SupabaseAuthService servicio, List<String> rutas}) crear({
      http.Response? Function(http.Request r)? auth,
      Map<String, dynamic>? perfil,
      Map<String, dynamic>? alumna,
    }) {
      final rutas = <String>[];
      http.Response responder(http.Request r) {
        final json = {'content-type': 'application/json'};
        if (r.url.path.startsWith('/auth/v1')) {
          final respuesta = auth?.call(r);
          if (respuesta != null) return respuesta;
          if (r.url.path.endsWith('/token')) return http.Response(jsonEncode(sesionJson()), 200, headers: json);
          if (r.url.path.endsWith('/logout')) return http.Response('', 204);
          return http.Response('{}', 200, headers: json);
        }
        final fila = r.url.path.endsWith('/perfiles') ? perfil : alumna;
        final objeto = (r.headers['Accept'] ?? r.headers['accept'] ?? '').contains('vnd.pgrst.object');
        if (fila == null) {
          return objeto
              ? http.Response(jsonEncode({'code': 'PGRST116', 'message': 'no rows'}), 406, headers: json)
              : http.Response('[]', 200, headers: json);
        }
        return http.Response(jsonEncode(objeto ? fila : [fila]), 200, headers: json);
      }

      // Las respuestas llevan su request, como las de un servidor real
      final cliente = MockClient((r) async {
        rutas.add('${r.method} ${r.url.path}');
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon',
        httpClient: cliente,
        authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _AlmacenPkce()),
      );
      return (servicio: SupabaseAuthService(client, redirectTo: 'http://localhost:3000/'), rutas: rutas);
    }

    final perfilTutora = {
      'id': userId,
      'nombres': 'Daniela',
      'apellidos': 'Valenzuela Castro',
      'correo': 'daniela.valenzuela@ninaspro.cl',
      'rol': 'tutora',
      'activo': true,
      'usuarios_sedes': [
        {'sede_id': 'sede-1', 'es_lider_sede': false, 'sedes': {'nombre': 'Sede Beauchef'}},
      ],
    };

    test('sin sesión guardada queda en el acceso', () async {
      final s = crear().servicio;
      await s.iniciar();
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('iniciar sesión carga el perfil, el rol y las sedes', () async {
      final s = crear(perfil: perfilTutora).servicio;
      await s.iniciar();
      final r = await s.iniciarSesion(correo: ' Daniela.Valenzuela@NinasPro.cl ', contrasena: 'NinasPro2026');

      expect(r.ok, isTrue);
      final sesion = s.estado.value.sesion!;
      expect(s.estado.value.etapa, EtapaAuth.conSesion);
      expect(sesion.rol, RolUsuario.tutora);
      expect(sesion.nombreCompleto, 'Daniela Valenzuela Castro');
      expect(sesion.sedePrincipal?.nombre, 'Sede Beauchef');

      await s.cerrarSesion();
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('la alumna queda vinculada a su ficha', () async {
      final s = crear(
        perfil: {...perfilTutora, 'rol': 'alumna', 'usuarios_sedes': []},
        alumna: {'id': 'alumna-uuid'},
      ).servicio;
      final r = await s.iniciarSesion(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isTrue);
      expect(s.estado.value.sesion!.alumnaId, 'alumna-uuid');
      s.dispose();
    });

    test('una alumna sin ficha vinculada no puede entrar', () async {
      final s = crear(perfil: {...perfilTutora, 'rol': 'alumna'}).servicio;
      final r = await s.iniciarSesion(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isFalse);
      expect(r.mensaje, contains('no está vinculada'));
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('una cuenta sin perfil activo se cierra con aviso', () async {
      final s = crear(perfil: {...perfilTutora, 'activo': false}).servicio;
      final r = await s.iniciarSesion(correo: 'daniela@ninaspro.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isFalse);
      expect(s.estado.value.aviso, contains('perfil activo'));
      s.dispose();
    });

    test('las credenciales erróneas devuelven el mensaje traducido', () async {
      final s = crear(
        auth: (r) => http.Response(
          jsonEncode({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ).servicio;
      final r = await s.iniciarSesion(correo: 'x@ninaspro.cl', contrasena: 'mala');
      expect(r.ok, isFalse);
      expect(r.mensaje, 'Correo o contraseña incorrectos.');
      s.dispose();
    });

    test('crear cuenta pide confirmar el correo; un correo no autorizado se rechaza', () async {
      var autorizado = true;
      final s = crear(
        auth: (r) => r.url.path.endsWith('/signup')
            ? (autorizado
                ? http.Response(jsonEncode(usuario()), 200, headers: {'content-type': 'application/json'})
                : http.Response(
                    jsonEncode({'code': 403, 'msg': 'Este correo no está autorizado para crear una cuenta.'}),
                    403,
                    headers: {'content-type': 'application/json'},
                  ))
            : null,
      ).servicio;

      final ok = await s.crearCuenta(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(ok.ok, isTrue);
      expect(ok.mensaje, contains('activar tu cuenta'));

      autorizado = false;
      final rechazo = await s.crearCuenta(correo: 'intrusa@correo.cl', contrasena: 'NinasPro2026');
      expect(rechazo.ok, isFalse);
      expect(rechazo.mensaje, contains('no está autorizado'));
      s.dispose();
    });

    test('envía la recuperación y actualiza la contraseña', () async {
      final (:servicio, :rutas) = crear(
        perfil: perfilTutora,
        auth: (r) => r.url.path.endsWith('/user')
            ? http.Response(jsonEncode(usuario()), 200, headers: {'content-type': 'application/json'})
            : null,
      );
      final rec = await servicio.enviarRecuperacion(correo: 'daniela@ninaspro.cl');
      expect(rec.ok, isTrue);
      expect(rutas, contains('POST /auth/v1/recover'));

      await servicio.iniciarSesion(correo: 'daniela@ninaspro.cl', contrasena: 'NinasPro2026');
      final act = await servicio.actualizarContrasena(contrasena: 'NinasPro2027');
      expect(act.ok, isTrue);
      expect(rutas, contains('PUT /auth/v1/user'));
      servicio.dispose();
    });
  });
}

/// Almacenamiento en memoria del verificador PKCE (flujo de enlaces por correo)
class _AlmacenPkce extends GotrueAsyncStorage {
  final _datos = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _datos[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _datos[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _datos.remove(key);
}
