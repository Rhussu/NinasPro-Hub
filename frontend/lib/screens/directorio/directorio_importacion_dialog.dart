import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import 'directorio_widgets.dart';

/// Diálogo de carga masiva simulada (US-07, US-08, US-30).
///
/// 1. Se elige el destino (curso o sede) y se "sube" la planilla: en el mockup se elige
///    entre una planilla de ejemplo válida o una que no respeta la plantilla.
/// 2. Se muestra la previsualización: filas nuevas, existentes e inválidas con su motivo.
/// 3. "Confirmar carga" guarda las filas válidas.
///
/// Devuelve la cantidad de registros guardados, o null si se canceló.
Future<int?> mostrarDialogoImportacion(
  BuildContext context, {
  required String titulo,
  required String etiquetaDestino,
  required Map<String, String> destinos,
  required List<String> columnasPlantilla,
  required String etiquetaDetalle,
  required Future<ResultadoImportacion> Function(String destinoId, bool columnasValidas) previsualizar,
  required Future<int> Function(String destinoId) confirmar,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _DialogoImportacion(
      titulo: titulo,
      etiquetaDestino: etiquetaDestino,
      destinos: destinos,
      columnasPlantilla: columnasPlantilla,
      etiquetaDetalle: etiquetaDetalle,
      previsualizar: previsualizar,
      confirmar: confirmar,
    ),
  );
}

class _DialogoImportacion extends StatefulWidget {
  final String titulo;
  final String etiquetaDestino;
  final Map<String, String> destinos;
  final List<String> columnasPlantilla;
  final String etiquetaDetalle;
  final Future<ResultadoImportacion> Function(String destinoId, bool columnasValidas) previsualizar;
  final Future<int> Function(String destinoId) confirmar;

  const _DialogoImportacion({
    required this.titulo,
    required this.etiquetaDestino,
    required this.destinos,
    required this.columnasPlantilla,
    required this.etiquetaDetalle,
    required this.previsualizar,
    required this.confirmar,
  });

  @override
  State<_DialogoImportacion> createState() => _DialogoImportacionState();
}

class _DialogoImportacionState extends State<_DialogoImportacion> {
  late String _destinoId = widget.destinos.keys.first;
  ResultadoImportacion? _resultado;
  bool _procesando = false;

  Future<void> _subir(bool columnasValidas) async {
    setState(() => _procesando = true);
    final resultado = await widget.previsualizar(_destinoId, columnasValidas);
    if (!mounted) return;
    setState(() {
      _resultado = resultado;
      _procesando = false;
    });
  }

  Future<void> _confirmar() async {
    setState(() => _procesando = true);
    final guardados = await widget.confirmar(_destinoId);
    if (!mounted) return;
    Navigator.pop(context, guardados);
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;
    final validas = resultado == null || resultado.errorColumnas != null
        ? 0
        : resultado.filas.where((f) => f.estado != EstadoFilaImportacion.invalida).length;

    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: resultado == null
              ? _buildPasoSubida()
              : VistaPreviaImportacion(
                  resultado: resultado,
                  destino: widget.destinos[_destinoId] ?? '',
                  etiquetaDetalle: widget.etiquetaDetalle,
                  onDescargarRechazadas: () =>
                      mostrarAviso(context, '📄 Reporte de filas rechazadas descargado (mockup).'),
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (resultado != null)
          TextButton(
            onPressed: _procesando ? null : () => setState(() => _resultado = null),
            child: const Text('Subir otra planilla'),
          ),
        if (resultado != null && resultado.errorColumnas == null)
          FilledButton.icon(
            onPressed: _procesando || validas == 0 ? null : _confirmar,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text('Confirmar carga ($validas)'),
          ),
      ],
    );
  }

  Widget _buildPasoSubida() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _destinoId,
          decoration: InputDecoration(labelText: widget.etiquetaDestino, border: const OutlineInputBorder()),
          items: [
            for (final e in widget.destinos.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _destinoId = v ?? _destinoId),
        ),
        const SizedBox(height: 16),
        // Zona de arrastrar y soltar (simulada)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark700 : NinasProColors.primary100.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NinasProColors.primary500, width: 1.5),
          ),
          child: _procesando
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 40, color: NinasProColors.primary500),
                    const SizedBox(height: 8),
                    const Text(
                      'Arrastra aquí tu planilla CSV o XLSX',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mockup: la subida es simulada con planillas de ejemplo.',
                      style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _subir(true),
                          icon: const Icon(Icons.description_rounded, size: 18),
                          label: const Text('Usar planilla de ejemplo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _subir(false),
                          icon: const Icon(Icons.report_problem_rounded, size: 18),
                          label: const Text('Probar planilla mal formada'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Columnas de la plantilla: ${widget.columnasPlantilla.join(', ')}',
                style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
              ),
            ),
            TextButton.icon(
              onPressed: () => mostrarAviso(context, '📄 Plantilla descargada (mockup: sin archivo real).'),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar plantilla'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Resumen de una planilla procesada: rechazo completo por estructura, o el
/// desglose de filas nuevas, existentes e inválidas con su motivo (US-07, US-08).
class VistaPreviaImportacion extends StatelessWidget {
  final ResultadoImportacion resultado;
  final String destino;
  final String etiquetaDetalle;
  final VoidCallback? onDescargarRechazadas;

  const VistaPreviaImportacion({
    super.key,
    required this.resultado,
    required this.destino,
    required this.etiquetaDetalle,
    this.onDescargarRechazadas,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (resultado.errorColumnas != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? NinasProColors.error900 : NinasProColors.error100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block_rounded, color: isDark ? NinasProColors.error300 : NinasProColors.error900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${resultado.nombreArchivo} fue rechazada completa.\n${resultado.errorColumnas}',
                style: TextStyle(color: isDark ? NinasProColors.error300 : NinasProColors.error900),
              ),
            ),
          ],
        ),
      );
    }

    final invalidas = resultado.contar(EstadoFilaImportacion.invalida);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${resultado.nombreArchivo} · ${resultado.filas.length} filas · destino: $destino',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DirectorioChip('${resultado.contar(EstadoFilaImportacion.nueva)} nuevas', tono: TonoChip.exito),
            DirectorioChip('${resultado.contar(EstadoFilaImportacion.existente)} ya existentes', tono: TonoChip.info),
            DirectorioChip('$invalidas inválidas', tono: invalidas == 0 ? TonoChip.neutro : TonoChip.error),
          ],
        ),
        const SizedBox(height: 12),
        DirectorioTabla(
          columnas: ['Fila', 'Nombre', 'RUT', etiquetaDetalle, 'Estado', 'Observación'],
          filas: [
            for (final f in resultado.filas)
              DataRow(cells: [
                DataCell(Text('${f.numeroFila}')),
                DataCell(Text(f.nombre)),
                DataCell(Text(f.rut)),
                DataCell(Text(f.detalle)),
                DataCell(DirectorioChip(
                  f.estado.label,
                  tono: switch (f.estado) {
                    EstadoFilaImportacion.nueva => TonoChip.exito,
                    EstadoFilaImportacion.existente => TonoChip.info,
                    EstadoFilaImportacion.invalida => TonoChip.error,
                  },
                )),
                DataCell(Text(f.motivo ?? '—')),
              ]),
          ],
        ),
        if (invalidas > 0 && onDescargarRechazadas != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onDescargarRechazadas,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar filas rechazadas'),
            ),
          ),
      ],
    );
  }
}
