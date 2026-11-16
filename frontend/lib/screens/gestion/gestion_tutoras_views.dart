import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/hub_repository.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/clase_sesion_views.dart';

/// Vistas exclusivas del Equipo de Gestión sobre las tutoras de la sede.
///
/// - [AsistenciaTutorasView]: US-33 y US-34, pase de lista de tutoras con historial y corrección por semana.
/// - [RolesSemanalesView]: US-43, asignación de roles a tutoras para una semana elegida.

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

// Asignación de Roles a Tutoras por semana (US-43)
class RolesSemanalesView extends StatefulWidget {
  final HubRepository repository;
  final String sedeId;
  final int semanaInicial;
  final int totalSemanas;

  const RolesSemanalesView({
    super.key,
    required this.repository,
    this.sedeId = 'sede-beauchef',
    this.semanaInicial = 4,
    this.totalSemanas = 10,
  });

  @override
  State<RolesSemanalesView> createState() => _RolesSemanalesViewState();
}

class _RolesSemanalesViewState extends State<RolesSemanalesView> {
  bool _cargando = true;
  late int _semana;

  List<Tutora> _tutoras = [];
  List<RolTutorConfig> _rolesConfig = [];
  List<AsignacionSemanalTutora> _asignaciones = [];

  @override
  void initState() {
    super.initState();
    _semana = widget.semanaInicial;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final tuts = await widget.repository.getTutoras(sedeId: widget.sedeId);
    final roles = await widget.repository.getRolesTutora();
    final asigs = await widget.repository.getAsignacionesSemanales(semanaNumero: _semana);
    if (!mounted) return;
    setState(() {
      _tutoras = tuts;
      _rolesConfig = roles;
      _asignaciones = asigs;
      _cargando = false;
    });
  }

  void _cambiarSemana(int nueva) {
    if (nueva < 1 || nueva > widget.totalSemanas) return;
    _semana = nueva;
    _cargarDatos();
  }

  // Diálogo para asignar rol a una tutora en la semana seleccionada
  void _mostrarDialogoAsignarRol(Tutora tutora) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semana = _semana;
    String rolSeleccionado = _rolesConfig.firstOrNull?.codigo ?? '';

    // Buscar si ya tiene asignación previa
    final asignacionActual = _asignaciones.where((a) => a.tutoraId == tutora.id).firstOrNull;
    if (asignacionActual != null) {
      rolSeleccionado = asignacionActual.rolCodigo;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NinasProColors.primary700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: NinasProColors.brandPink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Asignar Rol Semanal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutora.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Semana $semana · Sede Beauchef',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Selecciona la responsabilidad para esta semana (US-43):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ..._rolesConfig.map((rol) {
                      final sel = rolSeleccionado == rol.codigo;
                      return InkWell(
                        onTap: () => setDialogState(() => rolSeleccionado = rol.codigo),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                sel ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: sel ? NinasProColors.brandPink : NinasProColors.neutral500,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rol.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text(rol.descripcion, style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: NinasProTheme.brandButton,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await widget.repository.asignarRolSemanal(
                      tutoraId: tutora.id,
                      semanaNumero: semana,
                      rolCodigo: rolSeleccionado,
                    );
                    await _cargarDatos();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: NinasProColors.success700,
                        content: Text('✅ Rol de la semana $semana asignado a ${tutora.nombre}.'),
                      ),
                    );
                  },
                  child: const Text('Confirmar Asignación'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Selector de semana
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _semana > 1 ? () => _cambiarSemana(_semana - 1) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Semana $_semana',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _semana == widget.semanaInicial ? 'Semana actual' : 'de ${widget.totalSemanas} del programa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _semana == widget.semanaInicial
                            ? NinasProColors.brandPink
                            : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _semana < widget.totalSemanas ? () => _cambiarSemana(_semana + 1) : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _buildListaTutoras(isDark),
        ),
      ],
    );
  }

  Widget _buildListaTutoras(bool isDark) {
    final asignadas = _tutoras.where((t) => _asignaciones.any((a) => a.tutoraId == t.id)).length;
    final obligatoriosSinCubrir = _rolesConfig
        .where((r) => r.esRequerido && !_asignaciones.any((a) => a.rolCodigo == r.codigo))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
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
                  '$asignadas de ${_tutoras.length} tutoras con rol asignado esta semana. '
                  'Los roles obligatorios deben quedar cubiertos antes del sábado (US-43).',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (obligatoriosSinCubrir.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NinasProColors.warning100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: NinasProColors.warning900, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Roles obligatorios sin cubrir: '
                    '${obligatoriosSinCubrir.map((r) => r.nombre).join(', ')}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NinasProColors.warning900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        ..._tutoras.map((tutora) {
          final asignacion = _asignaciones.where((a) => a.tutoraId == tutora.id).firstOrNull;
          final rolActual = _rolesConfig.where((r) => r.codigo == asignacion?.rolCodigo).firstOrNull;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () => _mostrarDialogoAsignarRol(tutora),
              leading: CircleAvatar(
                backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                child: Text(
                  tutora.nombre[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      tutora.nombre,
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
                ],
              ),
              subtitle: Text(
                rolActual != null ? rolActual.nombre : 'Sin rol asignado',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: rolActual != null ? FontWeight.w700 : FontWeight.w400,
                  color: rolActual != null
                      ? NinasProColors.brandPink
                      : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                tooltip: 'Asignar o Cambiar Rol',
                onPressed: () => _mostrarDialogoAsignarRol(tutora),
              ),
            ),
          );
        }),
      ],
    );
  }
}
