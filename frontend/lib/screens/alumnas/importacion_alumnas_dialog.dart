import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../services/descargas.dart';
import '../../services/selector_archivos.dart';
import '../../utils/planilla.dart';
import 'filas_nomina.dart';

/// Carga masiva de la nómina desde un CSV (UTF-8) o XLSX (US-07, US-08).
///
/// 1. Se elige la instancia de destino y el archivo. Si las columnas no son las
///    de la plantilla, el archivo se rechaza completo.
/// 2. La base revisa cada fila sin guardar nada y avisa los conflictos (RUT
///    repetido, ficha existente con otros datos, correo en uso) y los errores.
///    Cada uno se resuelve aquí mismo con el menú de la fila.
/// 3. "Confirmar carga" inscribe lo resuelto en una transacción; lo que siga sin
///    resolver queda en "Conflictos de importación" para resolverlo después.
///
/// Devuelve cuántas se inscribieron y cuántas quedaron pendientes, o null si se canceló.
Future<({int inscritas, int pendientes})?> mostrarImportacionAlumnas(
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
  String? _archivo;
  List<FilaNomina>? _filas;
  String? _errorEstructura;
  bool _procesando = false;
  String? _error;

  String _etiqueta(Curso c) => '${c.codigo} · ${c.sedeNombre}';

  Curso get _instancia => widget.instancias.firstWhere((c) => c.id == _instanciaId);

  Future<void> _elegirArchivo() async {
    final archivo = await elegirArchivo(const ['csv', 'xlsx']);
    if (archivo == null || !mounted) return;
    final List<Map<String, Object?>> datos;
    try {
      datos = filasNominaAlumnas(leerPlanilla(archivo.bytes, archivo.nombre));
    } on PlanillaInvalida catch (e) {
      setState(() {
        _archivo = archivo.nombre;
        _errorEstructura = e.mensaje;
      });
      return;
    }
    _archivo = archivo.nombre;
    await _revisar([for (final d in datos) FilaNomina(numero: d['fila'] as int, datos: d)]);
  }

  /// Vuelve a revisar todas las filas con las correcciones y resoluciones elegidas
  Future<void> _revisar(List<FilaNomina> filas) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    final r = await widget.repository.revisarImportacion(instanciaId: _instanciaId, archivo: _archivo!, filas: filas);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _error = r.error;
      if (r.ok) _filas = r.valor!.filas;
    });
  }

  Future<void> _accion(int indice, AccionFila accion) async {
    final filas = [..._filas!];
    switch (accion) {
      case AccionFila.corregir:
        final datos = await editarFilaNomina(context, filas[indice]);
        if (datos == null) return;
        filas[indice] = filas[indice].conDatos(datos);
      case AccionFila.usarEstaFila:
        for (final j in indicesRepetidos(filas, indice)) {
          filas[j] = filas[j].conResolucion(ResolucionFila.descartar);
        }
      case AccionFila.deshacer:
        filas[indice] = filas[indice].conResolucion(null);
      default:
        filas[indice] = filas[indice].conResolucion(resolucionDe(accion));
    }
    await _revisar(filas);
  }

  Future<void> _confirmar() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    final r = await widget.repository.confirmarImportacion(instanciaId: _instanciaId, archivo: _archivo!, filas: _filas!);
    if (!mounted) return;
    final valor = r.valor;
    if (valor == null) {
      setState(() {
        _procesando = false;
        _error = r.error;
      });
      return;
    }
    Navigator.pop(context, (inscritas: valor.inscritas, pendientes: valor.pendientes));
  }

  void _reiniciar() => setState(() {
    _archivo = null;
    _filas = null;
    _errorEstructura = null;
    _error = null;
  });

  void _descargarPorResolver() {
    final filas = _filas!.where((f) => f.estado.porResolver);
    descargarArchivo(
      'por_resolver_${_archivo!.split('.').first}.csv',
      reporteFilasCsv([for (final f in filas) (fila: f.numero, rut: f.rut, nombre: f.nombre, motivo: f.motivo ?? '')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filas;
    final revisado = filas != null || _errorEstructura != null;
    final inscribir = filas?.where((f) => f.estado.seInscribe).length ?? 0;
    final pendientes = filas?.where((f) => f.estado.porResolver).length ?? 0;

    return AlertDialog(
      title: const Text('Carga masiva de nómina'),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorEstructura != null)
                _RechazoCompleto(archivo: _archivo!, mensaje: _errorEstructura!)
              else if (filas != null)
                _buildRevision(filas, pendientes)
              else
                _buildPasoSubida(),
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
        if (revisado)
          TextButton(onPressed: _procesando ? null : _reiniciar, child: const Text('Subir otra planilla')),
        if (filas != null)
          FilledButton.icon(
            onPressed: _procesando || inscribir + pendientes == 0 ? null : _confirmar,
            icon: _procesando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              pendientes == 0
                  ? 'Confirmar carga ($inscribir)'
                  : 'Confirmar: $inscribir ${inscribir == 1 ? 'inscripción' : 'inscripciones'} · $pendientes pendientes',
            ),
          ),
      ],
    );
  }

  Widget _buildRevision(List<FilaNomina> filas, int pendientes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_archivo · ${filas.length} filas · destino: ${_etiqueta(_instancia)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ResumenFilasNomina(filas: filas),
        if (pendientes > 0) ...[
          const SizedBox(height: 10),
          _Aviso(
            '$pendientes ${pendientes == 1 ? 'fila tiene' : 'filas tienen'} conflictos o errores. Resuélvelas aquí con '
            'el menú ⋯ de cada fila, o confirma la carga y quedarán pendientes en "Conflictos de importación" '
            'para resolverlas después.',
          ),
        ],
        const SizedBox(height: 12),
        if (_procesando) const LinearProgressIndicator(),
        TablaFilasNomina(filas: filas, onAccion: _procesando ? null : _accion),
        if (pendientes > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _descargarPorResolver,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar filas por resolver'),
            ),
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

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso(this.texto);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.warning900 : NinasProColors.warning100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: NinasProColors.warning700),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

/// La planilla no respeta la plantilla: se rechaza completa (US-08 escenario 1)
class _RechazoCompleto extends StatelessWidget {
  final String archivo;
  final String mensaje;

  const _RechazoCompleto({required this.archivo, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? NinasProColors.error300 : NinasProColors.error900;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.error900 : NinasProColors.error100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text('$archivo fue rechazada completa.\n$mensaje', style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
