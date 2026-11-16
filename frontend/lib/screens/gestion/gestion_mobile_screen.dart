import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../../widgets/ninaspro_speed_dial.dart';
import '../../widgets/ninaspro_stat_card.dart';
import '../alumnas/pendientes_autorizacion_screen.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/clase_sesion_views.dart';
import '../tutora/inicio_tutora_widgets.dart';
import 'gestion_tutoras_views.dart';

/// Pantalla móvil para el Equipo de Gestión de Sede en NiñasPro Hub.
///
/// Características clave:
/// - Todos los miembros del equipo de gestión son tutoras, pero tienen permisos extendidos de gestión de sede.
///   Por eso el Speed Dial da acceso a las mismas pantallas de clase que la Tutora
///   (asistencia, ejercicios, fotos y Kahoot), compartidas vía [ClaseSesionController].
/// - Pantalla principal con resumen de la sede, justificativos pendientes y alertas activas.
/// - US-37: Aprobación y resolución exclusiva de justificativos de inasistencia de alumnas.
/// - US-37/US-39: Alertas tempranas de deserción e inasistencias en la sede.
class GestionMobileScreen extends StatefulWidget {
  final HubRepository repository;

  /// Tutora del Equipo de Gestión que usa la app
  final String tutoraId;

  /// Autorizaciones pendientes de las alumnas de la sede (US-11); opcional sin base de datos
  final AlumnasRepository? alumnasRepository;

  const GestionMobileScreen({
    super.key,
    required this.repository,
    this.alumnasRepository,
    this.tutoraId = 'tutora-1', // Camila Sepúlveda Rivas por defecto
  });

  @override
  State<GestionMobileScreen> createState() => _GestionMobileScreenState();
}

class _GestionMobileScreenState extends State<GestionMobileScreen> {
  bool _cargando = true;
  bool _recargando = false;

  List<Justificativo> _justificativos = [];
  List<Tutora> _tutoras = [];
  List<AlertaDesercion> _alertas = [];
  List<Alumna> _alumnas = [];
  List<SesionClase> _sesiones = [];
  Curso? _curso;
  List<RolTutorConfig> _rolesConfig = [];
  List<AsignacionSemanalTutora> _asignaciones = [];

  // Mi registro como tutora: asistencia y rol de cada clase del curso
  List<ClaseTutoraResumen> _miHistorial = [];

  // Curso de la sede (mockup: un único curso por sede)
  static const _cursoId = 'curso-pcb-stgo';
  static const _sedeId = 'sede-beauchef';

  // Clase en curso, compartida con las pantallas de Tutora
  late final ClaseSesionController _clase;

  @override
  void initState() {
    super.initState();
    _clase = ClaseSesionController(repository: widget.repository);
    _cargarDatos();
  }

  @override
  void dispose() {
    _clase.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final justs = await widget.repository.getJustificativos(sedeId: _sedeId);
    final tuts = await widget.repository.getTutoras(sedeId: _sedeId);
    final alerts = await widget.repository.getAlertasDesercion(sedeId: _sedeId);
    final alumnas = await widget.repository.getAlumnas(cursoId: _cursoId);
    final sesiones = await widget.repository.getSesiones(cursoId: _cursoId);
    final cursos = await widget.repository.getCursos();
    final roles = await widget.repository.getRolesTutora();
    await _clase.cargar();
    final semana = sesiones.where((s) => s.id == _clase.sesionId).firstOrNull?.numeroSesion ?? 1;
    final asigs = await widget.repository.getAsignacionesSemanales(semanaNumero: semana);
    await _cargarMiAsistencia(sesiones, roles);

    if (!mounted) return;
    setState(() {
      _justificativos = justs;
      _tutoras = tuts;
      _alertas = alerts;
      _alumnas = alumnas;
      _sesiones = sesiones;
      _curso = cursos.where((c) => c.id == _cursoId).firstOrNull;
      _rolesConfig = roles;
      _asignaciones = asigs;
      _cargando = false;
    });
  }

  // Recarga deslizando hacia abajo: descarga los datos de la nube (~1 s simulado) mostrando el esqueleto
  Future<void> _recargar() async {
    setState(() => _recargando = true);
    await widget.repository.recargar();
    await _cargarDatos();
    if (!mounted) return;
    setState(() => _recargando = false);
  }

  List<Justificativo> get _pendientes =>
      _justificativos.where((j) => j.estado == 'pendiente').toList();

  List<AlertaDesercion> get _alertasActivas =>
      _alertas.where((a) => a.estado == 'activa').toList();

  // Carga mi registro individual como tutora: asistencia y rol por clase (US-33)
  Future<void> _cargarMiAsistencia(List<SesionClase> sesiones, List<RolTutorConfig> roles) async {
    _miHistorial = await cargarHistorialTutora(
      repository: widget.repository,
      tutoraId: widget.tutoraId,
      sesiones: sesiones,
      roles: roles,
    );
  }

  Iterable<ClaseTutoraResumen> get _misClasesRegistradas =>
      _miHistorial.where((c) => c.estado != EstadoAsistencia.pendiente);

  Future<void> _abrirAsistenciaTutoras() async {
    await _abrirPantallaClase(
      'Asistencia de Tutoras',
      AsistenciaTutorasView(
        repository: widget.repository,
        sesionActualId: _clase.sesionId,
        cursoId: _cursoId,
      ),
    );
    // Refresca mi asistencia y mis roles al volver
    await _cargarMiAsistencia(_sesiones, _rolesConfig);
    if (!mounted) return;
    setState(() {});
  }

  // Tutora del Equipo de Gestión que usa la app
  Tutora? get _tutoraActual => _tutoras.where((t) => t.id == widget.tutoraId).firstOrNull;

  // Semana de la clase en curso (una sesión por semana)
  int get _semanaActual =>
      _sesiones.where((s) => s.id == _clase.sesionId).firstOrNull?.numeroSesion ?? 1;

  RolTutorConfig? get _miRolSemana {
    final asignacion = _asignaciones.where((a) => a.tutoraId == widget.tutoraId).firstOrNull;
    return _rolesConfig.where((r) => r.codigo == asignacion?.rolCodigo).firstOrNull;
  }

  Future<void> _abrirRolesSemanales() async {
    await _abrirPantallaClase(
      'Roles de Tutoras',
      RolesSemanalesView(
        repository: widget.repository,
        sedeId: _sedeId,
        semanaInicial: _semanaActual,
        totalSemanas: _curso?.totalSesiones ?? 10,
      ),
    );
    // Refresca "Tu rol esta semana" al volver
    final asigs = await widget.repository.getAsignacionesSemanales(semanaNumero: _semanaActual);
    if (!mounted) return;
    setState(() => _asignaciones = asigs);
  }

  // Abre una pantalla de la clase o de tutoras
  Future<void> _abrirPantallaClase(String titulo, Widget vista) =>
      abrirPantallaSecundaria(context, titulo, vista);

  // Modal para ingresar un justificativo manualmente; queda aprobado de inmediato (US-37)
  void _mostrarModalJustificativoManual() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detalleCtrl = TextEditingController();

    if (_alumnas.isEmpty || _sesiones.isEmpty) return;

    String sesionId = _sesiones
            .where((s) => s.id == _clase.sesionId)
            .firstOrNull
            ?.id ??
        _sesiones.first.id;
    String alumnaId = _alumnas.first.id;
    String? errorDetalle;

    final campoDecoration = BoxDecoration(
      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
      borderRadius: BorderRadius.circular(12),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: NinasProColors.success100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.note_add_rounded, color: NinasProColors.success900, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Ingresar Justificativo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se registra como aprobado de inmediato y la asistencia de esa clase queda Justificada.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Semana:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: campoDecoration,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: sesionId,
                          dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                          items: _sesiones.map((s) {
                            final f = s.fecha;
                            final fechaStr = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
                            return DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                'Semana ${s.numeroSesion} ($fechaStr) · ${s.tema}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => sesionId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Alumna:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: campoDecoration,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: alumnaId,
                          dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                          items: _alumnas.map((a) {
                            return DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                a.nombre,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => alumnaId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Descripción:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: detalleCtrl,
                      maxLines: 3,
                      onChanged: (_) {
                        if (errorDetalle != null) {
                          setModalState(() => errorDetalle = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Ej: Apoderada avisó por WhatsApp que la alumna está con licencia médica...',
                        errorText: errorDetalle,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: () async {
                          if (detalleCtrl.text.trim().isEmpty) {
                            setModalState(
                              () => errorDetalle = 'Debes ingresar la descripción del justificativo.',
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          await widget.repository.registrarJustificativoManual(
                            alumnaId: alumnaId,
                            sesionId: sesionId,
                            detalle: detalleCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('✅ Justificativo registrado y aprobado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Registrar y Aprobar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Modal para resolver justificativo de inasistencia (US-37)
  void _mostrarModalResolverJustificativo(Justificativo just) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obsCtrl = TextEditingController(text: just.observacionesResolucion ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NinasProColors.warning100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rule_folder_rounded, color: NinasProColors.warning900, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revisar Justificativo (US-37)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? NinasProColors.white : NinasProColors.neutral900,
                            ),
                          ),
                          Text(
                            'Exclusivo Equipo de Gestión',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumna: ${just.alumnaNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clase / Fecha: ${just.sesionFecha.day}/${just.sesionFecha.month}/${just.sesionFecha.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${just.motivoTipificado}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${just.detalle}"',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Observaciones de la resolución (opcional):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Certificado recibido y verificado por gestión...',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NinasProColors.error700,
                          side: const BorderSide(color: NinasProColors.error700),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.repository.resolverJustificativo(
                            justificativoId: just.id,
                            aprobado: false,
                            observaciones: obsCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.error700,
                              content: Text('❌ Justificativo rechazado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.repository.resolverJustificativo(
                            justificativoId: just.id,
                            aprobado: true,
                            observaciones: obsCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('✅ Justificativo aprobado. Asistencia recalculada a 70% min.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Deslizar hacia abajo recarga; mientras tanto se muestra el esqueleto de la pantalla
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: _cargando || _recargando ? const NinasProSkeletonInicio() : _buildPantallaPrincipal(isDark),
      ),
      // Speed Dial: el primer elemento de la lista queda arriba y el último junto al rayito
      floatingActionButton: NinasProSpeedDial(
        acciones: [
          AccionRapida(
            icon: Icons.note_add_rounded,
            tooltip: 'Ingresar justificativo',
            backgroundColor: NinasProColors.neutral100,
            foregroundColor: NinasProColors.neutral900,
            onTap: _mostrarModalJustificativoManual,
          ),
          AccionRapida(
            icon: Icons.assignment_ind_rounded,
            tooltip: 'Asignar roles a tutoras',
            backgroundColor: NinasProColors.secondary100,
            foregroundColor: NinasProColors.secondary900,
            onTap: _abrirRolesSemanales,
          ),
          AccionRapida(
            icon: Icons.groups_rounded,
            tooltip: 'Asistencia de tutoras',
            backgroundColor: NinasProColors.info100,
            foregroundColor: NinasProColors.info900,
            onTap: _abrirAsistenciaTutoras,
          ),
          AccionRapida(
            icon: Icons.emoji_events_rounded,
            tooltip: 'Registrar Kahoot',
            backgroundColor: NinasProColors.warning100,
            foregroundColor: NinasProColors.warning900,
            onTap: () => mostrarModalRegistroKahoot(context, _clase),
          ),
          AccionRapida(
            icon: Icons.camera_alt_rounded,
            tooltip: 'Fotos',
            backgroundColor: NinasProColors.accent100,
            foregroundColor: NinasProColors.accent900,
            onTap: () => _abrirPantallaClase('Fotos', FotosClaseView(controller: _clase)),
          ),
          AccionRapida(
            icon: Icons.code_rounded,
            tooltip: 'Ejercicios',
            backgroundColor: NinasProColors.success100,
            foregroundColor: NinasProColors.success900,
            onTap: () => _abrirPantallaClase('Ejercicios', EjerciciosClaseView(controller: _clase)),
          ),
          AccionRapida(
            icon: Icons.fact_check_rounded,
            tooltip: 'Asistencia',
            backgroundColor: NinasProColors.primary100,
            foregroundColor: NinasProColors.primary900,
            onTap: () => _abrirPantallaClase('Asistencia', AsistenciaClaseView(controller: _clase)),
          ),
        ],
      ),
    );
  }

  // Pantalla principal: resumen de la sede + justificativos pendientes + alertas activas
  Widget _buildPantallaPrincipal(bool isDark) {
    final pendientes = _pendientes;
    final alertas = _alertasActivas;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Planificación de la clase de hoy, curso y sede
        BannerBienvenidaTutora(
          nombre: _tutoraActual?.nombre,
          sesion: _clase.sesionActual,
          cursoNombre: _curso?.nombre,
          sedeNombre: _tutoraActual?.sedeNombre,
        ),
        const SizedBox(height: 14),

        // Preinscritas sin consentimiento de datos, destacadas tras 2 sesiones (US-11)
        if (widget.alumnasRepository case final alumnas?) TarjetaAutorizacionesPendientes(repository: alumnas),

        // Resumen rápido de la clase y la sede
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _clase,
                builder: (context, _) => NinasProStatCard(
                  title: 'Alumnas presentes',
                  value: '${_clase.totalPresentes}/${_clase.registros.length}',
                  subtitle: 'Esta semana',
                  icon: Icons.fact_check_rounded,
                  accentColor: NinasProColors.primary700,
                  onTap: () => _abrirPantallaClase('Asistencia', AsistenciaClaseView(controller: _clase)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Abre mi registro individual; la de todas las tutoras está en el Speed Dial
              child: TarjetaMiAsistencia(
                asistidas: _misClasesRegistradas.where((c) => c.estado == EstadoAsistencia.presente).length,
                registradas: _misClasesRegistradas.length,
                onTap: () => _abrirPantallaClase(
                  'Mi Asistencia',
                  MiHistorialTutoraView(historial: _miHistorial, sesionActualId: _clase.sesionId),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TarjetaMiRol(
          rol: _miRolSemana,
          semana: _semanaActual,
          mensajeSinRol: 'Toca para asignarte un rol en Roles de Tutoras.',
          onTap: _abrirRolesSemanales,
        ),

        const SizedBox(height: 10),
                // Recursos del curso de la sede (Classroom y Juez Virtual, US-26)
        if (_curso != null && (_curso!.classroomUrl != null || _curso!.juezVirtualUrl != null)) ...[
          NinasProRecursosCursoCard(curso: _curso!),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 20),

        // Justificativos pendientes de aprobación (US-37)
        _buildEncabezadoSeccion(
          isDark,
          icon: Icons.assignment_turned_in_outlined,
          titulo: 'Justificativos pendientes',
          cantidad: pendientes.length,
          color: NinasProColors.warning700,
        ),
        const SizedBox(height: 10),
        if (pendientes.isEmpty)
          _buildEstadoVacio(
            isDark,
            icon: Icons.task_alt_rounded,
            titulo: 'Todo al día',
            mensaje: 'No hay justificativos esperando tu aprobación.',
          )
        else
          ...pendientes.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTarjetaJustificativo(isDark, j),
              )),
        const SizedBox(height: 20),

        // Alertas tempranas de deserción (US-37/US-39)
        _buildEncabezadoSeccion(
          isDark,
          icon: Icons.notifications_active_outlined,
          titulo: 'Alertas de deserción',
          cantidad: alertas.length,
          color: NinasProColors.error700,
        ),
        const SizedBox(height: 10),
        if (alertas.isEmpty)
          _buildEstadoVacio(
            isDark,
            icon: Icons.favorite_rounded,
            titulo: 'Sin alumnas en riesgo',
            mensaje: 'Ninguna alumna acumula inasistencias consecutivas. ¡Sigan así!',
          )
        else
          ...alertas.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTarjetaAlerta(isDark, a),
              )),
        const SizedBox(height: 20),

        const TarjetaConsejo(
          texto: 'Tip: toca ⚡ para pasar lista, registrar ejercicios, subir la foto de la clase '
              'o guardar el podio Kahoot, igual que una tutora en el aula.',
        ),
      ],
    );
  }

  Widget _buildEncabezadoSeccion(
    bool isDark, {
    required IconData icon,
    required String titulo,
    required int cantidad,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cantidad > 0
                ? color.withValues(alpha: 0.15)
                : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$cantidad',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cantidad > 0 ? color : NinasProColors.neutral500,
            ),
          ),
        ),
      ],
    );
  }

  // Relleno amigable cuando una sección no tiene elementos
  Widget _buildEstadoVacio(
    bool isDark, {
    required IconData icon,
    required String titulo,
    required String mensaje,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: NinasProColors.success700),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de justificativo pendiente (US-37)
  Widget _buildTarjetaJustificativo(bool isDark, Justificativo j) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NinasProColors.warning500, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    j.alumnaNombre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NinasProColors.warning100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PENDIENTE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: NinasProColors.warning900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Clase del ${j.sesionFecha.day}/${j.sesionFecha.month}/${j.sesionFecha.year} · Motivo: ${j.motivoTipificado}',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${j.detalle}"',
              style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _mostrarModalResolverJustificativo(j),
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: const Text('Evaluar Justificativo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta de alerta temprana de deserción activa (US-37/US-39)
  Widget _buildTarjetaAlerta(bool isDark, AlertaDesercion a) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NinasProColors.error700, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    a.alumnaNombre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NinasProColors.error100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN RIESGO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: NinasProColors.error900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${a.inasistenciasConsecutivas} inasistencias consecutivas registradas.',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Apoderada: ${a.apoderadoContacto}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await widget.repository.contactarAlerta(
                    alertaId: a.id,
                    observacionesContacto: 'Contactada por equipo de gestión vía WhatsApp.',
                  );
                  await _cargarDatos();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      backgroundColor: NinasProColors.success700,
                      content: Text('📞 Alerta marcada como contactada.'),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                label: const Text('Registrar Contacto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
