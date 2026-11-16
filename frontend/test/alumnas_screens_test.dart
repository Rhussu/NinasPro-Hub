import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/alumnas/pendientes_autorizacion_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_alumnas_view.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_desktop_screen.dart';
import 'package:ninas_pro_hub/services/descargas.dart';
import 'package:ninas_pro_hub/services/selector_archivos.dart';
import 'package:ninas_pro_hub/utils/planilla.dart';

import 'fakes/fake_alumnas_repository.dart';

/// Nómina, carga masiva, inscripción, ficha y pendientes (US-07..US-12)
void main() {
  late FakeAlumnasRepository repo;

  setUp(() {
    repo = FakeAlumnasRepository();
    repo.agregar(
      rut: '22.341.890-2',
      nombres: 'Valentina',
      apellidos: 'Soto Morales',
      consentimiento: ConsentimientoDatos.otorgado,
      canales: const {CanalImagen.redesSociales: true, CanalImagen.prensa: true},
      documento: 'alumna-1/1_firma.pdf',
      clasesAsistidas: 3,
      clasesComputables: 4,
    );
    repo.agregar(rut: '21.904.331-7', nombres: 'Florencia', apellidos: 'Muñoz Tapia', sesionesTranscurridas: 3);
    repo.agregar(rut: '21.998.765-K', nombres: 'Isidora', apellidos: 'Silva Vargas', instanciaId: 'inst-b');
    ultimaDescarga = null;
  });

  tearDown(() => elegirArchivo = (_) async => null);

  Future<void> abrir(WidgetTester tester, Widget pantalla, {Size tamano = const Size(1440, 1000)}) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: NinasProTheme.light, home: Scaffold(body: pantalla)));
    await tester.pumpAndSettle();
  }

  void elegir(String nombre, List<int> bytes) =>
      elegirArchivo = (_) async => ArchivoAdjunto(nombre: nombre, bytes: Uint8List.fromList(bytes));

  String fila(String rut, String nombres, {String correoApoderado = 'apoderada@correo.cl'}) =>
      '$rut,$nombres,Pérez,15-04-2011,,,,,Marta,Pérez,+56 9 1234 5678,$correoApoderado,';

  group('nómina de la Directiva', () {
    testWidgets('lista una fila por inscripción con asistencia, consentimiento y estado', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));

      expect(find.text('1 activas en 2 sedes'), findsOneWidget);
      expect(find.text('Valentina Soto Morales'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('Otorgado'), findsOneWidget);
      expect(find.text('Preinscrita'), findsNWidgets(2));
      // Florencia sigue sin consentimiento tras 3 sesiones (US-11 escenario 3)
      expect(find.textContaining('1 alumna sigue sin consentimiento de datos tras 2 sesiones'), findsOneWidget);
    });

    testWidgets('busca por RUT sin puntos ni guion', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.enterText(find.byType(TextField).first, '21998765k');
      await tester.pumpAndSettle();
      expect(find.text('Isidora Silva Vargas'), findsOneWidget);
      expect(find.text('Valentina Soto Morales'), findsNothing);
    });

    testWidgets('la Directiva ve la nómina real desde la barra lateral', (tester) async {
      await abrir(tester, DirectorioDesktopScreen(repository: MockHubRepository(), alumnasRepository: repo));
      await tester.tap(find.text('Alumnas').first);
      await tester.pumpAndSettle();
      expect(find.text('Florencia Muñoz Tapia'), findsOneWidget);
    });

    testWidgets('sin instancias no se puede inscribir', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: FakeAlumnasRepository(instancias: const [])));
      expect(find.textContaining('Aún no hay alumnas inscritas'), findsOneWidget);
      final boton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Inscribir alumna'));
      expect(boton.onPressed, isNull);
    });
  });

  group('carga masiva (US-07, US-08)', () {
    testWidgets('previsualiza nuevas, existentes e inválidas, descarga las rechazadas y confirma', (tester) async {
      elegir('nómina.csv', utf8.encode([
        columnasPlantillaAlumnas.join(','),
        fila('25.000.001-4', 'María José'),
        fila('25.000.007-0', 'Josefa'),
        fila('21.998.765-K', 'Isidora'),
      ].join('\n')));
      await abrir(tester, DirectorioAlumnasView(repository: repo));

      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();

      expect(find.text('1 nuevas'), findsOneWidget);
      expect(find.text('1 ya existentes'), findsOneWidget);
      expect(find.text('1 inválidas'), findsOneWidget);
      expect(find.text('RUT de la alumna inválido (dígito verificador)'), findsOneWidget);

      await tester.tap(find.text('Descargar filas rechazadas'));
      expect(ultimaDescarga!.nombre, 'filas_rechazadas_nómina.csv');
      expect(utf8.decode(ultimaDescarga!.bytes.sublist(3)), contains('3,25.000.007-0,Josefa Pérez'));

      await tester.tap(find.text('Confirmar carga (2)'));
      await tester.pumpAndSettle();
      expect(find.text('✅ 2 alumnas inscritas · 1 filas rechazadas.'), findsOneWidget);
      expect(find.text('María José Pérez'), findsOneWidget);
      expect(repo.ultimasFilas!.map((f) => f['fila']), [2, 3, 4]);
      // La ficha existente se reutiliza: Isidora tiene ahora dos inscripciones
      expect(repo.inscripciones.where((i) => i.nombres == 'Isidora'), hasLength(2));
    });

    testWidgets('una planilla que no respeta la plantilla se rechaza completa', (tester) async {
      elegir('nomina.csv', utf8.encode('nombre,rut\nAna,1-9'));
      await abrir(tester, DirectorioAlumnasView(repository: repo));

      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('fue rechazada completa'), findsOneWidget);
      expect(find.textContaining('Faltan columnas'), findsOneWidget);
      expect(find.textContaining('Confirmar carga'), findsNothing);

      await tester.tap(find.text('Subir otra planilla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar plantilla'));
      expect(ultimaDescarga!.nombre, 'plantilla_nomina_alumnas.csv');
    });

    testWidgets('si la base rechaza la carga se muestra su mensaje', (tester) async {
      elegir('nomina.csv', utf8.encode('${columnasPlantillaAlumnas.join(',')}\n${fila('25.000.001-4', 'Ana')}'));
      repo.errorEscritura = 'Solo la Directiva o el Equipo de Gestión de la sede inscriben alumnas.';
      await abrir(tester, DirectorioAlumnasView(repository: repo));

      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
      expect(find.text('Solo la Directiva o el Equipo de Gestión de la sede inscriben alumnas.'), findsOneWidget);
    });
  });

  group('inscripción individual (US-09)', () {
    testWidgets('valida el RUT y el contacto, e inscribe con la fecha de nacimiento', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.tap(find.text('Inscribir alumna'));
      await tester.pumpAndSettle();

      final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
      await tester.enterText(campos.at(0), '25.000.007-0');
      await tester.tap(find.text('Inscribir'));
      await tester.pumpAndSettle();
      expect(find.text('RUT inválido (revisa el dígito verificador)'), findsOneWidget);
      expect(find.text('Indica la fecha de nacimiento.'), findsOneWidget);

      await tester.enterText(campos.at(0), '25.000.001-4');
      await tester.enterText(campos.at(1), 'Amanda');
      await tester.enterText(campos.at(2), 'Núñez');
      await tester.enterText(campos.at(7), 'Rosa');
      await tester.enterText(campos.at(8), 'Núñez');
      await tester.enterText(campos.at(9), '+56 9 1111 2222');
      await tester.enterText(campos.at(10), 'rosa@correo.cl');
      await tester.ensureVisible(find.text('Fecha de nacimiento'));
      await tester.tap(find.text('Fecha de nacimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Inscribir'));
      await tester.tap(find.text('Inscribir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('✅ Alumna inscrita'), findsOneWidget);
      expect(find.text('Amanda Núñez'), findsOneWidget);
    });

    testWidgets('si ya está inscrita en el curso muestra el motivo de la base', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.tap(find.text('Inscribir alumna'));
      await tester.pumpAndSettle();

      final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
      for (final (i, texto) in ['22.341.890-2', 'Valentina', 'Soto', '', '', '', '', 'Marcela', 'Morales', '+56 9 1', 'm@correo.cl'].indexed) {
        await tester.enterText(campos.at(i), texto);
      }
      await tester.ensureVisible(find.text('Fecha de nacimiento'));
      await tester.tap(find.text('Fecha de nacimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Inscribir'));
      await tester.tap(find.text('Inscribir'));
      await tester.pumpAndSettle();
      expect(find.text('Ya está inscrita en este curso'), findsOneWidget);
    });
  });

  group('ficha de la alumna (US-09, US-10, US-12)', () {
    Future<void> abrirFicha(WidgetTester tester, String nombre) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
      expect(find.text('Autorizaciones del apoderado/a'), findsOneWidget);
    }

    testWidgets('otorgar el consentimiento exige el respaldo y activa la matrícula', (tester) async {
      await abrirFicha(tester, 'Florencia Muñoz Tapia');
      expect(find.text('Sin documento firmado adjunto'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(SegmentedButton<ConsentimientoDatos>), matching: find.text('Otorgado')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar autorizaciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Adjunta el documento firmado'), findsOneWidget);

      elegir('autorización.docx', [1, 2, 3]);
      await tester.ensureVisible(find.text('Adjuntar respaldo'));
      await tester.tap(find.text('Adjuntar respaldo'));
      await tester.pumpAndSettle();
      expect(find.text('El respaldo debe ser PDF, PNG o JPG.'), findsOneWidget);

      elegir('autorización.pdf', [1, 2, 3]);
      await tester.ensureVisible(find.text('Adjuntar respaldo'));
      await tester.tap(find.text('Adjuntar respaldo'));
      await tester.pumpAndSettle();
      expect(find.text('autorización.pdf (se sube al guardar)'), findsOneWidget);

      final filaMemoria = find.ancestor(of: find.text('Memoria anual'), matching: find.byType(Row)).first;
      await tester.ensureVisible(filaMemoria);
      await tester.tap(find.descendant(of: filaMemoria, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar autorizaciones'));
      await tester.pumpAndSettle();

      expect(find.text('✅ Autorizaciones guardadas.'), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Activa')), findsOneWidget, reason: 'la inscripción pasa sola a activa (US-11)');
      expect(find.textContaining('por Camila Sepúlveda'), findsOneWidget);
      final a = repo.fichas.values.firstWhere((f) => f.nombres == 'Florencia').autorizaciones;
      expect(a.autorizado(CanalImagen.memoriaAnual), isTrue);
      expect(a.autorizado(CanalImagen.prensa), isFalse, reason: 'sin respuesta = no autorizado (RB-2)');
      expect(repo.respaldos.values.single, 'autorización.pdf');
    });

    testWidgets('revoca un canal con fecha y motivo', (tester) async {
      await abrirFicha(tester, 'Valentina Soto Morales');
      expect(find.text('firma.pdf'), findsOneWidget);

      await tester.tap(find.text('Revocar autorización'));
      await tester.pumpAndSettle();
      // Solo se ofrecen los canales autorizados, todos marcados
      expect(find.widgetWithText(CheckboxListTile, 'Redes sociales'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Memoria anual'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Redes sociales'));
      await tester.enterText(find.widgetWithText(TextField, 'Motivo'), 'Solicitud de la apoderada');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revocar'));
      await tester.pumpAndSettle();

      expect(find.text('🚫 Revocación registrada. Rige desde la fecha indicada.'), findsOneWidget);
      expect(find.textContaining('Revocada desde'), findsOneWidget);
      final a = repo.fichas['alumna-1']!.autorizaciones;
      expect(a.autorizado(CanalImagen.prensa), isFalse);
      expect(a.autorizado(CanalImagen.redesSociales), isTrue);
      expect(a.revocaciones[CanalImagen.prensa]!.motivo, 'Solicitud de la apoderada');
    });

    testWidgets('registra el retiro de una inscripción conservando su historial', (tester) async {
      await abrirFicha(tester, 'Valentina Soto Morales');

      await tester.tap(find.text('Registrar retiro'));
      await tester.pumpAndSettle();
      final confirmar = find.widgetWithText(FilledButton, 'Registrar retiro');
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull, reason: 'el motivo es obligatorio');
      await tester.enterText(find.widgetWithText(TextField, 'Motivo formal'), 'Cambio de colegio');
      await tester.pumpAndSettle();
      await tester.tap(confirmar);
      await tester.pumpAndSettle();

      expect(find.text('Retiro registrado. Su historial de asistencia se conserva.'), findsOneWidget);
      expect(find.text('Retirada'), findsOneWidget);
      expect(find.textContaining('Cambio de colegio'), findsOneWidget);
      expect(find.textContaining('asistencia 75.0% (3/4)'), findsOneWidget);
    });
  });

  group('pendientes de regularización en Gestión (US-11)', () {
    testWidgets('la tarjeta del panel cuenta las preinscritas y destaca las urgentes', (tester) async {
      await abrir(
        tester,
        TarjetaAutorizacionesPendientes(repository: repo),
        tamano: const Size(400, 800),
      );
      expect(find.text('2 alumnas esperan su consentimiento'), findsOneWidget);
      expect(find.text('1 sin regularizar tras 2 sesiones: no pueden pasar lista'), findsOneWidget);

      await tester.tap(find.text('2 alumnas esperan su consentimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Autorizaciones pendientes'), findsOneWidget);
      // La urgente va primero
      final florencia = tester.getTopLeft(find.text('Florencia Muñoz Tapia')).dy;
      final isidora = tester.getTopLeft(find.text('Isidora Silva Vargas')).dy;
      expect(florencia, lessThan(isidora));
      expect(find.textContaining('Sin consentimiento tras 3 sesiones'), findsOneWidget);

      // En el celular la ficha ocupa toda la pantalla
      await tester.tap(find.text('Florencia Muñoz Tapia'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Autorizaciones del apoderado/a'), findsOneWidget);
    });

    testWidgets('sin pendientes la tarjeta no se muestra', (tester) async {
      final vacio = FakeAlumnasRepository();
      await abrir(tester, TarjetaAutorizacionesPendientes(repository: vacio), tamano: const Size(400, 800));
      expect(find.byType(Card), findsNothing);

      await abrir(tester, PendientesAutorizacionScreen(repository: vacio), tamano: const Size(400, 800));
      expect(find.textContaining('Todas las alumnas tienen su consentimiento'), findsOneWidget);
    });
  });
}
