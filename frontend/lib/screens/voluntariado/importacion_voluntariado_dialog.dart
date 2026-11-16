import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/voluntariado_repository.dart';
import '../../services/descargas.dart';
import '../../services/selector_archivos.dart';
import '../../utils/planilla.dart';
import '../directorio/directorio_widgets.dart';

/// Carga masiva del voluntariado desde un CSV (UTF-8) o XLSX (US-30 escenario 1).
///
/// 1. Se elige la sede de destino y el archivo. Si las columnas no son las de la
///    plantilla, el archivo se rechaza completo.
/// 2. La base revisa cada fila sin guardar nada: RUT, correo institucional,
///    rol y duplicados. Un RUT que ya tiene ficha la conserva y suma la sede.
/// 3. "Cargar" crea las fichas válidas y autoriza sus correos; las filas
///    rechazadas se pueden descargar con su motivo.
///
/// Devuelve la revisión final, o null si se canceló.
Future<RevisionVoluntariado?> mostrarImportacionVoluntariado(
  BuildContext context, {
  required VoluntariadoRepository repository,
  required List<Sede> sedes,
}) => showDialog(
  context: context,
  builder: (_) => _ImportacionVoluntariadoDialog(repository: repository, sedes: sedes),
);

/// Descarga las filas rechazadas con su número de fila y motivo
void descargarRechazadasVoluntariado(RevisionVoluntariado revision, String archivo) {
  descargarArchivo(
    'rechazadas_${archivo.split('.').first}.csv',
    reporteFilasCsv([
      for (final f in revision.rechazadasFilas) (fila: f.fila, rut: f.rut, nombre: f.nombre, motivo: f.motivo ?? ''),
    ]),
  );
}

class _ImportacionVoluntariadoDialog extends StatefulWidget {
  final VoluntariadoRepository repository;
  final List<Sede> sedes;

  const _ImportacionVoluntariadoDialog({required this.repository, required this.sedes});

  @override
  State<_ImportacionVoluntariadoDialog> createState() => _ImportacionVoluntariadoDialogState();
}

class _ImportacionVoluntariadoDialogState extends State<_ImportacionVoluntariadoDialog> {
  late String _sedeId = widget.sedes.first.id;
  String? _archivo;
  List<Map<String, Object?>>? _datos;
  RevisionVoluntariado? _revision;
  String? _errorEstructura;
  bool _procesando = false;
  String? _error;

  String get _sedeNombre => widget.sedes.firstWhere((s) => s.id == _sedeId).nombre;

  Future<void> _elegirArchivo() async {
    final archivo = await elegirArchivo(const ['csv', 'xlsx']);
    if (archivo == null || !mounted) return;
    try {
      _datos = filasVoluntariado(leerPlanilla(archivo.bytes, archivo.nombre));
    } on PlanillaInvalida catch (e) {
      setState(() {
        _archivo = archivo.nombre;
        _errorEstructura = e.mensaje;
      });
      return;
    }
    _archivo = archivo.nombre;
    setState(() {
      _procesando = true;
      _error = null;
    });
    final r = await widget.repository.revisarImportacion(sedeId: _sedeId, filas: _datos!);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _error = r.error;
      _revision = r.valor;
    });
  }

  Future<void> _confirmar() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    final r = await widget.repository.confirmarImportacion(sedeId: _sedeId, filas: _datos!);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _procesando = false;
        _error = r.error;
      });
      return;
    }
    Navigator.pop(context, r.valor);
  }

  void _reiniciar() => setState(() {
    _archivo = null;
    _datos = null;
    _revision = null;
    _errorEstructura = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final cargables = revision == null ? 0 : revision.creadas + revision.actualizadas;

    return AlertDialog(
      title: const Text('Carga masiva de voluntariado'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorEstructura != null)
                _RechazoCompleto(archivo: _archivo!, mensaje: _errorEstructura!)
              else if (revision != null)
                _buildRevision(revision)
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
        if (revision != null || _errorEstructura != null)
          TextButton(onPressed: _procesando ? null : _reiniciar, child: const Text('Subir otra planilla')),
        if (revision != null)
          FilledButton.icon(
            onPressed: _procesando || cargables == 0 ? null : _confirmar,
            icon: _procesando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              revision.rechazadas == 0
                  ? 'Cargar $cargables ${cargables == 1 ? 'ficha' : 'fichas'}'
                  : 'Cargar $cargables y rechazar ${revision.rechazadas}',
            ),
          ),
      ],
    );
  }

  Widget _buildRevision(RevisionVoluntariado revision) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_archivo · ${revision.filas.length} filas · destino: $_sedeNombre',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DirectorioChip('${revision.creadas} nuevas', tono: TonoChip.exito),
            DirectorioChip('${revision.actualizadas} ya tenían ficha', tono: TonoChip.info),
            DirectorioChip(
              '${revision.rechazadas} rechazadas',
              tono: revision.rechazadas == 0 ? TonoChip.neutro : TonoChip.error,
            ),
          ],
        ),
        if (revision.rechazadas > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Las filas rechazadas no se cargan. Corrígelas en la planilla y súbelas en otra carga; '
            'puedes descargar el detalle con el motivo de cada una.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).brightness == Brightness.dark
                  ? NinasProColors.neutral300
                  : NinasProColors.neutral700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_procesando) const LinearProgressIndicator(),
        DirectorioTabla(
          columnas: const ['Fila', 'RUT', 'Nombre', 'Correo', 'Estado', 'Detalle'],
          filas: [
            for (final f in revision.filas)
              DataRow(
                cells: [
                  DataCell(Text('${f.fila}')),
                  DataCell(Text(f.rut)),
                  DataCell(Text(f.nombre)),
                  DataCell(Text(f.correo)),
                  DataCell(_chipEstado(f)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(f.motivo ?? '', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (revision.rechazadas > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => descargarRechazadasVoluntariado(revision, _archivo!),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar filas rechazadas'),
            ),
          ),
      ],
    );
  }

  Widget _chipEstado(FilaVoluntariado f) => switch (f.estado) {
    'nueva' => const DirectorioChip('Nueva', tono: TonoChip.exito),
    'existente' => const DirectorioChip('Ya tiene ficha', tono: TonoChip.info),
    _ => const DirectorioChip('Rechazada', tono: TonoChip.error),
  };

  Widget _buildPasoSubida() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _sedeId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sede de destino', border: OutlineInputBorder()),
          items: [for (final s in widget.sedes) DropdownMenuItem(value: s.id, child: Text(s.nombre))],
          onChanged: _procesando ? null : (v) => setState(() => _sedeId = v ?? _sedeId),
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
                'Las columnas deben ser exactamente las de la plantilla, en el mismo orden. El correo es el '
                'institucional @ninaspro.cl y el rol, Tutora o Equipo de Gestión. Al cargar se autoriza su '
                'correo para que cree su cuenta.',
                style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
              ),
            ),
            TextButton.icon(
              onPressed: () => descargarArchivo('plantilla_voluntariado.csv', plantillaVoluntariadoCsv()),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar plantilla'),
            ),
          ],
        ),
      ],
    );
  }
}

/// La planilla no respeta la plantilla: se rechaza completa
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
          Expanded(
            child: Text('$archivo fue rechazada completa.\n$mensaje', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
