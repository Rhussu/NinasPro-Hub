import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/catalogo_repository.dart';
import '../../../utils/calendario.dart';
import '../../calendario/calendario_screen.dart';
import '../directorio_widgets.dart';

/// Instancias de curso (curso del catálogo + sede + período) y sus sesiones (US-02).
///
/// El asistente genera automáticamente las sesiones semanales 'programada' y
/// valida las fechas. Si la instancia ya existe pide confirmación y la crea
/// como sección paralela (A, B, …) con su propio cronograma.
class AjustesInstanciasView extends StatefulWidget {
  final CatalogoRepository repository;

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
    final (instancias, sedes, catalogo) = await (
      widget.repository.instancias(),
      widget.repository.sedes(),
      widget.repository.cursos(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _instancias = instancias;
      _sedes = sedes.where((s) => s.estado == 'activa').toList();
      _catalogo = catalogo;
      _cargando = false;
    });
  }

  Future<void> _nuevaInstancia() async {
    if (_sedes.isEmpty || _catalogo.isEmpty) {
      mostrarAviso(context, 'Primero registra al menos una sede activa y un curso del catálogo.', error: true);
      return;
    }
    final curso = await showDialog<Curso>(
      context: context,
      builder: (_) => _AsistenteInstancia(repository: widget.repository, sedes: _sedes, catalogo: _catalogo),
    );
    if (curso == null || !mounted) return;
    mostrarAviso(context, '✅ ${curso.codigo} creada con ${curso.totalSesiones} sesiones programadas.');
    _cargarDatos();
  }

  Future<void> _verSesiones(Curso curso) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalendarioScreen(repository: widget.repository, instanciaInicial: curso),
      ),
    );
    if (mounted) _cargarDatos();
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
            columnas: const ['Código', 'Curso', 'Sede', 'Período', 'Horario', 'Fechas', 'Sesiones'],
            mensajeVacio: 'Aún no hay instancias programadas.',
            filas: [
              for (final c in _instancias)
                DataRow(
                  onSelectChanged: (_) => _verSesiones(c),
                  cells: [
                    DataCell(Text(c.codigo, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(c.nombre)),
                    DataCell(Text(c.sedeNombre)),
                    DataCell(
                      Text('${c.anio} · ${c.semestre}° semestre${c.seccion > 1 ? ' · Sección ${c.seccionLetra}' : ''}'),
                    ),
                    DataCell(
                      Text(
                        '${nombresDiaSemana[c.diaSemana] ?? ''}'
                        '${c.horaInicio != null ? ' ${c.horaInicio}–${c.horaFin}' : ''}',
                      ),
                    ),
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

/// Asistente de creación de instancia: sede, curso, rango de fechas, día y horario (US-02)
class _AsistenteInstancia extends StatefulWidget {
  final CatalogoRepository repository;
  final List<Sede> sedes;
  final List<CursoCatalogo> catalogo;

  const _AsistenteInstancia({required this.repository, required this.sedes, required this.catalogo});

  @override
  State<_AsistenteInstancia> createState() => _AsistenteInstanciaState();
}

class _AsistenteInstanciaState extends State<_AsistenteInstancia> {
  late String _sedeId = widget.sedes.first.id;
  late String _catalogoId = widget.catalogo.first.id;
  late DateTime _inicio = _proximoInicio();
  late DateTime _termino = DateTime(_inicio.year, _inicio.month + 4, _inicio.day);
  int _diaSemana = DateTime.saturday;
  TimeOfDay _horaInicio = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 13, minute: 0);
  bool _guardando = false;
  String? _error;

  /// Inicio sugerido: el próximo semestre (marzo o agosto)
  static DateTime _proximoInicio() {
    final hoy = DateTime.now();
    if (hoy.month < 3) return DateTime(hoy.year, 3, 1);
    if (hoy.month < 8) return DateTime(hoy.year, 8, 1);
    return DateTime(hoy.year + 1, 3, 1);
  }

  bool get _fechasValidas => _termino.isAfter(_inicio);
  bool get _horarioValido => _minutos(_horaFin) > _minutos(_horaInicio);
  int get _sesionesPrevistas => _fechasValidas ? fechasSesiones(_inicio, _termino, _diaSemana).length : 0;

  static int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;
  static String _hora(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _crear({bool nuevaSeccion = false}) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final resultado = await widget.repository.crearInstancia(
      SolicitudInstancia(
        catalogoId: _catalogoId,
        sedeId: _sedeId,
        inicio: _inicio,
        termino: _termino,
        diaSemana: _diaSemana,
        horaInicio: _hora(_horaInicio),
        horaFin: _hora(_horaFin),
      ),
      nuevaSeccion: nuevaSeccion,
    );
    if (!mounted) return;
    if (resultado.ok) {
      Navigator.pop(context, resultado.valor);
      return;
    }
    setState(() => _guardando = false);
    if (resultado.duplicada) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Esta instancia ya existe'),
          content: Text(
            '${resultado.error}\n\n'
            '¿Quieres crear una sección paralela? Tendrá su propio cronograma de sesiones '
            'y no reemplaza a la existente.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear sección paralela')),
          ],
        ),
      );
      if (confirmar == true && mounted) await _crear(nuevaSeccion: true);
      return;
    }
    setState(() => _error = resultado.error);
  }

  Future<void> _elegirHora(bool inicio) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: inicio ? _horaInicio : _horaFin,
      helpText: inicio ? 'Hora de inicio' : 'Hora de término',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida == null) return;
    setState(() => inicio ? _horaInicio = elegida : _horaFin = elegida);
  }

  @override
  Widget build(BuildContext context) {
    final sesiones = _sesionesPrevistas;
    final valido = _fechasValidas && _horarioValido && sesiones > 0;

    return AlertDialog(
      title: const Text('Nueva instancia de curso'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
                    child: _CampoSelector(
                      etiqueta: 'Fecha de inicio',
                      valor: formatearFecha(_inicio),
                      icono: Icons.event_rounded,
                      onTap: () async {
                        final f = await elegirFecha(context, inicial: _inicio);
                        if (f != null) setState(() => _inicio = f);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoSelector(
                      etiqueta: 'Fecha de término',
                      valor: formatearFecha(_termino),
                      icono: Icons.event_rounded,
                      error: _fechasValidas ? null : 'Debe ser posterior al inicio',
                      onTap: () async {
                        final f = await elegirFecha(context, inicial: _termino);
                        if (f != null) setState(() => _termino = f);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _diaSemana,
                decoration: const InputDecoration(labelText: 'Día de clases', border: OutlineInputBorder()),
                items: [for (final e in nombresDiaSemana.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _diaSemana = v ?? _diaSemana),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CampoSelector(
                      etiqueta: 'Hora de inicio',
                      valor: _hora(_horaInicio),
                      icono: Icons.schedule_rounded,
                      onTap: () => _elegirHora(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoSelector(
                      etiqueta: 'Hora de término',
                      valor: _hora(_horaFin),
                      icono: Icons.schedule_rounded,
                      error: _horarioValido ? null : 'Debe ser posterior al inicio',
                      onTap: () => _elegirHora(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                !_fechasValidas
                    ? 'Corrige las fechas para ver las sesiones que se generarán.'
                    : sesiones == 0
                    ? 'No hay ningún ${nombresDiaSemana[_diaSemana]!.toLowerCase()} entre esas fechas.'
                    : 'Se generarán $sesiones sesiones con estado "programada", numeradas del 1 al $sesiones.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: valido ? NinasProColors.primary700 : NinasProColors.error700,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando || !valido ? null : _crear, child: const Text('Crear instancia')),
      ],
    );
  }
}

/// Campo de solo lectura que abre un selector (fecha u hora) al tocarlo
class _CampoSelector extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;
  final String? error;
  final VoidCallback onTap;

  const _CampoSelector({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.onTap,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          errorText: error,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icono),
        ),
        child: Text(valor),
      ),
    );
  }
}
