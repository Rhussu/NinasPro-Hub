import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/roles_repository.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/clase_sesion_views.dart';

/// Vistas exclusivas del Equipo de Gestión sobre las tutoras de la sede.
///
/// - [AsistenciaTutorasView]: US-33 y US-34, pase de lista de tutoras con historial y corrección por semana.
/// - [RolesSemanalesView]: US-43 y US-44, roles de cada tutora por clase (varios por tutora) y su cumplimiento.

// Pase de lista de Tutoras (US-33, US-34) con historial semana a semana y corrección posterior
class AsistenciaTutorasView extends StatefulWidget {
  /// Clase en curso: el curso, sus sesiones y la de hoy
  final ClaseSesionController controller;

  const AsistenciaTutorasView({super.key, required this.controller});

  @override
  State<AsistenciaTutorasView> createState() => _AsistenciaTutorasViewState();
}

class _AsistenciaTutorasViewState extends State<AsistenciaTutorasView> {
  bool _cargando = true;
  String? _error;

  // Clase que se está viendo y su pase de lista
  late String _sesionVistaId;
  List<RegistroAsistenciaTutora> _registros = [];
  bool _tienePaseLista = false;
  bool _corrigiendo = false;
  bool _guardando = false;
  bool _pendiente = false;

  ClaseSesionController get controller => widget.controller;
  ClaseRepository get repository => controller.repository;

  bool get _esClaseActual => _sesionVistaId == controller.sesionId;

  SesionClase? get _sesionVista => controller.sesiones.where((s) => s.id == _sesionVistaId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _sesionVistaId = controller.sesionId;
    if (_sesionVistaId.isEmpty) {
      _cargando = false;
    } else {
      _verSesion(_sesionVistaId);
    }
  }

  Future<void> _verSesion(String id) async {
    setState(() {
      _sesionVistaId = id;
      _cargando = true;
      _corrigiendo = false;
      _error = null;
    });
    try {
      final registros = await repository.asistenciaTutoras(id);
      if (!mounted || _sesionVistaId != id) return;
      final tiene = registros.any((r) => r.estado != EstadoAsistencia.pendiente);
      final sesion = _sesionVista;
      final registrable = sesion != null && sesionRegistrable(sesion, controller.hoy());
      setState(() {
        _tienePaseLista = tiene;
        // En la clase de hoy sin pase de lista, todo el equipo parte presente (US-33 escenario 1)
        _registros = [
          for (final r in registros)
            r.estado == EstadoAsistencia.pendiente && registrable && id == controller.sesionId
                ? r.copyWith(estado: EstadoAsistencia.presente)
                : r,
        ];
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || _sesionVistaId != id) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar la asistencia de tutoras. Revisa tu conexión.';
      });
    }
  }

  void _empezarCorreccion() {
    setState(() {
      _corrigiendo = true;
      _registros = [
        for (final r in _registros) r.estado == EstadoAsistencia.pendiente ? r.copyWith(estado: EstadoAsistencia.presente) : r,
      ];
    });
  }

  // Las tutoras solo alternan Presente ↔ Ausente (no tienen justificativos)
  void _ciclarEstado(int index) {
    final reg = _registros[index];
    setState(() {
      _registros[index] = reg.copyWith(
        estado: reg.estado == EstadoAsistencia.presente ? EstadoAsistencia.ausente : EstadoAsistencia.presente,
      );
    });
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final id = _sesionVistaId;
    setState(() => _guardando = true);
    final resultado = await repository.guardarAsistenciaTutoras(id, _registros);
    if (!mounted) return;
    setState(() => _guardando = false);
    final presentes = _registros.where((r) => r.estado == EstadoAsistencia.presente).length;
    mostrarResultadoGuardado(
      messenger,
      resultado,
      exito: '✅ Asistencia de tutoras guardada: $presentes de ${_registros.length} presentes.',
    );
    if (resultado.rechazado) return;
    if (resultado.pendiente) {
      setState(() {
        _pendiente = true;
        _tienePaseLista = true;
        _corrigiendo = false;
      });
    } else {
      _pendiente = false;
      await _verSesion(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (controller.sesiones.isEmpty) {
      return const EstadoSinPaseLista(titulo: 'Sin clases', mensaje: 'El curso aún no tiene clases programadas.');
    }

    final hoy = controller.hoy();
    final sesion = _sesionVista;
    final registrable = sesion != null && sesionRegistrable(sesion, hoy);
    final actual = _esClaseActual;
    final editable = registrable && (actual || _corrigiendo);
    int contar(EstadoAsistencia e) => _registros.where((r) => r.estado == e).length;

    final ultima = _registros
        .where((r) => r.editadoPor != null && r.editadoEn != null)
        .fold<RegistroAsistenciaTutora?>(null, (a, r) => a == null || r.editadoEn!.isAfter(a.editadoEn!) ? r : a);

    final etiqueta = actual
        ? 'Clase actual'
        : registrable
        ? (_corrigiendo ? 'Historial · corrigiendo' : 'Historial · solo lectura')
        : (sesion?.suspendida ?? false)
        ? 'Clase suspendida'
        : 'Próxima clase';

    Widget contenido;
    if (_cargando) {
      contenido = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      contenido = EstadoSinPaseLista(icono: Icons.cloud_off_rounded, titulo: 'Sin datos', mensaje: _error!);
    } else if (sesion?.suspendida ?? false) {
      contenido = EstadoSinPaseLista(
        icono: Icons.event_busy_rounded,
        titulo: 'Clase suspendida',
        mensaje: sesion?.motivoSuspension ?? 'Esta clase no se realiza.',
      );
    } else if (!registrable) {
      contenido = const EstadoSinPaseLista(
        titulo: 'Clase programada',
        mensaje: 'Esta clase aún no se realiza: el pase de lista se abre el día de la clase.',
      );
    } else if (_registros.isEmpty) {
      contenido = const EstadoSinPaseLista(
        icono: Icons.group_off_rounded,
        titulo: 'Sin tutoras asignadas',
        mensaje: 'Nadie está asignada a este curso todavía.',
      );
    } else if (!_tienePaseLista && !editable) {
      contenido = EstadoSinPaseLista(
        mensaje: 'Esta clase aún no tiene la asistencia de tutoras registrada.',
        accion: TextButton.icon(
          onPressed: _empezarCorreccion,
          icon: const Icon(Icons.fact_check_rounded, size: 18),
          label: const Text('Pasar lista'),
        ),
      );
    } else {
      contenido = Column(
        children: [
          BarraContadoresAsistencia(
            contadores: [
              ContadorAsistencia(label: 'Presentes', count: contar(EstadoAsistencia.presente), estado: EstadoAsistencia.presente),
              ContadorAsistencia(label: 'Ausentes', count: contar(EstadoAsistencia.ausente), estado: EstadoAsistencia.ausente),
            ],
          ),
          if (_pendiente) const AvisoPendienteEnvio(),
          if (_tienePaseLista) LineaUltimaEdicion(autora: ultima?.editadoPor, hora: ultima?.editadoEn),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _registros.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final reg = _registros[index];

                return TarjetaAsistencia(
                  nombre: reg.tutoraNombre,
                  estado: reg.estado,
                  onTap: editable ? () => _ciclarEstado(index) : null,
                  etiqueta: reg.esEquipoGestion
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: NinasProColors.accent700.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Gestión',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: NinasProColors.accent700),
                          ),
                        )
                      : null,
                  detalle: Text(
                    reg.esEquipoGestion ? 'Equipo de Gestión' : 'Tutora',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                );
              },
            ),
          ),
          if (editable)
            BarraGuardarAsistencia(
              label: actual ? 'Guardar Asistencia de Tutoras' : 'Guardar Corrección',
              onGuardar: _guardando ? null : _guardar,
            )
          else if (registrable)
            BarraGuardarAsistencia(label: 'Corregir lista', icono: Icons.edit_rounded, onGuardar: _empezarCorreccion),
        ],
      );
    }

    return Column(
      children: [
        SelectorSemanaClase(
          sesiones: controller.sesiones,
          sesionVistaId: _sesionVistaId,
          sesionActualId: controller.sesionId,
          etiqueta: etiqueta,
          onCambiar: _verSesion,
        ),
        Expanded(child: contenido),
      ],
    );
  }
}

/// Clase para la que se reparten los roles: la próxima que no está suspendida
/// (hoy incluida), o la última del curso si ya terminó (US-43 escenario 2, US-44 escenario 1).
SesionClase? claseParaRoles(List<SesionClase> sesiones, DateTime hoy) {
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  final activas = sesiones.where((s) => !s.suspendida).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
  return activas.where((s) => !DateTime(s.fecha.year, s.fecha.month, s.fecha.day).isBefore(dia)).firstOrNull ??
      activas.lastOrNull;
}

/// Roles del equipo en cada clase del curso (US-43 escenarios 2..4, US-44).
///
/// Con [editable] (Equipo de Gestión de la sede) se eligen los roles de cada
/// tutora (0, 1, 2 o más) y se marca el cumplimiento de cualquiera. Sin él
/// (tutora) es de solo lectura, salvo sus propios roles, que puede marcar.
class RolesSemanalesView extends StatefulWidget {
  final ClaseSesionController controller;
  final RolesRepository roles;

  /// Usuaria autenticada: marca sus propios roles
  final String perfilId;
  final bool editable;

  const RolesSemanalesView({
    super.key,
    required this.controller,
    required this.roles,
    required this.perfilId,
    this.editable = false,
  });

  @override
  State<RolesSemanalesView> createState() => _RolesSemanalesViewState();
}

class _RolesSemanalesViewState extends State<RolesSemanalesView> {
  bool _cargando = true;
  String? _error;
  SesionClase? _clase;
  List<RolTarea> _catalogo = [];
  List<TutoraRolesClase> _equipo = [];

  List<SesionClase> get _sesiones => widget.controller.sesiones;
  SesionClase? get _sugerida => claseParaRoles(_sesiones, widget.controller.hoy());

  @override
  void initState() {
    super.initState();
    _clase = _sugerida;
    _cargar();
  }

  Future<void> _cargar() async {
    final clase = _clase;
    if (clase == null) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final catalogo = await widget.roles.roles(incluirInactivos: true);
      final equipo = await widget.roles.equipoClase(clase.id);
      if (!mounted || _clase?.id != clase.id) return;
      setState(() {
        _catalogo = catalogo;
        _equipo = equipo;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar los roles. Revisa tu conexión.';
      });
    }
  }

  void _cambiarClase(int delta) {
    final i = _sesiones.indexWhere((s) => s.id == _clase?.id) + delta;
    if (i < 0 || i >= _sesiones.length) return;
    _clase = _sesiones[i];
    _cargar();
  }

  RolTarea? _rol(String id) => _catalogo.where((r) => r.id == id).firstOrNull;

  Future<void> _marcar(TareaClase tarea, bool completada) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await widget.roles.marcarCumplido(tarea.id, completada);
    if (!r.ok) messenger.showSnackBar(SnackBar(backgroundColor: NinasProColors.error700, content: Text(r.error!)));
    await _cargar();
  }

  Future<void> _elegirRoles(TutoraRolesClase tutora) async {
    final clase = _clase!;
    final actuales = tutora.rolIds;
    // Se ofrecen los activos y los inactivos que ya tiene (para poder quitarlos)
    final opciones = _catalogo.where((r) => r.activo || actuales.contains(r.id)).toList();
    final elegidos = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _DialogoRolesTutora(tutora: tutora, clase: clase, opciones: opciones, iniciales: actuales),
    );
    if (elegidos == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await widget.roles.guardarRoles(claseId: clase.id, tutoraId: tutora.tutoraId, rolIds: elegidos);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: r.ok ? NinasProColors.success700 : NinasProColors.error700,
        content: Text(
          r.ok
              ? (elegidos.isEmpty
                    ? '${tutora.nombre} queda sin roles en la clase ${clase.numeroSesion}.'
                    : '✅ ${elegidos.length} ${elegidos.length == 1 ? 'rol' : 'roles'} para ${tutora.nombre} en la clase ${clase.numeroSesion}.')
              : r.error!,
        ),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clase = _clase;
    if (clase == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('El curso aún no tiene clases programadas.', textAlign: TextAlign.center),
        ),
      );
    }
    final i = _sesiones.indexWhere((s) => s.id == clase.id);
    final f = clase.fecha;
    final fecha = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    final esSugerida = clase.id == _sugerida?.id;

    return Column(
      children: [
        // Selector de clase
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            border: Border(bottom: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Clase anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: i > 0 ? () => _cambiarClase(-1) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Clase ${clase.numeroSesion} · $fecha', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      clase.suspendida
                          ? 'Suspendida'
                          : esSugerida
                          ? 'Próxima clase'
                          : 'de ${_sesiones.length} del curso',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: esSugerida
                            ? NinasProColors.brandPink
                            : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clase siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: i < _sesiones.length - 1 ? () => _cambiarClase(1) : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _buildEquipo(isDark, clase),
        ),
      ],
    );
  }

  Widget _buildEquipo(bool isDark, SesionClase clase) {
    final conRol = _equipo.where((t) => t.tareas.isNotEmpty).length;
    final asignados = {for (final t in _equipo) ...t.rolIds};
    final obligatoriosSinCubrir = _catalogo.where((r) => r.activo && r.esRequerido && !asignados.contains(r.id)).toList();
    final editable = widget.editable && !clase.suspendida;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (clase.suspendida)
          _Aviso(
            icono: Icons.event_busy_rounded,
            texto: 'Esta clase está suspendida${clase.motivoSuspension == null ? '' : ' (${clase.motivoSuspension})'}: no lleva roles.',
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NinasProColors.primary700.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.diversity_3_rounded, color: NinasProColors.brandPink, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$conRol de ${_equipo.length} tutoras con rol en esta clase. '
                    '${widget.editable ? 'Cada tutora puede tener uno o varios roles.' : 'Los roles los asigna el Equipo de Gestión.'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (!clase.suspendida && obligatoriosSinCubrir.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Aviso(
            icono: Icons.warning_amber_rounded,
            texto: 'Roles obligatorios sin cubrir: ${obligatoriosSinCubrir.map((r) => r.nombre).join(', ')}.',
          ),
        ],
        const SizedBox(height: 14),
        if (_equipo.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('El curso aún no tiene tutoras asignadas.', textAlign: TextAlign.center),
          ),
        for (final tutora in _equipo) _buildTutora(isDark, tutora, editable),
      ],
    );
  }

  Widget _buildTutora(bool isDark, TutoraRolesClase tutora, bool editable) {
    final propia = tutora.tutoraId == widget.perfilId;
    final puedeMarcar = widget.editable || propia;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: propia ? NinasProColors.brandPink : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                  child: Text(
                    tutora.nombre.isEmpty ? '?' : tutora.nombre[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    propia ? '${tutora.nombre} (tú)' : tutora.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                if (tutora.esEquipoGestion)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: NinasProColors.accent700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Gestión',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: NinasProColors.accent700),
                    ),
                  ),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                    tooltip: 'Elegir los roles de ${tutora.nombre}',
                    onPressed: () => _elegirRoles(tutora),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
            if (tutora.tareas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 42, bottom: 6),
                child: Text(
                  'Sin rol asignado',
                  style: TextStyle(fontSize: 11.5, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                ),
              ),
            for (final t in tutora.tareas)
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 30),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _rol(t.rolId)?.color,
                value: t.completada,
                onChanged: puedeMarcar ? (v) => _marcar(t, v ?? false) : null,
                title: Text(
                  _rol(t.rolId)?.nombre ?? 'Rol',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _rol(t.rolId)?.color,
                    decoration: t.completada ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Selección múltiple de los roles de una tutora en una clase
class _DialogoRolesTutora extends StatefulWidget {
  final TutoraRolesClase tutora;
  final SesionClase clase;
  final List<RolTarea> opciones;
  final Set<String> iniciales;

  const _DialogoRolesTutora({required this.tutora, required this.clase, required this.opciones, required this.iniciales});

  @override
  State<_DialogoRolesTutora> createState() => _DialogoRolesTutoraState();
}

class _DialogoRolesTutoraState extends State<_DialogoRolesTutora> {
  late final Set<String> _elegidos = {...widget.iniciales};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Roles de la clase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.tutora.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                'Clase ${widget.clase.numeroSesion} · elige uno o varios roles, o ninguno.',
                style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
              ),
              const SizedBox(height: 8),
              for (final rol in widget.opciones)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: rol.color,
                  value: _elegidos.contains(rol.id),
                  onChanged: (v) => setState(() => v == true ? _elegidos.add(rol.id) : _elegidos.remove(rol.id)),
                  title: Text(
                    '${rol.nombre}${rol.esRequerido ? ' · obligatorio' : ''}${rol.activo ? '' : ' · inactivo'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: rol.descripcion.isEmpty ? null : Text(rol.descripcion, style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: NinasProTheme.brandButton,
          onPressed: () => Navigator.pop(context, _elegidos),
          child: Text(_elegidos.isEmpty ? 'Dejar sin roles' : 'Guardar (${_elegidos.length})'),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: NinasProColors.warning100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: NinasProColors.warning900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NinasProColors.warning900),
            ),
          ),
        ],
      ),
    );
  }
}
