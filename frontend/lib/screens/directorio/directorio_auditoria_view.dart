import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import 'dart:convert';

import '../../repositories/reportes_repository.dart';
import '../../utils/rut_input_formatter.dart';
import 'directorio_widgets.dart';

/// Visor de la bitácora de auditoría para cumplimiento y derechos ARCO (US-24).
///
/// Filtros por rango de fechas, usuaria (nombre o correo), tipo de acción y RUT de alumna.
/// La base acota el alcance: Gestión ve solo lo ocurrido en su sede (E3).
class DirectorioAuditoriaView extends StatefulWidget {
  final ReportesRepository repository;

  const DirectorioAuditoriaView({super.key, required this.repository});

  @override
  State<DirectorioAuditoriaView> createState() => _DirectorioAuditoriaViewState();
}

class _DirectorioAuditoriaViewState extends State<DirectorioAuditoriaView> {
  bool _cargando = true;
  String? _error;
  List<EventoAuditoria> _eventos = [];

  final _usuaria = TextEditingController();
  final _rut = TextEditingController();
  TipoEventoAuditoria? _tipo;
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
    setState(() => _cargando = true);
    try {
      final eventos = await widget.repository.auditoria(
        desde: _desde,
        hasta: _hasta,
        usuaria: _usuaria.text,
        tipo: _tipo,
        rutAlumna: _rut.text,
      );
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _error = null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos consultar la auditoría. Revisa la conexión e inténtalo nuevamente.';
        _cargando = false;
      });
    }
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

  TonoChip _tonoTipo(TipoEventoAuditoria tipo) => switch (tipo) {
        TipoEventoAuditoria.modificacion => TonoChip.advertencia,
        TipoEventoAuditoria.exportacion => TonoChip.info,
        TipoEventoAuditoria.accesoDenegado => TonoChip.error,
        TipoEventoAuditoria.seguridad => TonoChip.neutro,
      };

  // Detalle del evento: valores anterior y nuevo, filtros de la descarga o parámetros del intento
  void _verDetalle(EventoAuditoria e) {
    const json = JsonEncoder.withIndent('  ');
    final detalle = Map.of(e.detalle);
    final anterior = detalle.remove('anterior');
    final nuevo = detalle.remove('nuevo');

    Widget bloque(String titulo, Object? valor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(json.convert(valor), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${e.tipo.etiqueta} · ${formatearFechaHora(e.fecha)}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.descripcion),
                const SizedBox(height: 8),
                Text('Usuaria: ${e.usuariaNombre}${e.usuariaCorreo == null ? '' : ' (${e.usuariaCorreo})'}'),
                if (e.alumnaNombre != null) Text('Alumna: ${e.alumnaNombre} · ${e.alumnaRut ?? ''}'),
                if (anterior != null) bloque('Valor anterior', anterior),
                if (nuevo != null) bloque('Valor nuevo', nuevo),
                if (detalle.isNotEmpty) bloque('Detalle', detalle),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar'))],
      ),
    );
  }

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
                      inputFormatters: const [RutInputFormatter()],
                      onSubmitted: (_) => _buscar(),
                      decoration: const InputDecoration(
                        labelText: 'RUT de alumna',
                        prefixIcon: Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  FiltroDesplegable<TipoEventoAuditoria>(
                    etiqueta: 'Tipo de acción',
                    valor: _tipo,
                    opciones: {for (final t in TipoEventoAuditoria.values) t: t.etiqueta},
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
              else if (_error != null)
                Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
              else ...[
                Text(
                  _eventos.length == 1 ? '1 evento' : '${_eventos.length} eventos',
                  style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                ),
                DirectorioTabla(
                  columnas: const ['Fecha', 'Usuaria', 'Sede', 'Acción', 'Detalle', 'Alumna'],
                  mensajeVacio: 'No hay eventos con estos filtros',
                  filas: [
                    for (final e in _eventos)
                      DataRow(onSelectChanged: (_) => _verDetalle(e), cells: [
                        DataCell(Text(formatearFechaHora(e.fecha))),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(e.usuariaNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (e.usuariaCorreo != null)
                              Text(e.usuariaCorreo!,
                                  style: const TextStyle(fontSize: 11.5, color: NinasProColors.neutral500)),
                          ],
                        )),
                        DataCell(Text(e.sedeNombre ?? '—')),
                        DataCell(DirectorioChip(e.tipo.etiqueta, tono: _tonoTipo(e.tipo))),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(e.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(e.alumnaRut == null ? '—' : '${e.alumnaNombre ?? ''}\n${e.alumnaRut}'.trim())),
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
