import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart';
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
      await abrir(tester, DirectorioDesktopScreen(alumnasRepository: repo));
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
    Future<void> subir(WidgetTester tester, List<String> filas) async {
      elegir('nómina.csv', utf8.encode([columnasPlantillaAlumnas.join(','), ...filas].join('\n')));
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.tap(find.text('Carga masiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
    }

    Future<void> resolver(WidgetTester tester, int numeroFila, String accion) async {
      await tester.ensureVisible(find.byTooltip('Resolver fila $numeroFila'));
      await tester.tap(find.byTooltip('Resolver fila $numeroFila'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(accion).last);
      await tester.pumpAndSettle();
    }

    testWidgets('avisa los conflictos y los resuelve en la misma vista previa', (tester) async {
      await subir(tester, [
        fila('25.000.001-4', 'María José'),
        fila('25.000.007-0', 'Josefa'),
        fila('21.998.765-K', 'Isi'),
        fila('25.000.012-K', 'Bea'),
        fila('25.000.012-K', 'Beatriz'),
      ]);

      expect(find.text('1 nuevas'), findsOneWidget);
      expect(find.text('4 por resolver'), findsOneWidget);
      expect(find.textContaining('4 filas tienen conflictos o errores'), findsOneWidget);
      expect(find.textContaining('RUT de la alumna inválido (dígito verificador)'), findsOneWidget);
      expect(find.textContaining('Nombres: «Isidora» en la ficha, «Isi» en la planilla'), findsOneWidget);
      expect(find.textContaining('RUT repetido en la planilla (filas 5, 6)'), findsNWidgets(2));

      await tester.tap(find.text('Descargar filas por resolver'));
      expect(ultimaDescarga!.nombre, 'por_resolver_nómina.csv');
      expect(utf8.decode(ultimaDescarga!.bytes.sublist(3)), contains('3,25.000.007-0,Josefa Pérez'));

      await resolver(tester, 4, 'Actualizar la ficha con la planilla');
      expect(find.textContaining('Se actualizará la ficha con la planilla'), findsOneWidget);

      await resolver(tester, 6, 'Usar esta fila y descartar las repetidas');
      expect(find.text('1 descartadas'), findsOneWidget);

      await resolver(tester, 3, 'Corregir datos');
      await tester.enterText(find.widgetWithText(TextFormField, 'RUT'), '25.000.007-3');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('0 por resolver'), findsOneWidget);
      await tester.tap(find.text('Confirmar carga (4)'));
      await tester.pumpAndSettle();
      expect(find.text('✅ 4 alumnas inscritas.'), findsOneWidget);
      expect(find.text('Josefa Pérez'), findsOneWidget);
      expect(find.text('Beatriz Pérez'), findsOneWidget);
      expect(find.text('Bea Pérez'), findsNothing);
      // La ficha existente se actualizó y tiene ahora dos inscripciones
      expect(repo.fichas.values.where((f) => f.nombres == 'Isi'), hasLength(1));
      expect(repo.inscripciones.where((i) => i.rut == '21.998.765-K'), hasLength(2));
      expect(repo.pendientes, isEmpty);
    });

    testWidgets('lo que no se resuelve queda pendiente y se resuelve después', (tester) async {
      await subir(tester, [fila('25.000.001-4', 'María José'), fila('25.000.007-0', 'Josefa')]);

      await tester.tap(find.text('Confirmar: 1 inscripción · 1 pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('✅ 1 alumna inscrita · 1 filas quedaron en Conflictos de importación.'), findsOneWidget);
      expect(repo.pendientes.single.archivo, 'nómina.csv');

      await tester.tap(find.text('Conflictos de importación (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Con errores'), findsOneWidget);
      expect(find.text('PCB-2026-S2-BEAUCHEF\nnómina.csv'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Resolver fila 3'));
      await tester.tap(find.byTooltip('Resolver fila 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corregir datos').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'RUT'), '25.000.007-3');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('✅ Josefa Pérez quedó inscrita.'), findsOneWidget);
      expect(find.text('✅ No quedan conflictos pendientes.'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conflictos de importación ('), findsNothing);
      expect(find.text('Josefa Pérez'), findsOneWidget);
    });

    testWidgets('un pendiente que sigue sin resolverse se informa y se puede descartar', (tester) async {
      repo.correosEnUso.add('ocupada@correo.cl');
      repo.pendientes.add(ConflictoImportacion(
        id: 'conf-1',
        instanciaId: 'inst-a',
        cursoEtiqueta: 'PCB · Sede Beauchef',
        archivo: 'marzo.xlsx',
        numeroFila: 9,
        datos: {
          'fila': 9,
          'rut': '25.000.013-8',
          'nombres': 'Carla',
          'apellidos': 'Rojas',
          'correo': 'ocupada@correo.cl',
          'nombres_apoderado': 'Rosa',
          'apellidos_apoderado': 'Rojas',
          'telefono_apoderado': '+56 9 1234 5678',
          'correo_apoderado': 'rosa@correo.cl',
        },
        motivo: 'El correo de la alumna ya lo usa otra persona',
        creadoEn: DateTime(2026, 11, 16),
      ));
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await tester.tap(find.text('Conflictos de importación (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('El correo de la alumna ya lo usa otra persona'), findsOneWidget);

      // Corregir sin cambiar el correo: sigue pendiente
      await tester.ensureVisible(find.byTooltip('Resolver fila 9'));
      await tester.tap(find.byTooltip('Resolver fila 9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corregir datos').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('La fila 9 sigue pendiente'), findsOneWidget);
      expect(repo.pendientes, hasLength(1));

      await tester.ensureVisible(find.byTooltip('Resolver fila 9'));
      await tester.tap(find.byTooltip('Resolver fila 9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar fila').last);
      await tester.pumpAndSettle();
      expect(find.text('Fila 9 descartada.'), findsOneWidget);
      expect(repo.pendientes, isEmpty);
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
      expect(find.textContaining('Confirmar'), findsNothing);

      await tester.tap(find.text('Subir otra planilla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar plantilla'));
      expect(ultimaDescarga!.nombre, 'plantilla_nomina_alumnas.csv');
    });

    testWidgets('si la base rechaza la carga se muestra su mensaje', (tester) async {
      repo.errorEscritura = 'Solo la Directiva inscribe alumnas.';
      await subir(tester, [fila('25.000.001-4', 'Ana')]);
      expect(find.text('Solo la Directiva inscribe alumnas.'), findsOneWidget);
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

    Future<void> completar(WidgetTester tester, List<String> valores) async {
      await tester.tap(find.text('Inscribir alumna'));
      await tester.pumpAndSettle();
      final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
      for (final (i, texto) in valores.indexed) {
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
    }

    const apoderada = ['', 'Marcela', 'Morales', '+56 9 1234 5678', 'm@correo.cl'];

    testWidgets('si ya está inscrita en el curso muestra el motivo de la base', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await completar(tester, ['22.341.890-2', 'Valentina', 'Soto Morales', '', '', '', ...apoderada]);
      expect(find.text('Ya está inscrita en este curso'), findsOneWidget);
    });

    testWidgets('si el RUT tiene ficha con otros datos deja elegir antes de inscribir', (tester) async {
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      // Isidora está en Valparaíso; se inscribe en Beauchef con otro nombre
      await completar(tester, ['21.998.765-K', 'Isi', 'Silva Vargas', '', '', '', ...apoderada]);
      expect(find.textContaining('Nombres: «Isidora» en la ficha, «Isi» en el formulario'), findsOneWidget);

      await tester.ensureVisible(find.text('Mantener la ficha e inscribir'));
      await tester.tap(find.text('Mantener la ficha e inscribir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('✅ Alumna inscrita'), findsOneWidget);
      expect(repo.fichas.values.where((f) => f.nombres == 'Isidora'), hasLength(1));
    });

    testWidgets('si el correo está en uso deja inscribir sin correo', (tester) async {
      repo.correosEnUso.add('ocupada@correo.cl');
      await abrir(tester, DirectorioAlumnasView(repository: repo));
      await completar(tester, ['25.000.020-0', 'Elisa', 'Mora', 'ocupada@correo.cl', '', '', ...apoderada]);
      expect(find.text('El correo de la alumna ya lo usa otra persona'), findsOneWidget);

      await tester.ensureVisible(find.text('Inscribir sin correo'));
      await tester.tap(find.text('Inscribir sin correo'));
      await tester.pumpAndSettle();
      expect(find.text('Elisa Mora'), findsOneWidget);
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
}
