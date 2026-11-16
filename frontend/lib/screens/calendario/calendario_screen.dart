import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/catalogo_repository.dart';
import '../../utils/calendario.dart';
import '../directorio/directorio_widgets.dart';

/// Calendario de clases de un curso (US-03).
///
/// Gestión lo abre desde sus Ajustes y ve solo los cursos vigentes de su sede
/// (la RLS acota las filas). La Directiva lo abre desde "Instancias y
/// sesiones" con [instanciaInicial]. Permite suspender una sesión programada
/// (feriado o contingencia), reanudarla y agregar sesiones especiales.
/// La tutora lo abre desde sus Ajustes con [soloLectura]: ve el cronograma de
/// su curso sin poder cambiarlo.
class CalendarioScreen extends StatefulWidget {
  final CatalogoRepository repository;
  final Curso? instanciaInicial;

  /// Fecha de referencia para decidir qué cursos están vigentes (para pruebas)
  final DateTime? hoy;

  /// Sin suspender, reanudar ni agregar sesiones (la tutora)
  final bool soloLectura;

  const CalendarioScreen({
    super.key,
    required this.repository,
    this.instanciaInicial,
    this.hoy,
    this.soloLectura = false,
  });

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  bool _cargando = true;
  List<Curso> _instancias = [];
  Curso? _instancia;
  List<SesionClase> _sesiones = [];
  bool _cargandoSesiones = false;

  DateTime get _hoy {
    final h = widget.hoy ?? DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  @override
  void initState() {
    super.initState();
    _cargarInstancias();
  }

  /// Vigente: del período académico actual o que aún no termina
  bool _vigente(Curso c) =>
      '${c.anio}-${c.semestre}' == periodoAcademico(_hoy) ||
      (c.fechaTermino != null && !c.fechaTermino!.isBefore(_hoy));

  Future<void> _cargarInstancias() async {
    final inicial = widget.instanciaInicial;
    final instancias = inicial != null ? [inicial] : (await widget.repository.instancias()).where(_vigente).toList();
    if (!mounted) return;
    setState(() {
      _instancias = instancias;
      _instancia = instancias.firstOrNull;
      _cargando = false;
    });
    await _cargarSesiones();
  }

  Future<void> _cargarSesiones() async {
    final instancia = _instancia;
    if (instancia == null) return;
    setState(() => _cargandoSesiones = true);
    final sesiones = await widget.repository.sesiones(instancia.id);
    if (!mounted) return;
    setState(() {
      _sesiones = sesiones;
      _cargandoSesiones = false;
    });
  }

  Future<void> _suspender(SesionClase sesion) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoSuspension(sesion: sesion),
    );
    if (motivo == null || !mounted) return;
    final resultado = await widget.repository.suspenderSesion(sesion.id, motivo);
    if (!mounted) return;
    if (resultado.ok) {
      mostrarAviso(context, 'Sesión ${sesion.numeroSesion} suspendida. No se tomará asistencia ese día.');
      _cargarSesiones();
    } else {
      mostrarAviso(context, resultado.error!, error: true);
    }
  }

  Future<void> _reanudar(SesionClase sesion) async {
    final resultado = await widget.repository.reanudarSesion(sesion.id);
    if (!mounted) return;
    if (resultado.ok) {
      mostrarAviso(context, 'Sesión ${sesion.numeroSesion} vuelve a estar programada.');
      _cargarSesiones();
    } else {
      mostrarAviso(context, resultado.error!, error: true);
    }
  }

  Future<void> _agregarEspecial() async {
    final instancia = _instancia;
    if (instancia == null) return;
    final agregada = await showDialog<SesionClase>(
      context: context,
      builder: (_) => _DialogoSesionEspecial(repository: widget.repository, instancia: instancia, hoy: _hoy),
    );
    if (agregada == null || !mounted) return;
    mostrarAviso(context, '✅ Sesión especial del ${formatearFecha(agregada.fecha)} programada.');
    _cargarSesiones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.soloLectura ? 'Cronograma' : 'Calendario de clases')),
      floatingActionButton: _instancia == null || widget.soloLectura
          ? null
          : FloatingActionButton.extended(
              onPressed: _agregarEspecial,
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Sesión especial'),
            ),
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _buildContenido()),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final instancia = _instancia;
    if (instancia == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tu sede no tiene cursos vigentes en este período.', textAlign: TextAlign.center),
        ),
      );
    }

    final suspendidas = _sesiones.where((s) => s.suspendida).length;
    final realizadas = _sesiones.where((s) => s.estado == 'realizada').length;

    return RefreshIndicator(
      onRefresh: _cargarSesiones,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_instancias.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: instancia.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder()),
              items: [
                for (final c in _instancias)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.codigo} · ${c.nombre}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                setState(() => _instancia = _instancias.firstWhere((c) => c.id == id));
                _cargarSesiones();
              },
            ),
            const SizedBox(height: 14),
          ],
          DirectorioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instancia.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${instancia.sedeNombre} · ${instancia.anio} ${instancia.semestre}° semestre'
                  '${instancia.seccion > 1 ? ' · Sección ${instancia.seccionLetra}' : ''}',
                ),
                if (instancia.horaInicio != null)
                  Text('${nombresDiaSemana[instancia.diaSemana]} de ${instancia.horaInicio} a ${instancia.horaFin}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    DirectorioChip('${_sesiones.length} sesiones', tono: TonoChip.info),
                    DirectorioChip('$realizadas realizadas', tono: TonoChip.exito),
                    if (suspendidas > 0) DirectorioChip('$suspendidas suspendidas', tono: TonoChip.advertencia),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_cargandoSesiones)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final s in _sesiones)
              _TarjetaSesion(
                sesion: s,
                esHoy: s.fecha == _hoy,
                onSuspender: s.estado == 'programada' && !widget.soloLectura ? () => _suspender(s) : null,
                onReanudar: s.suspendida && !widget.soloLectura ? () => _reanudar(s) : null,
              ),
        ],
      ),
    );
  }
}

class _TarjetaSesion extends StatelessWidget {
  final SesionClase sesion;
  final bool esHoy;
  final VoidCallback? onSuspender;
  final VoidCallback? onReanudar;

  const _TarjetaSesion({required this.sesion, required this.esHoy, this.onSuspender, this.onReanudar});

  @override
  Widget build(BuildContext context) {
    final s = sesion;
    final horario = s.horaInicio == null ? '' : ' · ${s.horaInicio}–${s.horaFin}';
    final detalle = s.suspendida ? 'Motivo: ${s.motivoSuspension ?? 'sin motivo'}' : (s.tema.isEmpty ? null : s.tema);

    return Opacity(
      opacity: s.suspendida ? 0.7 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: s.suspendida ? NinasProColors.neutral300 : NinasProColors.primary100,
            foregroundColor: NinasProColors.primary900,
            child: Text('${s.numeroSesion}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          title: Text(
            '${nombresDiaSemana[s.fecha.weekday]} ${formatearFecha(s.fecha)}$horario',
            style: TextStyle(fontWeight: FontWeight.w700, decoration: s.suspendida ? TextDecoration.lineThrough : null),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DirectorioChip(etiquetaEstado(s.estado), tono: _tono(s.estado)),
                if (s.esEspecial) const DirectorioChip('Especial', tono: TonoChip.info, icono: Icons.star_rounded),
                if (esHoy) const DirectorioChip('Hoy', icono: Icons.today_rounded),
                if (detalle != null) Text(detalle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          trailing: onSuspender == null && onReanudar == null
              ? null
              : PopupMenuButton<VoidCallback>(
                  tooltip: 'Acciones de la sesión ${s.numeroSesion}',
                  onSelected: (accion) => accion(),
                  itemBuilder: (_) => [
                    if (onSuspender != null)
                      PopupMenuItem(
                        value: onSuspender,
                        child: const ListTile(
                          leading: Icon(Icons.event_busy_rounded),
                          title: Text('Suspender'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onReanudar != null)
                      PopupMenuItem(
                        value: onReanudar,
                        child: const ListTile(
                          leading: Icon(Icons.event_repeat_rounded),
                          title: Text('Reanudar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  static TonoChip _tono(String estado) => switch (estado) {
    'realizada' => TonoChip.exito,
    'suspendida' => TonoChip.advertencia,
    _ => TonoChip.info,
  };
}

/// Pide el motivo de la suspensión; devuelve el motivo o null si se cancela
class _DialogoSuspension extends StatefulWidget {
  final SesionClase sesion;

  const _DialogoSuspension({required this.sesion});

  @override
  State<_DialogoSuspension> createState() => _DialogoSuspensionState();
}

class _DialogoSuspensionState extends State<_DialogoSuspension> {
  final _formKey = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sesion;
    return AlertDialog(
      title: Text('Suspender la sesión ${s.numeroSesion}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La clase del ${formatearFecha(s.fecha)} saldrá del pase de lista y no contará '
                'en el porcentaje de asistencia.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final sugerencia in const ['Feriado', 'Contingencia local', 'Sede no disponible'])
                    ActionChip(label: Text(sugerencia), onPressed: () => _motivo.text = sugerencia),
                ],
              ),
              const SizedBox(height: 10),
              CampoFormulario(controller: _motivo, etiqueta: 'Motivo', validator: obligatorio),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.pop(context, _motivo.text.trim());
          },
          child: const Text('Suspender'),
        ),
      ],
    );
  }
}

/// Agrega una sesión especial o de recuperación con fecha y horario propios
class _DialogoSesionEspecial extends StatefulWidget {
  final CatalogoRepository repository;
  final Curso instancia;
  final DateTime hoy;

  const _DialogoSesionEspecial({required this.repository, required this.instancia, required this.hoy});

  @override
  State<_DialogoSesionEspecial> createState() => _DialogoSesionEspecialState();
}

class _DialogoSesionEspecialState extends State<_DialogoSesionEspecial> {
  late DateTime _fecha = widget.hoy.isBefore(widget.instancia.fechaInicio ?? widget.hoy)
      ? widget.instancia.fechaInicio!
      : widget.hoy;
  late TimeOfDay _inicio = _parsear(widget.instancia.horaInicio, 10);
  late TimeOfDay _fin = _parsear(widget.instancia.horaFin, 13);
  bool _guardando = false;
  String? _error;

  static TimeOfDay _parsear(String? hora, int respaldo) {
    final partes = hora?.split(':');
    if (partes == null || partes.length < 2) return TimeOfDay(hour: respaldo, minute: 0);
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  static String _texto(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _horarioValido => _fin.hour * 60 + _fin.minute > _inicio.hour * 60 + _inicio.minute;

  Future<void> _elegirHora(bool inicio) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: inicio ? _inicio : _fin,
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida != null) setState(() => inicio ? _inicio = elegida : _fin = elegida);
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final resultado = await widget.repository.agregarSesionEspecial(
      instanciaId: widget.instancia.id,
      fecha: _fecha,
      horaInicio: _texto(_inicio),
      horaFin: _texto(_fin),
    );
    if (!mounted) return;
    if (resultado.ok) {
      Navigator.pop(context, resultado.valor);
    } else {
      setState(() {
        _guardando = false;
        _error = resultado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar sesión especial'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Para recuperar una clase suspendida o sumar una sesión extraordinaria. '
              'Las tutoras del curso la verán de inmediato.',
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('Fecha'),
              subtitle: Text('${nombresDiaSemana[_fecha.weekday]} ${formatearFecha(_fecha)}'),
              onTap: () async {
                final f = await elegirFecha(context, inicial: _fecha, primera: widget.instancia.fechaInicio);
                if (f != null) setState(() => _fecha = f);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Inicio'),
                    subtitle: Text(_texto(_inicio)),
                    onTap: () => _elegirHora(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Término'),
                    subtitle: Text(_texto(_fin)),
                    onTap: () => _elegirHora(false),
                  ),
                ),
              ],
            ),
            if (!_horarioValido)
              const Text(
                'La hora de término debe ser posterior a la de inicio.',
                style: TextStyle(color: NinasProColors.error700),
              ),
            if (_error != null) Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando || !_horarioValido ? null : _guardar, child: const Text('Agregar')),
      ],
    );
  }
}
