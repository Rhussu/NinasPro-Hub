// TC-37 · RNF-U-3: la interfaz se adapta desde 360 px de ancho (celulares de
// las tutoras) hasta 1080p (escritorio de la Directiva), en español.
//
// Un desborde de diseño ("RenderFlex overflowed") es un error de Flutter que
// hace fallar la prueba, así que basta con abrir cada vista en cada tamaño.
// Perfiles: los de Chrome DevTools que nombra el SRS (iPhone, Samsung Galaxy)
// y 1080p.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';

import 'fakes/fake_alertas_repository.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_clase_repository.dart';
import 'fakes/fake_portal_repository.dart';
import 'fakes/fake_reportes_repository.dart';

const _moviles = {
  'Galaxy S8+ 360×740': Size(360, 740),
  'iPhone SE 375×667': Size(375, 667),
  'iPhone 14 Pro Max 430×932': Size(430, 932),
};
const _escritorio = {'1080p 1920×1080': Size(1920, 1080)};

void main() {
  late FakeClaseRepository clase;

  setUp(() => clase = FakeClaseRepository());
  tearDown(() => clase.cerrar());

  Future<void> abrir(WidgetTester tester, SesionUsuario sesion, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: NinasProTheme.light,
      darkTheme: NinasProTheme.dark,
      themeMode: ThemeMode.dark,
      home: HubShellScreen(
        sesion: sesion,
        themeNotifier: ValueNotifier(ThemeMode.dark),
        claseRepository: clase,
        portalRepository: FakePortalRepository(),
        alertasRepository: FakeAlertasRepository(),
        reportesRepository: FakeReportesRepository(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final perfilesMoviles = {
    'Tutora': (SesionesDemo.tutora, '¡Hola, Daniela!'),
    'Equipo de Gestión': (SesionesDemo.gestion, '¡Hola, Camila!'),
    'Alumna': (SesionesDemo.alumna, '¡Hola, Valentina!'),
  };

  for (final MapEntry(key: dispositivo, value: tamano) in _moviles.entries) {
    for (final MapEntry(key: perfil, value: (sesion, saludo)) in perfilesMoviles.entries) {
      testWidgets('$perfil en $dispositivo: inicio sin desbordes y en español', (tester) async {
        await abrir(tester, sesion, tamano);
        expect(find.textContaining(saludo), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Tutora en $dispositivo: el pase de lista cabe y sus botones miden al menos 44 px', (tester) async {
      await abrir(tester, SesionesDemo.tutora, tamano);
      await tester.tap(find.byTooltip('Acciones rápidas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // RNF-U-1: área táctil mínima de 44×44 px (SRS §4.4)
      for (final boton in [find.text('Presente').first, find.text('Guardar Asistencia de la Clase')]) {
        final tamanoBoton = tester.getSize(find.ancestor(of: boton, matching: find.byWidgetPredicate(
          (w) => w is InkWell || w is ButtonStyleButton || w is GestureDetector,
        )).first);
        expect(tamanoBoton.width, greaterThanOrEqualTo(44), reason: 'ancho de $boton');
        expect(tamanoBoton.height, greaterThanOrEqualTo(44), reason: 'alto de $boton');
      }
    });
  }

  for (final MapEntry(key: pantalla, value: tamano) in _escritorio.entries) {
    testWidgets('Directiva en $pantalla: la consola de escritorio sin desbordes', (tester) async {
      await abrir(tester, SesionesDemo.directiva, tamano);
      expect(find.text('Dashboard'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
