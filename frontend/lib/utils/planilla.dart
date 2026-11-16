import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/hub_models.dart';

/// Lectura de planillas CSV (UTF-8) y XLSX para las cargas masivas (US-07, US-08).
///
/// El archivo se lee en el navegador: aquí se revisa la estructura (formato,
/// codificación y columnas de la plantilla) y se convierten las fechas a ISO.
/// Las reglas de cada fila (RUT, contacto del apoderado, duplicados) las valida
/// la base al previsualizar, que es la fuente de verdad.

/// Columnas de la plantilla de nómina de alumnas, en orden
const columnasPlantillaAlumnas = [
  'rut',
  'nombres',
  'apellidos',
  'fecha_nacimiento',
  'correo_alumna',
  'establecimiento',
  'curso_escolar',
  'rut_apoderado',
  'nombres_apoderado',
  'apellidos_apoderado',
  'telefono_apoderado',
  'correo_apoderado',
  'parentesco',
];

/// Fila de ejemplo de la plantilla descargable
const _ejemploPlantillaAlumnas = [
  '22.341.890-2',
  'María José',
  'Muñoz Ñancupil',
  '15-04-2011',
  '',
  'Liceo Carmela Carvajal',
  '1° medio',
  '',
  'Marcela',
  'Ñancupil Pérez',
  '+56 9 8765 4321',
  'marcela.nancupil@correo.cl',
  'Madre',
];

/// Columnas que se envían con nombre distinto al de la plantilla
const _claveFilaAlumnas = {'correo_alumna': 'correo'};

/// La planilla no se pudo leer o no respeta la plantilla: se rechaza completa
class PlanillaInvalida implements Exception {
  final String mensaje;

  const PlanillaInvalida(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Planilla leída: encabezados y filas con su número en el archivo (la fila 1 son los encabezados)
class PlanillaLeida {
  final String nombreArchivo;
  final List<String> encabezados;
  final List<({int numero, List<String> celdas})> filas;

  const PlanillaLeida({required this.nombreArchivo, required this.encabezados, required this.filas});
}

/// Lee un CSV o XLSX según su extensión
PlanillaLeida leerPlanilla(Uint8List bytes, String nombreArchivo) {
  final extension = nombreArchivo.toLowerCase().split('.').last;
  final List<List<String>> tabla = switch (extension) {
    'csv' => _leerCsv(bytes),
    'xlsx' => _leerXlsx(bytes),
    _ => throw const PlanillaInvalida('El archivo debe ser CSV (UTF-8) o XLSX.'),
  };

  final conDatos = <({int numero, List<String> celdas})>[];
  for (var i = 0; i < tabla.length; i++) {
    if (tabla[i].any((c) => c.trim().isNotEmpty)) conDatos.add((numero: i + 1, celdas: tabla[i]));
  }
  if (conDatos.isEmpty) throw const PlanillaInvalida('El archivo está vacío.');

  final encabezados = conDatos.first.celdas.map((c) => c.trim()).toList();
  while (encabezados.isNotEmpty && encabezados.last.isEmpty) {
    encabezados.removeLast();
  }
  return PlanillaLeida(nombreArchivo: nombreArchivo, encabezados: encabezados, filas: conDatos.skip(1).toList());
}

List<List<String>> _leerCsv(Uint8List bytes) {
  final String texto;
  try {
    texto = utf8.decode(bytes);
  } on FormatException {
    throw const PlanillaInvalida(
      'El archivo no está en UTF-8. En Excel usa "Guardar como" → "CSV UTF-8 (delimitado por comas)".',
    );
  }
  return parsearCsv(texto.startsWith('﻿') ? texto.substring(1) : texto);
}

List<List<String>> _leerXlsx(Uint8List bytes) {
  final Excel libro;
  try {
    libro = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const PlanillaInvalida('No pudimos abrir el archivo XLSX. Revisa que no esté dañado ni protegido.');
  }
  final hoja = libro.tables.values.firstOrNull;
  if (hoja == null) throw const PlanillaInvalida('El archivo XLSX no tiene hojas.');
  return [
    for (final fila in hoja.rows) [for (final celda in fila) _textoCelda(celda?.value)],
  ];
}

String _textoCelda(CellValue? valor) => switch (valor) {
  null => '',
  TextCellValue() => valor.value.toString(),
  DateCellValue() => _iso(DateTime(valor.year, valor.month, valor.day)),
  DateTimeCellValue() => _iso(DateTime(valor.year, valor.month, valor.day)),
  IntCellValue() => '${valor.value}',
  DoubleCellValue() => valor.value == valor.value.roundToDouble() ? '${valor.value.toInt()}' : '${valor.value}',
  _ => valor.toString(),
};

/// CSV según RFC 4180 con comillas dobles. El separador (coma o punto y coma,
/// como exporta Excel en español) se detecta en la primera línea.
List<List<String>> parsearCsv(String texto) {
  final primeraLinea = texto.split('\n').first;
  final separador = ';'.allMatches(primeraLinea).length > ','.allMatches(primeraLinea).length ? ';' : ',';

  final filas = <List<String>>[];
  var fila = <String>[];
  final celda = StringBuffer();
  var entreComillas = false;

  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (entreComillas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          celda.write('"');
          i++;
        } else {
          entreComillas = false;
        }
      } else {
        celda.write(c);
      }
    } else if (c == '"') {
      entreComillas = true;
    } else if (c == separador) {
      fila.add(celda.toString());
      celda.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') i++;
      fila.add(celda.toString());
      celda.clear();
      filas.add(fila);
      fila = <String>[];
    } else {
      celda.write(c);
    }
  }
  if (celda.isNotEmpty || fila.isNotEmpty) {
    fila.add(celda.toString());
    filas.add(fila);
  }
  return filas;
}

/// 'Correo Alumna ' -> 'correo_alumna' (tolera mayúsculas, tildes y espacios)
String _normalizarEncabezado(String texto) {
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final minusculas = texto.trim().toLowerCase().split('').map((c) => tildes[c] ?? c).join();
  return minusculas.replaceAll(RegExp(r'[\s\-]+'), '_');
}

/// Mensaje de error si los encabezados no son exactamente los de la plantilla (US-08 escenario 1)
String? validarEncabezados(List<String> encabezados, List<String> plantilla) {
  final leidos = encabezados.map(_normalizarEncabezado).toList();
  final faltan = plantilla.where((c) => !leidos.contains(c)).toList();
  final sobran = [
    for (var i = 0; i < leidos.length; i++)
      if (!plantilla.contains(leidos[i])) encabezados[i].trim().isEmpty ? '(columna ${i + 1} sin nombre)' : encabezados[i].trim(),
  ];
  final repetidas = {for (final c in leidos) if (leidos.where((x) => x == c).length > 1) c};

  final problemas = [
    if (faltan.isNotEmpty) 'Faltan columnas: ${faltan.join(', ')}.',
    if (sobran.isNotEmpty) 'Columnas que no son de la plantilla: ${sobran.join(', ')}.',
    if (repetidas.isNotEmpty) 'Columnas repetidas: ${repetidas.join(', ')}.',
  ];
  if (problemas.isEmpty) {
    final desalineadas = [
      for (var i = 0; i < plantilla.length; i++)
        if (leidos[i] != plantilla[i]) 'la columna ${i + 1} debe ser "${plantilla[i]}" (dice "${encabezados[i].trim()}")',
    ];
    if (desalineadas.isNotEmpty) problemas.add('Columnas desalineadas: ${desalineadas.join('; ')}.');
  }
  return problemas.isEmpty ? null : '${problemas.join(' ')} Descarga la plantilla y copia tus datos en ella.';
}

/// Filas de la nómina listas para la RPC importar_alumnas. Lanza [PlanillaInvalida]
/// si la estructura no respeta la plantilla.
List<Map<String, Object?>> filasNominaAlumnas(PlanillaLeida planilla) {
  final error = validarEncabezados(planilla.encabezados, columnasPlantillaAlumnas);
  if (error != null) throw PlanillaInvalida(error);
  if (planilla.filas.isEmpty) throw const PlanillaInvalida('La planilla no tiene filas con datos.');

  return [
    for (final f in planilla.filas)
      {
        'fila': f.numero,
        for (var i = 0; i < columnasPlantillaAlumnas.length; i++)
          _claveFilaAlumnas[columnasPlantillaAlumnas[i]] ?? columnasPlantillaAlumnas[i]: _valor(
            columnasPlantillaAlumnas[i],
            i < f.celdas.length ? f.celdas[i].trim() : '',
          ),
      },
  ];
}

String _valor(String columna, String texto) => columna == 'fecha_nacimiento' ? fechaIso(texto) ?? texto : texto;

/// '15-04-2011', '15/4/2011', '2011-04-15' o el número de serie de Excel -> '2011-04-15'.
/// Devuelve null si no se reconoce (la base informará la fila como inválida).
String? fechaIso(String texto) {
  final t = texto.trim();
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
  final chilena = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(t);
  final DateTime? fecha;
  if (iso != null) {
    fecha = _fechaReal(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  } else if (chilena != null) {
    fecha = _fechaReal(int.parse(chilena[3]!), int.parse(chilena[2]!), int.parse(chilena[1]!));
  } else if (RegExp(r'^\d{4,5}$').hasMatch(t)) {
    // Serie de Excel: días desde el 30-12-1899
    fecha = DateTime.utc(1899, 12, 30).add(Duration(days: int.parse(t)));
  } else {
    fecha = null;
  }
  return fecha == null ? null : _iso(fecha);
}

DateTime? _fechaReal(int anio, int mes, int dia) {
  final f = DateTime.utc(anio, mes, dia);
  return f.year == anio && f.month == mes && f.day == dia ? f : null;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Celda CSV con comillas si hace falta
String _celdaCsv(String valor) =>
    RegExp(r'[",;\n\r]').hasMatch(valor) ? '"${valor.replaceAll('"', '""')}"' : valor;

/// CSV en UTF-8 con BOM (Excel lo abre con las tildes correctas)
Uint8List csvUtf8(List<List<String>> filas) {
  final texto = filas.map((f) => f.map(_celdaCsv).join(',')).join('\r\n');
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$texto\r\n')]);
}

/// Plantilla descargable de la nómina de alumnas
Uint8List plantillaAlumnasCsv() => csvUtf8([columnasPlantillaAlumnas, _ejemploPlantillaAlumnas]);

/// Reporte de filas rechazadas con su número de fila y motivo (US-08 escenario 2)
Uint8List reporteRechazadasCsv(ResultadoImportacion resultado) => csvUtf8([
  const ['fila', 'rut', 'nombre', 'motivo'],
  for (final f in resultado.filas.where((f) => f.estado == EstadoFilaImportacion.invalida))
    ['${f.numeroFila}', f.rut, f.nombre, f.motivo ?? ''],
]);
