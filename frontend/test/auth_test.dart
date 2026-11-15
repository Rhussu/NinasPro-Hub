import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/screens/auth/acceso_screen.dart';
import 'package:ninas_pro_hub/screens/auth/auth_gate.dart';
import 'package:ninas_pro_hub/screens/auth/codigo_recuperacion_screen.dart';
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
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['crearCuenta:valentina@correo.cl']);
      expect(find.text('Te enviamos un correo para activar tu cuenta.'), findsOneWidget);
    });

    // Regresión C1: tras mostrar la contraseña y fallar la validación, los campos
    // siguen editables y el error no pasa al login
    testWidgets('mostrar la contraseña y fallar no bloquea los campos ni arrastra errores al login', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = FakeAuthService()..resultadoCrearCuenta = const ResultadoAuth.error('Este correo no está autorizado.');
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));
      await tester.tap(find.text('Primera vez: crear mi cuenta'));
      await tester.pumpAndSettle();

      Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);
      String texto(String etiqueta) => tester.widget<TextFormField>(campo(etiqueta)).controller!.text;

      await tester.enterText(campo('Correo'), 'valentina@correo.cl');
      await tester.enterText(campo('Contraseña'), 'sinmayuscula1');
      // Mostrar y volver a ocultar la primera contraseña
      await tester.tap(find.byTooltip('Mostrar contraseña').first);
      await tester.pump();
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
      expect(texto('Contraseña'), 'sinmayuscula1');
      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();

      await tester.enterText(campo('Repite la contraseña'), 'sinmayuscula1');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Incluye al menos una letra mayúscula.'), findsOneWidget);

      // El campo sigue aceptando cambios después del error
      await tester.enterText(campo('Contraseña'), 'ConMayuscula1');
      expect(texto('Contraseña'), 'ConMayuscula1');
      await tester.enterText(campo('Repite la contraseña'), 'ConMayuscula1');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Este correo no está autorizado.'), findsOneWidget);

      // Al volver al login no queda ningún error ni contraseña del modo anterior
      await tester.tap(find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Te damos la bienvenida'), findsOneWidget);
      expect(find.text('Este correo no está autorizado.'), findsNothing);
      expect(find.text('Incluye al menos una letra mayúscula.'), findsNothing);
      expect(texto('Correo'), 'valentina@correo.cl');
      expect(texto('Contraseña'), isEmpty);
      await tester.enterText(campo('Contraseña'), 'NinasPro2026');
      expect(texto('Contraseña'), 'NinasPro2026');
    });

    testWidgets('pide el código de recuperación de contraseña', (tester) async {
      final auth = FakeAuthService()..resultadoRecuperacion = const ResultadoAuth.error('Hiciste demasiados intentos.');
      await tester.pumpWidget(_app(AccesoScreen(authService: auth)));

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Contraseña'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'tutora@ninaspro.cl');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['enviarRecuperacion:tutora@ninaspro.cl']);
      expect(find.text('Hiciste demasiados intentos.'), findsOneWidget);
    });
  });

  group('CodigoRecuperacionScreen', () {
    Finder campoCodigo() => find.widgetWithText(TextFormField, 'Código');

    testWidgets('valida el código, lo envía y muestra el error de Auth', (tester) async {
      final auth = FakeAuthService()..resultadoCodigo = const ResultadoAuth.error(mensajeCodigoInvalido);
      await tester.pumpWidget(_app(CodigoRecuperacionScreen(authService: auth, correo: 'rita@ninaspro.cl')));
      expect(find.textContaining('rita@ninaspro.cl'), findsOneWidget);

      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa el código que te enviamos.'), findsOneWidget);

      await tester.enterText(campoCodigo(), '1234');
      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(find.text('El código tiene 6 números.'), findsOneWidget);
      expect(auth.llamadas, isEmpty);

      // Solo se aceptan números y espacios, como al pegarlo desde el correo
      await tester.enterText(campoCodigo(), '12a 456');
      expect(tester.widget<TextFormField>(campoCodigo()).controller!.text, '12 456');
      await tester.enterText(campoCodigo(), '123 456');
      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['verificarCodigo:123 456']);
      expect(find.text(mensajeCodigoInvalido), findsOneWidget);
    });

    testWidgets('reenvía el código y permite cancelar', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(_app(CodigoRecuperacionScreen(authService: auth, correo: 'rita@ninaspro.cl')));

      await tester.enterText(campoCodigo(), '111111');
      await tester.tap(find.text('Enviarme otro código'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, ['enviarRecuperacion:rita@ninaspro.cl']);
      expect(find.textContaining('código nuevo'), findsOneWidget);
      expect(tester.widget<TextFormField>(campoCodigo()).controller!.text, isEmpty);

      await tester.ensureVisible(find.text('Cancelar y volver al inicio'));
      await tester.tap(find.text('Cancelar y volver al inicio'));
      expect(auth.llamadas, contains('cancelarRecuperacion'));
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

      await tester.ensureVisible(find.text('Cancelar y volver al inicio'));
      await tester.tap(find.text('Cancelar y volver al inicio'));
      expect(auth.llamadas, contains('cancelarRecuperacion'));
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

    testWidgets('recorre la recuperación en la misma pantalla: código, contraseña nueva y app', (tester) async {
      final auth = FakeAuthService(sesionAlIngresar: SesionesDemo.alumna);
      await tester.pumpWidget(gate(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'valentina@correo.cl');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('valentina@correo.cl'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Código'), '123456');
      await tester.tap(find.text('Verificar código'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, contains('verificarCodigo:123456'));
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
    const json = {'content-type': 'application/json'};

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

    /// Servidor simulado de Supabase (Auth + PostgREST) que puede compartir el
    /// estado de la cuenta entre varios clientes
    late Map<String, dynamic> cuenta;
    late List<String> rutas;

    setUp(() {
      cuenta = {'bloqueada': false, 'recuperacion_pendiente': false};
      rutas = [];
    });

    SupabaseAuthService crear({
      http.Response? Function(http.Request r)? auth,
      Map<String, dynamic>? perfil,
      Map<String, dynamic>? alumna,
      Uri? url,
      void Function()? limpiarUrl,
    }) {
      http.Response responder(http.Request r) {
        final ruta = r.url.path;
        if (ruta.startsWith('/auth/v1')) {
          final respuesta = auth?.call(r);
          if (respuesta != null) return respuesta;
          if (ruta.endsWith('/token')) return http.Response(jsonEncode(sesionJson()), 200, headers: json);
          if (ruta.endsWith('/verify')) {
            // Canjear el código de recuperación deja la recuperación pendiente en la base
            if ((jsonDecode(r.body) as Map)['type'] == 'recovery') cuenta['recuperacion_pendiente'] = true;
            return http.Response(jsonEncode(sesionJson()), 200, headers: json);
          }
          if (ruta.endsWith('/user')) {
            // Cambiar la contraseña cierra la recuperación y desbloquea la cuenta
            cuenta['recuperacion_pendiente'] = false;
            cuenta['bloqueada'] = false;
            return http.Response(jsonEncode(usuario()), 200, headers: json);
          }
          if (ruta.endsWith('/logout')) return http.Response('', 204);
          return http.Response('{}', 200, headers: json);
        }
        if (ruta.endsWith('/rpc/estado_mi_cuenta')) return http.Response(jsonEncode(cuenta), 200, headers: json);
        final fila = ruta.endsWith('/perfiles') ? perfil : alumna;
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
      return SupabaseAuthService(
        client,
        redirectTo: 'http://localhost:3000/',
        urlInicial: url ?? Uri.parse('http://localhost:3000/'),
        limpiarUrl: limpiarUrl ?? () {},
      );
    }

    Uri enlace(String tipo) => Uri.parse('http://localhost:3000/?token_hash=pkce_abc123&type=$tipo');

    test('sin sesión guardada queda en el acceso', () async {
      final s = crear();
      await s.iniciar();
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('iniciar sesión carga el perfil, el rol y las sedes', () async {
      final s = crear(perfil: perfilTutora);
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
      );
      final r = await s.iniciarSesion(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isTrue);
      expect(s.estado.value.sesion!.alumnaId, 'alumna-uuid');
      s.dispose();
    });

    test('una alumna sin ficha vinculada no puede entrar', () async {
      final s = crear(perfil: {...perfilTutora, 'rol': 'alumna'});
      final r = await s.iniciarSesion(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isFalse);
      expect(r.mensaje, contains('no está vinculada'));
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('una cuenta sin perfil activo se cierra con aviso', () async {
      final s = crear(perfil: {...perfilTutora, 'activo': false});
      final r = await s.iniciarSesion(correo: 'daniela@ninaspro.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isFalse);
      expect(s.estado.value.aviso, contains('perfil activo'));
      s.dispose();
    });

    test('una cuenta bloqueada pierde la sesión aunque la tuviera abierta', () async {
      final s = crear(perfil: perfilTutora);
      cuenta['bloqueada'] = true;
      final r = await s.iniciarSesion(correo: 'daniela@ninaspro.cl', contrasena: 'NinasPro2026');
      expect(r.ok, isFalse);
      expect(s.estado.value.aviso, mensajeCuentaBloqueada);
      s.dispose();
    });

    test('las credenciales erróneas devuelven el mensaje traducido', () async {
      final s = crear(
        auth: (r) => http.Response(
          jsonEncode({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}),
          400,
          headers: json,
        ),
      );
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
                ? http.Response(jsonEncode(usuario()), 200, headers: json)
                : http.Response(
                    jsonEncode({'code': 403, 'msg': 'Este correo no está autorizado para crear una cuenta.'}),
                    403,
                    headers: json,
                  ))
            : null,
      );

      final ok = await s.crearCuenta(correo: 'valentina@correo.cl', contrasena: 'NinasPro2026');
      expect(ok.ok, isTrue);
      expect(ok.mensaje, contains('activar tu cuenta'));

      autorizado = false;
      final rechazo = await s.crearCuenta(correo: 'intrusa@correo.cl', contrasena: 'NinasPro2026');
      expect(rechazo.ok, isFalse);
      expect(rechazo.mensaje, contains('no está autorizado'));
      s.dispose();
    });

    test('el enlace de activación canjea el token_hash y entra a la app', () async {
      var urlLimpiada = 0;
      final s = crear(perfil: perfilTutora, url: enlace('email'), limpiarUrl: () => urlLimpiada++);
      await s.iniciar();
      expect(rutas, contains('POST /auth/v1/verify'));
      expect(urlLimpiada, 1);
      expect(s.estado.value.etapa, EtapaAuth.conSesion);
      s.dispose();
    });

    test('un enlace de activación vencido avisa en el acceso', () async {
      final s = crear(
        url: enlace('email'),
        auth: (r) => r.url.path.endsWith('/verify')
            ? http.Response(jsonEncode({'code': 403, 'error_code': 'otp_expired', 'msg': 'expired'}), 403, headers: json)
            : null,
      );
      await s.iniciar();
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      expect(s.estado.value.aviso, contains('ya se usó o venció'));
      s.dispose();
    });

    group('recuperación con código', () {
      Map<String, dynamic>? verificado;

      SupabaseAuthService conCodigo({Map<String, dynamic>? perfil, String? errorVerificar}) => crear(
            perfil: perfil,
            auth: (r) {
              if (!r.url.path.endsWith('/verify')) return null;
              verificado = jsonDecode(r.body) as Map<String, dynamic>;
              if (errorVerificar == null) return null;
              return http.Response(jsonEncode({'code': 403, 'error_code': errorVerificar, 'msg': 'x'}), 403, headers: json);
            },
          );

      setUp(() => verificado = null);

      test('envía el código, lo verifica con el correo y pide la contraseña nueva antes de entrar', () async {
        final s = conCodigo(perfil: perfilTutora);
        await s.iniciar();
        final r = await s.enviarRecuperacion(correo: ' Daniela@NinasPro.cl ');
        expect(r.ok, isTrue);
        expect(rutas, contains('POST /auth/v1/recover'));
        expect(s.estado.value.etapa, EtapaAuth.codigoEnviado);
        expect(s.estado.value.correo, 'daniela@ninaspro.cl');

        final v = await s.verificarCodigo(codigo: '123 456');
        expect(v.ok, isTrue);
        expect(verificado, containsPair('type', 'recovery'));
        expect(verificado, containsPair('email', 'daniela@ninaspro.cl'));
        expect(verificado, containsPair('token', '123456'));
        expect(s.estado.value.etapa, EtapaAuth.recuperandoContrasena);

        final c = await s.actualizarContrasena(contrasena: 'NinasPro2027');
        expect(c.ok, isTrue);
        expect(s.estado.value.etapa, EtapaAuth.conSesion);
        s.dispose();
      });

      test('un código incorrecto o vencido se avisa y deja reintentar', () async {
        final s = conCodigo(perfil: perfilTutora, errorVerificar: 'otp_expired');
        await s.iniciar();
        await s.enviarRecuperacion(correo: 'daniela@ninaspro.cl');
        final v = await s.verificarCodigo(codigo: '000000');
        expect(v.ok, isFalse);
        expect(v.mensaje, mensajeCodigoInvalido);
        expect(s.estado.value.etapa, EtapaAuth.codigoEnviado);
        s.dispose();
      });

      test('sin haber pedido el código no se verifica ni se cambia la contraseña', () async {
        final s = conCodigo(perfil: perfilTutora);
        await s.iniciar();
        expect((await s.verificarCodigo(codigo: '123456')).ok, isFalse);
        expect((await s.actualizarContrasena(contrasena: 'NinasPro2027')).ok, isFalse);
        expect(rutas, isNot(contains('POST /auth/v1/verify')));
        expect(rutas, isNot(contains('PUT /auth/v1/user')));
        s.dispose();
      });

      test('una cuenta bloqueada recupera el acceso con el código', () async {
        cuenta['bloqueada'] = true;
        final s = conCodigo(perfil: perfilTutora);
        await s.iniciar();
        await s.enviarRecuperacion(correo: 'daniela@ninaspro.cl');
        await s.verificarCodigo(codigo: '123456');
        expect(s.estado.value.etapa, EtapaAuth.recuperandoContrasena);

        await s.actualizarContrasena(contrasena: 'NinasPro2027');
        expect(s.estado.value.etapa, EtapaAuth.conSesion);
        s.dispose();
      });

      test('cancelar mientras se espera el código vuelve al acceso', () async {
        final s = conCodigo();
        await s.iniciar();
        await s.enviarRecuperacion(correo: 'daniela@ninaspro.cl');
        await s.cancelarRecuperacion();
        expect(s.estado.value.etapa, EtapaAuth.sinSesion);
        s.dispose();
      });
    });

    test('un enlace de recuperación antiguo se ignora y queda en el acceso', () async {
      var urlLimpiada = 0;
      final s = crear(perfil: perfilTutora, url: enlace('recovery'), limpiarUrl: () => urlLimpiada++);
      await s.iniciar();
      expect(urlLimpiada, 1);
      expect(rutas, isNot(contains('POST /auth/v1/verify')));
      expect(s.estado.value.etapa, EtapaAuth.sinSesion);
      s.dispose();
    });

    test('recargar con una recuperación pendiente nunca entra a la app', () async {
      final s = crear(perfil: perfilTutora);
      cuenta['recuperacion_pendiente'] = true;
      // Recarga: la sesión del código sigue guardada pero falta la contraseña nueva
      final r = await s.iniciarSesion(correo: 'daniela@ninaspro.cl', contrasena: 'x');
      expect(r.ok, isFalse);
      await s.iniciar();
      expect(s.estado.value.etapa, EtapaAuth.recuperandoContrasena);
      expect(s.estado.value.correo, 'daniela.valenzuela@ninaspro.cl');
      s.dispose();
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
