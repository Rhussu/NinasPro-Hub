import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/utils/planilla.dart';

/// Lectura de planillas CSV/XLSX de la nómina (US-07, US-08)
void main() {
  final encabezado = columnasPlantillaAlumnas.join(',');
  const filaValida =
      '22.341.890-2,María José,Muñoz Ñancupil,15-04-2011,mj@correo.cl,Liceo 1,1° medio,,Marcela,Ñancupil,+56 9 8765 4321,marcela@correo.cl,Madre';

  Uint8List csv(String texto) => Uint8List.fromList(utf8.encode(texto));

  group('CSV', () {
    test('separa por coma o punto y coma y respeta las comillas', () {
      expect(parsearCsv('a,"b, c","d ""e"""\r\n1,2,3'), [
        ['a', 'b, c', 'd "e"'],
        ['1', '2', '3'],
      ]);
      expect(parsearCsv('a;b;c\n1;2,5;3\n'), [
        ['a', 'b', 'c'],
        ['1', '2,5', '3'],
      ]);
    });

    test('lee un CSV UTF-8 con BOM, tildes, diéresis y ñ sin perder caracteres', () {
      final planilla = leerPlanilla(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$encabezado\n$filaValida\n\n')]),
        'nomina.csv',
      );
      expect(planilla.encabezados, columnasPlantillaAlumnas);
      expect(planilla.filas, hasLength(1), reason: 'las filas vacías se ignoran');

      final filas = filasNominaAlumnas(planilla);
      expect(filas.single['fila'], 2);
      expect(filas.single['nombres'], 'María José');
      expect(filas.single['apellidos'], 'Muñoz Ñancupil');
      expect(filas.single['fecha_nacimiento'], '2011-04-15');
      expect(filas.single['correo'], 'mj@correo.cl', reason: 'correo_alumna se envía como correo');
      expect(filas.single.containsKey('correo_alumna'), isFalse);
    });

    test('rechaza un archivo que no está en UTF-8', () {
      // "Muñoz" en Latin-1: la ñ es el byte 0xF1
      final latin1 = Uint8List.fromList([...utf8.encode('$encabezado\nMu'), 0xF1, ...utf8.encode('oz')]);
      expect(
        () => leerPlanilla(latin1, 'nomina.csv'),
        throwsA(isA<PlanillaInvalida>().having((e) => e.mensaje, 'mensaje', contains('UTF-8'))),
      );
    });

    test('rechaza extensiones que no son CSV ni XLSX y archivos vacíos', () {
      expect(() => leerPlanilla(csv('x'), 'nomina.pdf'), throwsA(isA<PlanillaInvalida>()));
      expect(() => leerPlanilla(csv('\n\n'), 'nomina.csv'), throwsA(isA<PlanillaInvalida>()));
      expect(
        () => filasNominaAlumnas(leerPlanilla(csv(encabezado), 'nomina.csv')),
        throwsA(isA<PlanillaInvalida>().having((e) => e.mensaje, 'mensaje', contains('no tiene filas'))),
      );
    });
  });

  group('XLSX', () {
    test('lee una planilla con acentos, ñ, nombres compuestos y fechas de Excel', () {
      final libro = Excel.createExcel();
      final hoja = libro[libro.getDefaultSheet()!];
      hoja.appendRow([for (final c in columnasPlantillaAlumnas) TextCellValue(c)]);
      hoja.appendRow([
        TextCellValue('22.341.890-2'),
        TextCellValue('Zoë Anaïs'),
        TextCellValue('Güemes Ñuñoa'),
        DateCellValue(year: 2011, month: 4, day: 15),
        null,
        TextCellValue('Liceo Señora de Fátima'),
        TextCellValue('2° medio'),
        null,
        TextCellValue('José Ángel'),
        TextCellValue('Güemes'),
        IntCellValue(56987654321),
        TextCellValue('jose@correo.cl'),
        TextCellValue('Padre'),
      ]);
      final bytes = Uint8List.fromList(libro.encode()!);

      final filas = filasNominaAlumnas(leerPlanilla(bytes, 'Nómina.XLSX'));
      expect(filas.single['nombres'], 'Zoë Anaïs');
      expect(filas.single['apellidos'], 'Güemes Ñuñoa');
      expect(filas.single['establecimiento'], 'Liceo Señora de Fátima');
      expect(filas.single['fecha_nacimiento'], '2011-04-15');
      expect(filas.single['telefono_apoderado'], '56987654321');
      expect(filas.single['correo'], '');
    });

    test('rechaza un XLSX dañado', () {
      expect(() => leerPlanilla(csv('no es un zip'), 'nomina.xlsx'), throwsA(isA<PlanillaInvalida>()));
    });
  });

  group('estructura de columnas (US-08 escenario 1)', () {
    test('acepta mayúsculas, tildes y espacios en los encabezados', () {
      expect(
        validarEncabezados([for (final c in columnasPlantillaAlumnas) ' ${c.replaceAll('_', ' ').toUpperCase()} '], columnasPlantillaAlumnas),
        isNull,
      );
    });

    test('informa las columnas que faltan y las que sobran', () {
      final error = validarEncabezados(
        [...columnasPlantillaAlumnas.where((c) => c != 'correo_apoderado'), 'comuna'],
        columnasPlantillaAlumnas,
      )!;
      expect(error, contains('Faltan columnas: correo_apoderado.'));
      expect(error, contains('Columnas que no son de la plantilla: comuna.'));
      expect(error, contains('Descarga la plantilla'));
    });

    test('informa las columnas desalineadas aunque estén todas', () {
      final desordenadas = [...columnasPlantillaAlumnas]
        ..[1] = 'apellidos'
        ..[2] = 'nombres';
      final error = validarEncabezados(desordenadas, columnasPlantillaAlumnas)!;
      expect(error, contains('la columna 2 debe ser "nombres" (dice "apellidos")'));
    });

    test('una planilla mal formada se rechaza completa', () {
      expect(
        () => filasNominaAlumnas(leerPlanilla(csv('nombre,rut\nAna,1-9'), 'nomina.csv')),
        throwsA(isA<PlanillaInvalida>().having((e) => e.mensaje, 'mensaje', contains('Faltan columnas'))),
      );
    });
  });

  group('fechas', () {
    test('convierte los formatos chilenos, ISO y la serie de Excel', () {
      expect(fechaIso('15-04-2011'), '2011-04-15');
      expect(fechaIso('5/4/2011'), '2011-04-05');
      expect(fechaIso('2011-4-5'), '2011-04-05');
      expect(fechaIso('40648'), '2011-04-15');
      expect(fechaIso('30-02-2011'), isNull, reason: 'el 30 de febrero no existe');
      expect(fechaIso('ayer'), isNull);
    });

    test('una fecha no reconocida se envía tal cual para que la base la informe', () {
      final planilla = leerPlanilla(csv('$encabezado\n${filaValida.replaceFirst('15-04-2011', 'abril')}'), 'n.csv');
      expect(filasNominaAlumnas(planilla).single['fecha_nacimiento'], 'abril');
    });
  });

  group('archivos descargables', () {
    test('la plantilla es un CSV UTF-8 con BOM que se vuelve a leer sin errores', () {
      final bytes = plantillaAlumnasCsv();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final filas = filasNominaAlumnas(leerPlanilla(bytes, 'plantilla.csv'));
      expect(filas.single['apellidos'], 'Muñoz Ñancupil');
    });

    test('el reporte de filas por resolver lista fila, RUT, nombre y motivo', () {
      final texto = utf8.decode(
        reporteFilasCsv([
          (fila: 7, rut: '25.000.007-0', nombre: 'Josefa, la segunda', motivo: 'RUT de la alumna inválido (dígito verificador)'),
        ]).sublist(3),
      );
      expect(texto, 'fila,rut,nombre,motivo\r\n7,25.000.007-0,"Josefa, la segunda",RUT de la alumna inválido (dígito verificador)\r\n');
    });
  });
}
