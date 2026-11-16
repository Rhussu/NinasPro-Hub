import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../services/descargas.dart';
import 'planilla.dart' show csvUtf8;

/// Exportación de listados a CSV o XLSX (US-21, US-22, US-32 escenario 3).
enum FormatoExportacion {
  csv('CSV', 'csv', 'text/csv;charset=utf-8'),
  xlsx('Excel (XLSX)', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

  final String etiqueta;
  final String extension;
  final String tipo;

  const FormatoExportacion(this.etiqueta, this.extension, this.tipo);
}

/// Libro XLSX con una hoja: la primera fila son los encabezados
Uint8List xlsxTabla(String hoja, List<List<String>> filas) {
  final libro = Excel.createExcel();
  final inicial = libro.getDefaultSheet() ?? 'Sheet1';
  libro.rename(inicial, hoja);
  final tabla = libro[hoja];
  for (final fila in filas) {
    tabla.appendRow([for (final celda in fila) TextCellValue(celda)]);
  }
  return Uint8List.fromList(libro.encode()!);
}

/// Bytes del archivo en el formato pedido
Uint8List archivoTabla(FormatoExportacion formato, String hoja, List<String> encabezados, List<List<String>> filas) {
  final tabla = [encabezados, ...filas];
  return switch (formato) {
    FormatoExportacion.csv => csvUtf8(tabla),
    FormatoExportacion.xlsx => xlsxTabla(hoja, tabla),
  };
}

/// Descarga un listado como `<nombreBase>.csv` o `.xlsx`
void exportarTabla({
  required String nombreBase,
  required String hoja,
  required List<String> encabezados,
  required List<List<String>> filas,
  required FormatoExportacion formato,
}) {
  descargarArchivo(
    '$nombreBase.${formato.extension}',
    archivoTabla(formato, hoja, encabezados, filas),
    tipo: formato.tipo,
  );
}
