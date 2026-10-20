import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/hub_repository.dart';
import '../directorio_widgets.dart';

/// Instancias de curso (curso del catálogo + sede + período) y sus sesiones (US-02).
///
/// El asistente genera automáticamente las sesiones semanales 'programada',
/// valida las fechas y pide confirmación si la instancia ya existe.
class AjustesInstanciasView extends StatefulWidget {
  final HubRepository repository;

  const AjustesInstanciasView({super.key, required this.repository});

  @override
  State<AjustesInstanciasView> createState() => _AjustesInstanciasViewState();
}

class _AjustesInstanciasViewState extends State<AjustesInstanciasView> {
  bool _cargando = true;
  List<Curso> _instancias = [];
  List<Sede> _sedes = [];
  List<CursoCatalogo> _catalogo = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final instancias = await widget.repository.getCursos();
    final sedes = await widget.repository.getSedes();
    final catalogo = await widget.repository.getCatalogoCursos();
    if (!mounted) return;
    setState(() {
      _instancias = instancias;
      _sedes = sedes.where((s) => s.estado == 'activa').toList();
      _catalogo = catalogo;
      _cargando = false;
    });
  }

  Future<void> _nuevaInstancia() async {
    final curso = await showDialog<Curso>(
      context: context,
      builder: (_) => _AsistenteInstancia(repository: widget.repository, sedes: _sedes, catalogo: _catalogo),
    );
    if (curso == null || !mounted) return;
    mostrarAviso(context, '✅ ${curso.codigo} creada con ${curso.totalSesiones} sesiones programadas.');
    _cargarDatos();
  }

  Future<void> _verSesiones(Curso curso) async {
    final sesiones = await widget.repository.getSesiones(cursoId: curso.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${curso.codigo} · ${sesiones.length} sesiones'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: DirectorioTabla(
              columnas: const ['N°', 'Fecha', 'Tema', 'Estado'],
              filas: [
                for (final s in sesiones)
                  DataRow(cells: [
                    DataCell(Text('${s.numeroSesion}')),
                    DataCell(Text(formatearFecha(s.fecha))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(s.tema, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(DirectorioChip(
                      etiquetaEstado(s.estado),
                      tono: s.estado == 'realizada' ? TonoChip.exito : TonoChip.info,
                    )),
                  ]),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Instancias y sesiones',
          subtitulo: 'Un curso del catálogo dictado en una sede y período, con su calendario de clases',
          acciones: [
            FilledButton.icon(
              onPressed: _nuevaInstancia,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva instancia'),
            ),
          ],
        ),
        DirectorioPanel(
          child: DirectorioTabla(
            columnas: const ['Código', 'Curso', 'Sede', 'Período', 'Día', 'Fechas', 'Sesiones'],
            filas: [
              for (final c in _instancias)
                DataRow(
                  onSelectChanged: (_) => _verSesiones(c),
                  cells: [
                    DataCell(Text(c.codigo, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(c.nombre)),
                    DataCell(Text(c.sedeNombre)),
                    DataCell(Text('${c.anio} · ${c.semestre}° semestre')),
                    DataCell(Text(nombresDiaSemana[c.diaSemana] ?? '')),
                    DataCell(Text('${formatearFecha(c.fechaInicio)} – ${formatearFecha(c.fechaTermino)}')),
                    DataCell(Text('${c.totalSesiones}')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asistente de creación de instancia: sede, curso, rango de fechas y día de clases (US-02)
class _AsistenteInstancia extends StatefulWidget {
  final HubRepository repository;
  final List<Sede> sedes;
  final List<CursoCatalogo> catalogo;

  const _AsistenteInstancia({required this.repository, required this.sedes, required this.catalogo});

  @override
  State<_AsistenteInstancia> createState() => _AsistenteInstanciaState();
}

class _AsistenteInstanciaState extends State<_AsistenteInstancia> {
  late String _sedeId = widget.sedes.first.id;
  late String _catalogoId = widget.catalogo.first.id;
  DateTime _inicio = DateTime(2026, 8, 1);
  DateTime _termino = DateTime(2026, 11, 28);
  int _diaSemana = DateTime.saturday;
  bool _guardando = false;

  bool get _fechasValidas => _termino.isAfter(_inicio);

  /// Cuántas clases caen en el rango para el día elegido
  int get _sesionesPrevistas {
    if (!_fechasValidas) return 0;
    var dia = _inicio;
    while (dia.weekday != _diaSemana) {
      dia = DateTime(dia.year, dia.month, dia.day + 1);
    }
    var total = 0;
    while (!dia.isAfter(_termino)) {
      total++;
      dia = DateTime(dia.year, dia.month, dia.day + 7);
    }
    return total;
  }

  Future<void> _crear() async {
    final semestre = _inicio.month >= 7 ? 2 : 1;
    final duplicada = await widget.repository.existeInstancia(
      catalogoId: _catalogoId,
      sedeId: _sedeId,
      anio: _inicio.year,
      semestre: semestre,
    );
    if (!mounted) return;
    if (duplicada) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Esta instancia ya existe'),
          content: Text(
            'Ya hay una instancia de este curso en esta sede para el $semestre° semestre de ${_inicio.year}. '
            '¿Quieres crear otra igualmente? Se duplicará el cronograma.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear de todas formas')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _guardando = true);
    final curso = await widget.repository.crearInstanciaCurso(
      catalogoId: _catalogoId,
      sedeId: _sedeId,
      inicio: _inicio,
      termino: _termino,
      diaSemana: _diaSemana,
    );
    if (!mounted) return;
    Navigator.pop(context, curso);
  }

  @override
  Widget build(BuildContext context) {
    final sesiones = _sesionesPrevistas;

    return AlertDialog(
      title: const Text('Nueva instancia de curso'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _sedeId,
              decoration: const InputDecoration(labelText: 'Sede', border: OutlineInputBorder()),
              items: [for (final s in widget.sedes) DropdownMenuItem(value: s.id, child: Text(s.nombre))],
              onChanged: (v) => setState(() => _sedeId = v ?? _sedeId),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _catalogoId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Curso del catálogo', border: OutlineInputBorder()),
              items: [
                for (final c in widget.catalogo)
                  DropdownMenuItem(value: c.id, child: Text('${c.codigo} · ${c.nombre}')),
              ],
              onChanged: (v) => setState(() => _catalogoId = v ?? _catalogoId),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CampoFecha(
                    etiqueta: 'Fecha de inicio',
                    fecha: _inicio,
                    onChanged: (f) => setState(() => _inicio = f),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoFecha(
                    etiqueta: 'Fecha de término',
                    fecha: _termino,
                    error: _fechasValidas ? null : 'Debe ser posterior al inicio',
                    onChanged: (f) => setState(() => _termino = f),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _diaSemana,
              decoration: const InputDecoration(labelText: 'Día de clases', border: OutlineInputBorder()),
              items: [
                for (final e in nombresDiaSemana.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _diaSemana = v ?? _diaSemana),
            ),
            const SizedBox(height: 16),
            Text(
              _fechasValidas
                  ? 'Se generarán $sesiones sesiones con estado "programada", numeradas del 1 al $sesiones.'
                  : 'Corrige las fechas para ver las sesiones que se generarán.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _fechasValidas ? NinasProColors.primary700 : NinasProColors.error700,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando || !_fechasValidas || sesiones == 0 ? null : _crear,
          child: const Text('Crear instancia'),
        ),
      ],
    );
  }
}

class _CampoFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime fecha;
  final String? error;
  final ValueChanged<DateTime> onChanged;

  const _CampoFecha({required this.etiqueta, required this.fecha, required this.onChanged, this.error});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final elegida = await elegirFecha(context, inicial: fecha);
        if (elegida != null) onChanged(elegida);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          errorText: error,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.event_rounded),
        ),
        child: Text(formatearFecha(fecha)),
      ),
    );
  }
}
