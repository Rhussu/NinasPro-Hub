import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../services/descargas.dart';
import '../../services/selector_archivos.dart';
import '../../utils/planilla.dart';
import '../directorio/directorio_importacion_dialog.dart';

/// Carga masiva de la nómina desde un CSV (UTF-8) o XLSX (US-07, US-08).
///
/// 1. Se elige la instancia de destino y el archivo. La app revisa la
///    estructura: si las columnas no son las de la plantilla se rechaza completo.
/// 2. La base clasifica cada fila sin guardar nada: nuevas, ya existentes (se
///    reutiliza su ficha) e inválidas con su motivo, descargables en un CSV.
/// 3. "Confirmar carga" inscribe todas las válidas en una sola transacción.
///
/// Devuelve el resultado final, o null si se canceló.
Future<({int inscritas, int rechazadas})?> mostrarImportacionAlumnas(
  BuildContext context, {
  required AlumnasRepository repository,
  required List<Curso> instancias,
}) => showDialog(
  context: context,
  builder: (_) => _ImportacionAlumnasDialog(repository: repository, instancias: instancias),
);

class _ImportacionAlumnasDialog extends StatefulWidget {
  final AlumnasRepository repository;
  final List<Curso> instancias;

  const _ImportacionAlumnasDialog({required this.repository, required this.instancias});

  @override
  State<_ImportacionAlumnasDialog> createState() => _ImportacionAlumnasDialogState();
}

class _ImportacionAlumnasDialogState extends State<_ImportacionAlumnasDialog> {
  late String _instanciaId = widget.instancias.first.id;
  List<Map<String, Object?>>? _filas;
  ResultadoImportacion? _resultado;
  bool _procesando = false;
  String? _error;

  String _etiqueta(Curso c) => '${c.codigo} · ${c.sedeNombre}';

  Curso get _instancia => widget.instancias.firstWhere((c) => c.id == _instanciaId);

  Future<void> _elegirArchivo() async {
    final archivo = await elegirArchivo(const ['csv', 'xlsx']);
    if (archivo == null || !mounted) return;
    setState(() {
      _procesando = true;
      _error = null;
    });

    // Estructura del archivo: se rechaza completo si no respeta la plantilla
    final List<Map<String, Object?>> filas;
    try {
      filas = filasNominaAlumnas(leerPlanilla(archivo.bytes, archivo.nombre));
    } on PlanillaInvalida catch (e) {
      setState(() {
        _procesando = false;
        _filas = null;
        _resultado = ResultadoImportacion(nombreArchivo: archivo.nombre, errorColumnas: e.mensaje);
      });
      return;
    }

    final r = await widget.repository.previsualizarImportacion(
      instanciaId: _instanciaId,
      nombreArchivo: archivo.nombre,
      filas: filas,
    );
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _error = r.error;
      _filas = r.ok ? filas : null;
      _resultado = r.valor;
    });
  }

  Future<void> _confirmar() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    final r = await widget.repository.confirmarImportacion(
      instanciaId: _instanciaId,
      nombreArchivo: _resultado!.nombreArchivo,
      filas: _filas!,
    );
    if (!mounted) return;
    final valor = r.valor;
    if (valor == null) {
      setState(() {
        _procesando = false;
        _error = r.error;
      });
      return;
    }
    Navigator.pop(context, (
      inscritas: valor.inscritas,
      rechazadas: valor.detalle.contar(EstadoFilaImportacion.invalida),
    ));
  }

  void _reiniciar() => setState(() {
    _resultado = null;
    _filas = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;
    final validas = resultado == null || resultado.errorColumnas != null
        ? 0
        : resultado.filas.where((f) => f.estado != EstadoFilaImportacion.invalida).length;

    return AlertDialog(
      title: const Text('Carga masiva de nómina'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (resultado == null)
                _buildPasoSubida()
              else
                VistaPreviaImportacion(
                  resultado: resultado,
                  destino: _etiqueta(_instancia),
                  etiquetaDetalle: 'Apoderado/a',
                  onDescargarRechazadas: () => descargarArchivo(
                    'filas_rechazadas_${resultado.nombreArchivo.split('.').first}.csv',
                    reporteRechazadasCsv(resultado),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _procesando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        if (resultado != null)
          TextButton(onPressed: _procesando ? null : _reiniciar, child: const Text('Subir otra planilla')),
        if (resultado != null && resultado.errorColumnas == null)
          FilledButton.icon(
            onPressed: _procesando || validas == 0 ? null : _confirmar,
            icon: _procesando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
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
          initialValue: _instanciaId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Curso de destino', border: OutlineInputBorder()),
          items: [
            for (final c in widget.instancias) DropdownMenuItem(value: c.id, child: Text(_etiqueta(c))),
          ],
          onChanged: _procesando ? null : (v) => setState(() => _instanciaId = v ?? _instanciaId),
        ),
        const SizedBox(height: 16),
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
                    const Text('Sube tu planilla CSV (UTF-8) o XLSX', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Nada se guarda hasta que confirmes la carga.',
                      style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _elegirArchivo,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Elegir archivo'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Las columnas deben ser exactamente las de la plantilla, en el mismo orden. '
                'El correo y el teléfono del apoderado/a son obligatorios.',
                style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
              ),
            ),
            TextButton.icon(
              onPressed: () => descargarArchivo('plantilla_nomina_alumnas.csv', plantillaAlumnasCsv()),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar plantilla'),
            ),
          ],
        ),
      ],
    );
  }
}
