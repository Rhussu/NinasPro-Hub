import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart' show ArchivoAdjunto;
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/repositories/voluntariado_repository.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes/ajustes_roles_view.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_desktop_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_widgets.dart' show FiltroDesplegable;
import 'package:ninas_pro_hub/services/descargas.dart';
import 'package:ninas_pro_hub/services/selector_archivos.dart';
import 'package:ninas_pro_hub/utils/planilla.dart';

import 'fakes/fake_catalogo_repository.dart';
import 'fakes/fake_roles_repository.dart';
import 'fakes/fake_voluntariado_repository.dart';

/// Voluntariado de la Directiva (US-30..US-32) y catálogo de roles (US-43)
void main() {
  late FakeVoluntariadoRepository voluntariado;
  late FakeCatalogoRepository catalogo;

  setUp(() {
    voluntariado = FakeVoluntariadoRepository();
    catalogo = FakeCatalogoRepository(
      sedes: [
        const Sede(
          id: 'sede-beauchef',
          nombre: 'Sede Beauchef',
          universidad: '',
          region: '',
          modalidad: 'Presencial',
          coordinadoraNombre: '',
        ),
        const Sede(
          id: 'sede-valpo',
          nombre: 'Sede Valparaíso',
          universidad: '',
          region: '',
          modalidad: 'Presencial',
          coordinadoraNombre: '',
        ),
      ],
      instancias: [
        const Curso(
          id: 'inst-pcb',
          codigo: 'PCB',
          nombre: 'Programación',
          sedeId: 'sede-beauchef',
          sedeNombre: 'Sede Beauchef',
          anio: 2026,
          semestre: 2,
          totalSesiones: 10,
        ),
        const Curso(
          id: 'inst-web',
          codigo: 'WEB',
          nombre: 'Desarrollo Web',
          sedeId: 'sede-valpo',
          sedeNombre: 'Sede Valparaíso',
          anio: 2026,
          semestre: 2,
          totalSesiones: 10,
        ),
      ],
    );
    ultimaDescarga = null;
  });
  tearDown(() => elegirArchivo = (_) async => null);

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: NinasProTheme.light,
        home: Scaffold(body: pantalla),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirVoluntariado(WidgetTester tester) async {
    await abrir(
      tester,
      DirectorioDesktopScreen(
        repository: MockHubRepository(),
        voluntariadoRepository: voluntariado,
        catalogoRepository: catalogo,
      ),
    );
    await tester.tap(find.text('Voluntariado').first);
    await tester.pumpAndSettle();
  }

  Future<void> elegirEnFiltro(WidgetTester tester, String etiqueta, String opcion) async {
    await tester.tap(find.byWidgetPredicate((w) => w is FiltroDesplegable && w.etiqueta == etiqueta));
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcion).last);
    await tester.pumpAndSettle();
  }

  group('Directorio del voluntariado', () {
    testWidgets('lista las activas, filtra por estado y por sede y exporta lo filtrado (US-32)', (tester) async {
      await abrirVoluntariado(tester);

      expect(find.text('3 voluntarias activas · 1 sin declaración de adhesión · 1 aún sin cuenta'), findsOneWidget);
      expect(find.text('Daniela Valenzuela Castro'), findsOneWidget);
      expect(find.text('Sofía Araya Medina'), findsOneWidget);
      expect(find.text('Correo autorizado'), findsOneWidget);
      expect(find.text('Ignacia Morales Fuentes'), findsNothing);

      await elegirEnFiltro(tester, 'Estado', 'Retirada');
      expect(find.text('Ignacia Morales Fuentes'), findsOneWidget);
      expect(find.text('Daniela Valenzuela Castro'), findsNothing);

      await elegirEnFiltro(tester, 'Estado', 'Activa');
      await elegirEnFiltro(tester, 'Sede', 'Sede Valparaíso');
      expect(find.text('Sofía Araya Medina'), findsOneWidget);
      expect(find.text('Daniela Valenzuela Castro'), findsNothing);

      await tester.tap(find.byTooltip('Exportar el listado filtrado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();
      expect(ultimaDescarga!.nombre, 'voluntariado.csv');
      final texto = utf8.decode(ultimaDescarga!.bytes.skip(3).toList());
      expect(texto, startsWith('rut,nombres,apellidos,correo'));
      expect(texto, contains('Sofía,Araya Medina'));
      expect(texto, isNot(contains('Daniela')));
      expect(find.text('📄 voluntariado.csv con 1 filas.'), findsOneWidget);

      await tester.tap(find.byTooltip('Exportar el listado filtrado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excel (XLSX)'));
      await tester.pumpAndSettle();
      expect(ultimaDescarga!.nombre, 'voluntariado.xlsx');
    });

    testWidgets('la ficha registra la adhesión y asigna a un curso (US-31)', (tester) async {
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Francisca Herrera Rojas'));
      await tester.pumpAndSettle();

      expect(find.text('No apta: falta la declaración de adhesión firmada'), findsOneWidget);
      expect(find.text('Para asignarla a un curso debe tener la declaración de adhesión firmada.'), findsOneWidget);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Declaración de Conocimiento y Adhesión firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(voluntariado.porId('vol-francisca').adhesionFirmada, isTrue);
      expect(find.text('Apta para hacer clases'), findsOneWidget);

      await tester.tap(find.text('Asignar a curso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEB · Sede Valparaíso · 2026-2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
      await tester.pumpAndSettle();
      expect(voluntariado.llamadas, contains('asignar:vol-francisca:inst-web'));
      expect(find.text('WEB · Sede Valparaíso · 2026-2'), findsOneWidget);
    });

    testWidgets('sin cuenta no se asigna a cursos; el rol se cambia desde la ficha', (tester) async {
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Sofía Araya Medina'));
      await tester.pumpAndSettle();

      expect(
        find.text('Podrás asignarla a un curso cuando cree su cuenta con sofia.araya@ninaspro.cl.'),
        findsOneWidget,
      );
      expect(find.textContaining('Su correo está autorizado hasta el 01/12/2026'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(SegmentedButton<RolVoluntaria>), matching: find.text('Tutora')));
      await tester.pumpAndSettle();
      expect(voluntariado.porId('vol-sofia').rol, RolVoluntaria.tutora);
      expect(find.text('Sofía Araya Medina ahora solo tiene las funciones de tutora.'), findsOneWidget);
    });

    testWidgets('registra la salida conservando la trayectoria y luego la reincorpora (US-32 E2)', (tester) async {
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Daniela Valenzuela Castro'));
      await tester.pumpAndSettle();
      expect(find.text('PCB · Sede Beauchef · 2026-2'), findsOneWidget);

      await tester.tap(find.text('Registrar salida'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('su cuenta se desactiva'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar salida'));
      await tester.pumpAndSettle();

      final daniela = voluntariado.porId('vol-daniela');
      expect(daniela.retirada, isTrue);
      expect(daniela.cursos, hasLength(1));
      expect(find.text('No apta: está retirada'), findsOneWidget);
      expect(find.text('Su cuenta está desactivada porque salió del voluntariado.'), findsOneWidget);

      await tester.tap(find.text('Reincorporar'));
      await tester.pumpAndSettle();
      expect(voluntariado.porId('vol-daniela').retirada, isFalse);
    });

    testWidgets('la autorización vencida se renueva desde la ficha', (tester) async {
      voluntariado.lista.add(
        FichaVoluntaria(
          id: 'vol-vencida',
          rut: '21.190.009-1',
          nombres: 'Paz',
          apellidos: 'Vencida',
          correo: 'paz@ninaspro.cl',
          sedeId: 'sede-beauchef',
          sedeNombre: 'Sede Beauchef',
          fechaIngreso: DateTime(2026, 1, 1),
          cuenta: CuentaVoluntaria.sinAutorizacion,
          sedeIds: const {'sede-beauchef'},
        ),
      );
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Paz Vencida'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renovar autorización'));
      await tester.pumpAndSettle();
      expect(voluntariado.porId('vol-vencida').cuenta, CuentaVoluntaria.autorizada);
      expect(find.text('✅ Su correo queda autorizado por 30 días más.'), findsOneWidget);
    });

    testWidgets('el alta individual crea la ficha y muestra el error de la base (US-30 E3)', (tester) async {
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Nueva voluntaria'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'RUT'), '211900083');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Camila');
      await tester.enterText(find.widgetWithText(TextFormField, 'Apellidos'), 'Rojas Pérez');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo institucional'), 'camila@gmail.com');
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();
      expect(find.text('Usa el correo @ninaspro.cl'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo institucional'), 'camila.rojas@ninaspro.cl');
      voluntariado.rechazo = 'Ya existe una cuenta con el correo camila.rojas@ninaspro.cl.';
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una cuenta con el correo camila.rojas@ninaspro.cl.'), findsOneWidget);

      voluntariado.rechazo = null;
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();
      expect(voluntariado.lista.where((f) => f.correo == 'camila.rojas@ninaspro.cl'), hasLength(1));
      expect(
        find.text('✅ Ficha creada y correo autorizado. Falta registrar su declaración de adhesión.'),
        findsOneWidget,
      );
      expect(find.text('Camila Rojas Pérez'), findsOneWidget);
    });

    testWidgets('la carga masiva revisa, descarga las rechazadas y carga las válidas (US-30 E1)', (tester) async {
      final csv = csvUtf8([
        columnasPlantillaVoluntariado,
        ['21.190.010-5', 'Ana', 'Uno', 'ana@ninaspro.cl', '', '', 'Tutora', ''],
        ['21.190.014-1', 'Bea', 'Dos', 'bea@ninaspro.cl', '', '', 'Tutora', ''],
        ['21.190.011-3', 'Cata', 'Tres', 'cata@ninaspro.cl', '', '', 'Equipo de Gestión', '01-03-2026'],
      ]);
      elegirArchivo = (_) async => ArchivoAdjunto(nombre: 'voluntarias.csv', bytes: Uint8List.fromList(csv));

      await abrirVoluntariado(tester);
      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar plantilla'));
      expect(ultimaDescarga!.nombre, 'plantilla_voluntariado.csv');

      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
      expect(voluntariado.llamadas, ['revisar:sede-beauchef']);
      expect(find.text('2 nuevas'), findsOneWidget);
      expect(find.text('1 rechazadas'), findsOneWidget);
      expect(find.text('RUT inválido (dígito verificador)'), findsOneWidget);

      await tester.tap(find.text('Descargar filas rechazadas'));
      expect(ultimaDescarga!.nombre, 'rechazadas_voluntarias.csv');
      expect(utf8.decode(ultimaDescarga!.bytes.skip(3).toList()), contains('3,21.190.014-1,Bea Dos,RUT inválido'));

      await tester.tap(find.text('Cargar 2 y rechazar 1'));
      await tester.pumpAndSettle();
      expect(
        voluntariado.lista.where((f) => f.correo == 'ana@ninaspro.cl' || f.correo == 'cata@ninaspro.cl'),
        hasLength(2),
      );
      expect(find.textContaining('2 fichas nuevas y 0 actualizadas · 1 filas rechazadas'), findsOneWidget);
    });

    testWidgets('una planilla con otras columnas se rechaza completa', (tester) async {
      elegirArchivo = (_) async => ArchivoAdjunto(nombre: 'alumnas.csv', bytes: plantillaAlumnasCsv());
      await abrirVoluntariado(tester);
      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('alumnas.csv fue rechazada completa'), findsOneWidget);
      expect(voluntariado.llamadas, isEmpty);
    });
  });

  group('Catálogo de roles (US-43 E1)', () {
    testWidgets('crea un rol obligatorio, avisa nombres parecidos y desactiva uno con asignaciones', (tester) async {
      final roles = FakeRolesRepository()..asignar('clase-1', 'perfil-daniela', ['rol-presentar']);
      await abrir(tester, AjustesRolesView(repository: roles));

      expect(find.text('4 roles que Gestión asigna en cada clase · 3 obligatorios'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);

      await tester.tap(find.text('Nuevo rol'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del rol'), 'presentar la clase');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe el rol "Presentar la Clase"'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del rol'), 'Logística');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Obligatorio en cada clase'));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(roles.catalogo.last.nombre, 'Logística');
      expect(roles.catalogo.last.esRequerido, isTrue);
      expect(find.text('✅ Rol creado.'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar Presentar la Clase'));
      await tester.pumpAndSettle();
      expect(find.text('¿Desactivar "Presentar la Clase"?'), findsOneWidget);
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      expect(roles.catalogo.firstWhere((r) => r.id == 'rol-presentar').activo, isFalse);
      expect(find.text('Inactivo'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Reactivar Presentar la Clase'));
      await tester.pumpAndSettle();
      expect(roles.catalogo.firstWhere((r) => r.id == 'rol-presentar').activo, isTrue);
    });
  });
}
