import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/accesos_repository.dart';
import 'package:ninas_pro_hub/screens/accesos/accesos_view.dart';
import 'package:ninas_pro_hub/screens/auth/auth_gate.dart';
import 'package:ninas_pro_hub/screens/auth/codigo_recuperacion_screen.dart';
import 'package:ninas_pro_hub/screens/auth/verificacion_mfa_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/ajustes_gestion_screen.dart';
import 'package:ninas_pro_hub/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'fakes/fake_accesos_repository.dart';
import 'fakes/fake_auth_service.dart';

Widget _app(Widget home) => MaterialApp(theme: NinasProTheme.light, home: home);

Finder _campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

AutorizacionCorreo _autorizacion({
  required String id,
  required String correo,
  RolUsuario rol = RolUsuario.tutora,
  DateTime? expiraEn,
  DateTime? usadoEn,
}) =>
    AutorizacionCorreo(
      id: id,
      correo: correo,
      rol: rol,
      nombre: 'Persona $id',
      sedeNombre: 'Sede Beauchef',
      expiraEn: expiraEn ?? DateTime.now().add(const Duration(days: 10)),
      usadoEn: usadoEn,
    );

void main() {
  group('VerificacionMfaScreen', () {
    testWidgets('la primera vez muestra el QR y la clave, y verifica el código', (tester) async {
      final auth = FakeAuthService()..resultadoMfa = const ResultadoAuth.error(mensajeMfaInvalido);
      await tester.pumpWidget(_app(VerificacionMfaScreen(authService: auth, correo: 'directiva@ninaspro.cl')));
      await tester.pumpAndSettle();

      expect(auth.llamadas, ['iniciarInscripcionMfa']);
      expect(find.text('Protege tu cuenta de Directiva'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ABC'), findsOneWidget);

      await tester.enterText(_campo('Código'), '123456');
      await tester.ensureVisible(find.text('Verificar'));
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
      expect(auth.llamadas, contains('verificarMfa:123456'));
      expect(find.text(mensajeMfaInvalido), findsOneWidget);

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      expect(auth.llamadas, contains('cerrarSesion'));
    });

    testWidgets('si no se puede preparar el autenticador permite reintentar', (tester) async {
      final auth = FakeAuthService()..inscripcionMfa = null;
      await tester.pumpWidget(_app(VerificacionMfaScreen(authService: auth)));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos preparar el autenticador.'), findsOneWidget);
      expect(_campo('Código'), findsNothing);

      auth.inscripcionMfa = const InscripcionMfa(uri: 'otpauth://totp/x?secret=XYZ', secreto: 'XYZ');
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('XYZ'), findsOneWidget);
    });

    testWidgets('con el autenticador inscrito solo pide el código y entra a la app', (tester) async {
      final auth = FakeAuthService(sesionAlIngresar: SesionesDemo.directiva);
      await tester.pumpWidget(_app(AuthGate(
        authService: auth,
        builder: (context, sesion) => Text('App de ${sesion.nombres}'),
      )));
      await tester.pumpAndSettle();
      auth.emitir(const EstadoAuth(EtapaAuth.verificandoMfa, correo: 'directiva@ninaspro.cl', mfaInscrita: true));
      await tester.pumpAndSettle();

      expect(find.text('Verificación en dos pasos'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(auth.llamadas, isNot(contains('iniciarInscripcionMfa')));

      await tester.enterText(_campo('Código'), '654321');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
      expect(find.text('App de Directiva'), findsOneWidget);
    });
  });

  testWidgets('la pantalla del código explica que la cuenta quedó bloqueada', (tester) async {
    const aviso = 'Tu cuenta quedó bloqueada por 3 intentos fallidos. Te enviamos un código a tu correo para desbloquearla.';
    await tester.pumpWidget(_app(CodigoRecuperacionScreen(
      authService: FakeAuthService(),
      correo: 'daniela@ninaspro.cl',
      aviso: aviso,
    )));
    expect(find.text(aviso), findsOneWidget);
  });

  group('AccesosView', () {
    testWidgets('la Directiva ve las autorizaciones con su estado y autoriza a una tutora', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeAccesosRepository(lista: [
        _autorizacion(id: '1', correo: 'pendiente@ninaspro.cl'),
        _autorizacion(id: '2', correo: 'usada@ninaspro.cl', usadoEn: DateTime(2026, 11, 2)),
        _autorizacion(id: '3', correo: 'vencida@ninaspro.cl', expiraEn: DateTime(2026, 1, 1)),
      ]);
      await tester.pumpWidget(_app(Scaffold(body: AccesosView(repository: repo, sesion: SesionesDemo.directiva))));
      await tester.pumpAndSettle();

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Cuenta creada'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      // Una cuenta ya creada no se puede revocar
      expect(find.byTooltip('Revocar acceso de usada@ninaspro.cl'), findsNothing);

      await tester.tap(find.text('Autorizar correo'));
      await tester.pumpAndSettle();
      expect(find.text('Rol'), findsOneWidget);

      await tester.enterText(_campo('Nombres'), 'Nueva');
      await tester.enterText(_campo('Apellidos'), 'Tutora');
      await tester.enterText(_campo('RUT'), '12.345.678-0');
      await tester.enterText(_campo('Correo'), 'nueva@gmail.com');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();
      expect(find.text('El RUT no es válido'), findsOneWidget);
      expect(find.text('El voluntariado usa su correo institucional @ninaspro.cl.'), findsOneWidget);
      expect(find.text('Elige la sede'), findsOneWidget);
      expect(repo.solicitudes, isEmpty);

      await tester.enterText(_campo('RUT'), '123456785');
      await tester.enterText(_campo('Correo'), 'Nueva.Tutora@NinasPro.cl');
      await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String>, 'Sede'));
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Sede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sede Valparaíso').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      final s = repo.solicitudes.single;
      expect(s.correo, 'nueva.tutora@ninaspro.cl');
      expect(s.rol, RolUsuario.tutora);
      expect(s.sedeId, 'sede-b');
      expect(s.rut, '12.345.678-5');
      expect(find.textContaining('ya puede crear su cuenta'), findsOneWidget);
      expect(find.text('Persona 1'), findsOneWidget);
      expect(find.text('Nueva Tutora'), findsOneWidget);
    });

    testWidgets('la Directiva marca a una líder de sede y revoca una autorización', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeAccesosRepository(lista: [_autorizacion(id: '1', correo: 'pendiente@ninaspro.cl')]);
      await tester.pumpWidget(_app(Scaffold(body: AccesosView(repository: repo, sesion: SesionesDemo.directiva))));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Revocar acceso de pendiente@ninaspro.cl'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revocar'));
      await tester.pumpAndSettle();
      expect(repo.revocadas, ['1']);
      expect(find.text('Aún no hay correos autorizados.'), findsOneWidget);

      await tester.tap(find.text('Autorizar correo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<RolUsuario>, 'Rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('📋 Gestión').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Líder de sede'));
      await tester.enterText(_campo('Nombres'), 'Paula');
      await tester.enterText(_campo('Apellidos'), 'Líder');
      await tester.enterText(_campo('RUT'), '12.345.678-5');
      await tester.enterText(_campo('Correo'), 'paula@ninaspro.cl');
      await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String>, 'Sede'));
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Sede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sede Beauchef').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(repo.solicitudes.single.rol, RolUsuario.equipoGestion);
      expect(repo.solicitudes.single.esLiderSede, isTrue);
    });

    testWidgets('sin alumnas pendientes lo explica en el formulario', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeAccesosRepository(alumnas: const []);
      await tester.pumpWidget(_app(Scaffold(body: AccesosView(repository: repo, sesion: SesionesDemo.directiva))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autorizar correo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<RolUsuario>, 'Rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Alumna').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay alumnas inscritas sin cuenta'), findsOneWidget);
    });
  });

  group('Ajustes con Accesos', () {
    testWidgets('la Directiva abre Accesos desde su menú lateral', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeAccesosRepository(lista: [_autorizacion(id: '1', correo: 'pendiente@ninaspro.cl')]);
      await tester.pumpWidget(_app(AjustesDirectivaScreen(
        sesion: SesionesDemo.directiva,
        accesosRepository: repo,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accesos'));
      await tester.pumpAndSettle();
      expect(find.text('pendiente@ninaspro.cl'), findsOneWidget);
    });

    testWidgets('sin repositorio de accesos la Directiva no ve la opción', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AjustesDirectivaScreen(sesion: SesionesDemo.directiva)));
      await tester.pumpAndSettle();
      expect(find.text('Accesos'), findsNothing);
    });

    testWidgets('Gestión no tiene Accesos: las alumnas las gestiona la Directiva', (tester) async {
      await tester.pumpWidget(_app(AjustesGestionScreen(sesion: SesionesDemo.gestion)));
      await tester.pumpAndSettle();
      expect(find.text('Accesos'), findsNothing);
    });
  });
}
