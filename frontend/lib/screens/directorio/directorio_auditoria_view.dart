import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import 'directorio_widgets.dart';

/// Visor de la bitácora de auditoría para cumplimiento y derechos ARCO (US-24).
///
/// Filtros por rango de fechas, usuaria (nombre o correo), tipo de acción y RUT de alumna.
class DirectorioAuditoriaView extends StatefulWidget {
  final HubRepository repository;

  const DirectorioAuditoriaView({super.key, required this.repository});

  @override
  State<DirectorioAuditoriaView> createState() => _DirectorioAuditoriaViewState();
}

class _DirectorioAuditoriaViewState extends State<DirectorioAuditoriaView> {
  bool _cargando = true;
  List<EventoAuditoria> _eventos = [];

  final _usuaria = TextEditingController();
  final _rut = TextEditingController();
  TipoAccionAuditoria? _tipo;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _usuaria.dispose();
    _rut.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final eventos = await widget.repository.getEventosAuditoria(
      desde: _desde,
      hasta: _hasta,
      usuaria: _usuaria.text,
      tipo: _tipo,
      rutAlumna: _rut.text.trim().isEmpty ? null : _rut.text,
    );
    if (!mounted) return;
    setState(() {
      _eventos = eventos;
      _cargando = false;
    });
  }

  void _limpiar() {
    _usuaria.clear();
    _rut.clear();
    setState(() {
      _tipo = null;
      _desde = null;
      _hasta = null;
    });
    _buscar();
  }

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: _desde != null && _hasta != null ? DateTimeRange(start: _desde!, end: _hasta!) : null,
      helpText: 'Rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      saveText: 'Aceptar',
    );
    if (rango == null) return;
    setState(() {
      _desde = rango.start;
      _hasta = rango.end;
    });
    _buscar();
  }

  TonoChip _tonoTipo(TipoAccionAuditoria tipo) => switch (tipo) {
        TipoAccionAuditoria.consulta => TonoChip.info,
        TipoAccionAuditoria.modificacion => TonoChip.advertencia,
        TipoAccionAuditoria.exportacion => TonoChip.neutro,
        TipoAccionAuditoria.acceso => TonoChip.exito,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const DirectorioEncabezado(
          titulo: 'Auditoría',
          subtitulo: 'Registro inmutable de accesos, consultas, modificaciones y descargas.',
        ),
        DirectorioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _usuaria,
                      onSubmitted: (_) => _buscar(),
                      decoration: const InputDecoration(
                        labelText: 'Usuaria (nombre o correo)',
                        prefixIcon: Icon(Icons.person_search_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _rut,
                      onSubmitted: (_) => _buscar(),
                      decoration: const InputDecoration(
                        labelText: 'RUT de alumna',
                        prefixIcon: Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  FiltroDesplegable<TipoAccionAuditoria>(
                    etiqueta: 'Tipo de acción',
                    valor: _tipo,
                    opciones: {for (final t in TipoAccionAuditoria.values) t: t.label},
                    onChanged: (v) {
                      setState(() => _tipo = v);
                      _buscar();
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: _elegirRango,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(_desde == null
                        ? 'Rango de fechas'
                        : '${formatearFecha(_desde)} – ${formatearFecha(_hasta)}'),
                  ),
                  FilledButton.icon(
                    onPressed: _buscar,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Buscar'),
                  ),
                  TextButton(onPressed: _limpiar, child: const Text('Limpiar filtros')),
                ],
              ),
              const SizedBox(height: 12),
              if (_cargando)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else ...[
                Text(
                  '${_eventos.length} eventos',
                  style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                ),
                DirectorioTabla(
                  columnas: const ['Fecha', 'Usuaria', 'Sede', 'Acción', 'Detalle', 'RUT alumna'],
                  filas: [
                    for (final e in _eventos)
                      DataRow(cells: [
                        DataCell(Text(formatearFechaHora(e.fecha))),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(e.usuariaNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(e.usuariaCorreo,
                                style: const TextStyle(fontSize: 11.5, color: NinasProColors.neutral500)),
                          ],
                        )),
                        DataCell(Text(e.sedeNombre)),
                        DataCell(DirectorioChip(e.tipo.label, tono: _tonoTipo(e.tipo))),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(e.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(e.alumnaRut ?? '—')),
                      ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
