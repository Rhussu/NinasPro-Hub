import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes/ajustes_cursos_view.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes/ajustes_sedes_view.dart';

import 'fakes/fake_catalogo_repository.dart';

/// Sedes y Cursos de Ajustes: nombres sin tildes, aviso de parecidos y eliminación (US-01)
void main() {
  FakeCatalogoRepository repositorio() => FakeCatalogoRepository(
    sedes: [
      const Sede(
        id: 'sede-a',
        nombre: 'Sede Beauchef',
        universidad: 'Universidad de Chile',
        region: 'Región Metropolitana',
        modalidad: 'Presencial',
        coordinadoraNombre: 'Camila Sepúlveda',
        usos: ['1 instancia de curso', '3 personas asignadas'],
      ),
      const Sede(
        id: 'sede-b',
        nombre: 'Sede Valparaíso',
        universidad: 'USM',
        region: 'Valparaíso',
        modalidad: 'Presencial',
        coordinadoraNombre: '',
      ),
    ],
    cursos: [
      const CursoCatalogo(
        id: 'cat-pcb',
        codigo: 'PCB',
        nombre: 'Programación Competitiva Básica',
        usos: ['2 instancias de curso'],
      ),
      const CursoCatalogo(id: 'cat-web', codigo: 'WEB', nombre: 'Desarrollo Web Inicial'),
    ],
  );

  Future<void> abrir(WidgetTester tester, Widget vista) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: NinasProTheme.light,
        home: Scaffold(body: vista),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> llenarSede(WidgetTester tester, String nombre) async {
    await tester.tap(find.text('Nueva sede'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la sede'), nombre);
    await tester.enterText(find.widgetWithText(TextFormField, 'Institución anfitriona'), 'Universidad');
    await tester.enterText(find.widgetWithText(TextFormField, 'Región'), 'Región');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  /// La fuente de prueba ensancha la tabla: se desplaza hasta el botón antes de tocarlo
  Future<void> tocar(WidgetTester tester, String tooltip) async {
    await tester.ensureVisible(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  IconButton boton(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)).first);

  group('Sedes', () {
    testWidgets('rechaza un nombre que solo cambia en tildes o mayúsculas', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesSedesView(repository: repo));

      await llenarSede(tester, 'sede valparaiso');
      expect(
        find.text('Ya existe la sede "Sede Valparaíso". Los nombres no distinguen tildes, mayúsculas ni signos.'),
        findsOneWidget,
      );
      expect(repo.listaSedes, hasLength(2));
    });

    testWidgets('avisa si el nombre se parece a otro y deja guardar igual', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesSedesView(repository: repo));

      await llenarSede(tester, 'Sede Beauchep');
      expect(find.text('¿Es un nombre nuevo?'), findsOneWidget);
      expect(find.text('• Sede Beauchef'), findsOneWidget);
      expect(find.textContaining('otra sede registrada'), findsOneWidget);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(repo.listaSedes, hasLength(2), reason: 'al cancelar no se guarda');

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();
      expect(repo.listaSedes.map((s) => s.nombre), contains('Sede Beauchep'));
      expect(find.text('✅ Sede creada y activa.'), findsOneWidget);
    });

    testWidgets('editar otros datos de una sede no avisa por su propio nombre', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesSedesView(repository: repo));

      await tocar(tester, 'Editar Sede Valparaíso');
      await tester.enterText(find.widgetWithText(TextFormField, 'Región'), 'Región de Valparaíso');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Es un nombre nuevo?'), findsNothing);
      expect(repo.listaSedes.last.region, 'Región de Valparaíso');
    });

    testWidgets('elimina una sede sin uso y bloquea la que se usa', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesSedesView(repository: repo));

      const enUso = 'No se puede eliminar Sede Beauchef: tiene 1 instancia de curso, 3 personas asignadas';
      expect(find.byTooltip(enUso), findsOneWidget);
      expect(boton(tester, enUso).onPressed, isNull);

      await tocar(tester, 'Eliminar Sede Valparaíso');
      expect(find.text('¿Eliminar "Sede Valparaíso"? Esta acción no se puede deshacer.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.listaSedes, hasLength(2));

      await tocar(tester, 'Eliminar Sede Valparaíso');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(repo.listaSedes.map((s) => s.nombre), ['Sede Beauchef']);
      expect(find.text('Sede "Sede Valparaíso" eliminada.'), findsOneWidget);
    });

    testWidgets('si la base impide eliminar, muestra su mensaje', (tester) async {
      final repo = repositorio()..errorEscritura = 'No se puede eliminar "Sede Valparaíso": tiene 1 acceso pendiente.';
      await abrir(tester, AjustesSedesView(repository: repo));

      await tocar(tester, 'Eliminar Sede Valparaíso');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('No se puede eliminar "Sede Valparaíso": tiene 1 acceso pendiente.'), findsOneWidget);
      expect(repo.listaSedes, hasLength(2));
    });
  });

  group('Cursos', () {
    Future<void> llenarCurso(WidgetTester tester, String codigo, String nombre) async {
      await tester.tap(find.text('Nuevo curso'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Código institucional'), codigo);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), nombre);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('el código no distingue signos y el nombre parecido pide confirmación', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesCursosView(repository: repo));

      await llenarCurso(tester, 'p.c.b', 'Otro curso');
      expect(find.text('El código "P.C.B" ya está en uso como "PCB".'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Código institucional'), 'pcb');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('El código "PCB" ya está en uso.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Código institucional'), 'pci');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Programacion Competitiva Basica');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Es un nombre nuevo?'), findsOneWidget);
      expect(find.textContaining('otro curso registrado'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();
      expect(repo.listaCursos.map((c) => c.codigo), contains('PCI'));
    });

    testWidgets('elimina un curso sin instancias y bloquea el que tiene', (tester) async {
      final repo = repositorio();
      await abrir(tester, AjustesCursosView(repository: repo));

      const enUso = 'No se puede eliminar Programación Competitiva Básica: tiene 2 instancias de curso';
      expect(boton(tester, enUso).onPressed, isNull);

      await tocar(tester, 'Eliminar Desarrollo Web Inicial');
      expect(find.text('¿Eliminar "WEB · Desarrollo Web Inicial"? Esta acción no se puede deshacer.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(repo.listaCursos.map((c) => c.codigo), ['PCB']);
      expect(find.text('Curso WEB eliminado del catálogo.'), findsOneWidget);
    });

    testWidgets('si la base impide eliminar el curso, muestra su mensaje', (tester) async {
      final repo = repositorio()..errorEscritura = 'No se puede eliminar "WEB": tiene 1 instancia de curso.';
      await abrir(tester, AjustesCursosView(repository: repo));

      await tocar(tester, 'Eliminar Desarrollo Web Inicial');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('No se puede eliminar "WEB": tiene 1 instancia de curso.'), findsOneWidget);
    });
  });
}
