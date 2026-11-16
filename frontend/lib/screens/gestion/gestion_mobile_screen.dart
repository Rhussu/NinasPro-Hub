import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/evidencias_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../repositories/justificativos_repository.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../../widgets/ninaspro_speed_dial.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/clase_sesion_views.dart';
import '../tutora/fotos_clase_view.dart';
import '../tutora/inicio_tutora_widgets.dart';
import 'gestion_tutoras_views.dart';
import 'justificativos_gestion.dart';

/// Pantalla móvil para el Equipo de Gestión de Sede en NiñasPro Hub.
///
/// Características clave:
/// - Todos los miembros del equipo de gestión son tutoras, pero tienen permisos extendidos de gestión de sede.
///   Por eso el Speed Dial da acceso a las mismas pantallas de clase que la Tutora
///   (asistencia, ejercicios, fotos y Kahoot), compartidas vía [ClaseSesionController].
/// - Pantalla principal con resumen de la sede, bandeja de justificativos, clases
///   sin foto tras 48 horas (US-20) y alertas activas.
/// - US-16/US-37: Aprobación, rechazo, registro y eliminación exclusiva de justificativos.
/// - US-37/US-39: Alertas tempranas de deserción e inasistencias en la sede.
class GestionMobileScreen extends StatefulWidget {
  /// Repositorio del mockup: alertas y roles semanales (se conectan en sus PR)
  final HubRepository repository;

  /// La clase real: cursos de la sede, pase de lista de alumnas y de tutoras
  final ClaseRepository clase;

  /// Integrante del Equipo de Gestión autenticada
  final SesionUsuario sesion;

  /// Bandeja de justificativos de la sede (US-16, US-37)
  final JustificativosRepository? justificativos;

  /// Fotos de evidencia y clases sin foto tras 48 horas (US-18..US-20)
  final EvidenciasRepository? evidencias;

  /// Id de la tutora en el mockup, para mostrar su rol semanal mientras tanto
  final String tutoraIdRoles;

  const GestionMobileScreen({
    super.key,
    required this.repository,
    required this.clase,
    required this.sesion,
    this.justificativos,
    this.evidencias,
    this.tutoraIdRoles = 'tutora-1', // Camila Sepúlveda Rivas en el mockup
  });

  @override
  State<GestionMobileScreen> createState() => _GestionMobileScreenState();
}

class _GestionMobileScreenState extends State<GestionMobileScreen> {
  bool _cargando = true;
  bool _recargando = false;

  // Datos del mockup hasta conectar roles (PR 6) y alertas (PR 7)
  List<AlertaDesercion> _alertas = [];
  List<RolTutorConfig> _rolesConfig = [];

  /// Bandeja de justificativos; null sin conexión con la base
  BandejaJustificativosController? _bandeja;

  /// Clases realizadas hace más de 48 horas sin foto (US-20)
  List<EvidenciaPendiente> _evidenciasPendientes = const [];
  List<AsignacionSemanalTutora> _asignaciones = [];

  // Mi registro como tutora: asistencia y rol de cada clase del curso
  List<ClaseTutoraResumen> _miHistorial = [];

  // Sede del mockup para los datos que aún no se conectan
  static const _sedeIdMockup = 'sede-beauchef';

  // Clase en curso, compartida con las pantallas de Tutora
  late final ClaseSesionController _clase;

  @override
  void initState() {
    super.initState();
    _clase = ClaseSesionController(repository: widget.clase);
    final justificativos = widget.justificativos;
    if (justificativos != null) {
      // Aprobar, registrar o eliminar cambia la asistencia: se relee la clase
      _bandeja = BandejaJustificativosController(justificativos, alCambiarAsistencia: _clase.cargarCursoActual);
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    _clase.dispose();
    _bandeja?.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await _clase.cargar();
    await _bandeja?.cargar();
    await _cargarEvidenciasPendientes();
    final alerts = await widget.repository.getAlertasDesercion(sedeId: _sedeIdMockup);
    final roles = await widget.repository.getRolesTutora();
    final asigs = await widget.repository.getAsignacionesSemanales(semanaNumero: _semanaActual);
    await _cargarMiAsistencia();

    if (!mounted) return;
    setState(() {
      _alertas = alerts;
      _rolesConfig = roles;
      _asignaciones = asigs;
      _cargando = false;
    });
  }

  Future<void> _elegirCurso(String instanciaId) async {
    await _clase.elegirCurso(instanciaId);
    await _cargarMiAsistencia();
    if (!mounted) return;
    setState(() {});
  }

  // Recarga deslizando hacia abajo: descarga los datos de la nube (~1 s simulado) mostrando el esqueleto
  Future<void> _recargar() async {
    setState(() => _recargando = true);
    await widget.clase.sincronizar();
    await _cargarDatos();
    if (!mounted) return;
    setState(() => _recargando = false);
  }

  Future<void> _cargarEvidenciasPendientes() async {
    try {
      _evidenciasPendientes = await widget.evidencias?.pendientes() ?? const [];
    } catch (_) {
      // Sin conexión se mantiene la lista anterior
    }
  }

  Future<void> _abrirFotos() async {
    await _abrirPantallaClase('Fotos', FotosClaseView(controller: _clase, evidencias: widget.evidencias));
    // Una foto nueva saca la clase de las pendientes (US-20 escenario 2)
    await _cargarEvidenciasPendientes();
    if (!mounted) return;
    setState(() {});
  }

  void _ingresarJustificativo() {
    final bandeja = _bandeja;
    if (bandeja == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los justificativos necesitan la conexión con la base de datos.')),
      );
      return;
    }
    mostrarModalRegistrarJustificativo(context, bandeja, _clase);
  }

  List<AlertaDesercion> get _alertasActivas =>
      _alertas.where((a) => a.estado == 'activa').toList();

  // Carga mi registro individual como tutora: asistencia y rol por clase (US-33)
  Future<void> _cargarMiAsistencia() async {
    try {
      _miHistorial = await cargarHistorialTutora(
        clase: widget.clase,
        instanciaId: _clase.curso?.id,
        tutoraId: widget.sesion.perfilId,
        sesiones: _clase.sesiones,
        rolDeSemana: rolesDelMockup(widget.repository, widget.tutoraIdRoles),
      );
    } catch (_) {
      // Sin conexión se mantiene el historial anterior
    }
  }

  Iterable<ClaseTutoraResumen> get _misClasesRegistradas =>
      _miHistorial.where((c) => c.estado != EstadoAsistencia.pendiente);

  Future<void> _abrirAsistenciaTutoras() async {
    await _abrirPantallaClase(
      'Asistencia de Tutoras',
      AsistenciaTutorasView(controller: _clase),
    );
    // Refresca mi asistencia y mis roles al volver
    await _cargarMiAsistencia();
    if (!mounted) return;
    setState(() {});
  }

  // Semana de la clase en curso (una sesión por semana)
  int get _semanaActual => _clase.sesionActual?.numeroSesion ?? 1;

  RolTutorConfig? get _miRolSemana {
    final asignacion = _asignaciones.where((a) => a.tutoraId == widget.tutoraIdRoles).firstOrNull;
    return _rolesConfig.where((r) => r.codigo == asignacion?.rolCodigo).firstOrNull;
  }

  Future<void> _abrirRolesSemanales() async {
    await _abrirPantallaClase(
      'Roles de Tutoras',
      RolesSemanalesView(
        repository: widget.repository,
        sedeId: _sedeIdMockup,
        semanaInicial: _semanaActual,
        totalSemanas: _clase.sesiones.isEmpty ? 10 : _clase.sesiones.length,
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
            onTap: _ingresarJustificativo,
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
            onTap: _abrirFotos,
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

  // Pantalla principal: resumen de la sede + justificativos + evidencias pendientes + alertas activas
  Widget _buildPantallaPrincipal(bool isDark) {
    final bandeja = _bandeja;
    final alertas = _alertasActivas;
    final curso = _clase.curso;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        if (_clase.error != null) ...[
          AvisoErrorClase(mensaje: _clase.error!),
          const SizedBox(height: 14),
        ],
        if (_clase.cursos.length > 1) ...[
          SelectorCursoClase(cursos: _clase.cursos, cursoId: curso?.id, onCambiar: _elegirCurso),
          const SizedBox(height: 10),
        ],

        // Planificación de la clase de hoy, curso y sede
        BannerBienvenidaTutora(
          nombre: widget.sesion.nombres,
          sesion: _clase.sesionActual,
          cursoNombre: curso?.nombre,
          sedeNombre: curso?.sedeNombre ?? widget.sesion.sedePrincipal?.nombre,
        ),
        const SizedBox(height: 14),

        // Resumen rápido de la clase y la sede
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _clase,
                builder: (context, _) => TarjetaPresentesClase(
                  controller: _clase,
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
        if (curso != null && (curso.classroomUrl != null || curso.juezVirtualUrl != null)) ...[
          NinasProRecursosCursoCard(curso: curso),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),

        // Bandeja de justificativos con filtros por estado (US-37)
        if (bandeja == null)
          _buildEstadoVacio(
            isDark,
            icon: Icons.cloud_off_rounded,
            titulo: 'Justificativos sin conexión',
            mensaje: 'La bandeja de justificativos necesita la conexión con la base de datos.',
          )
        else ...[
          ListenableBuilder(
            listenable: bandeja,
            builder: (context, _) => _buildEncabezadoSeccion(
              isDark,
              icon: Icons.assignment_turned_in_outlined,
              titulo: 'Justificativos',
              cantidad: bandeja.cantidad(EstadoJustificativo.pendiente),
              color: NinasProColors.warning700,
            ),
          ),
          const SizedBox(height: 10),
          SeccionJustificativos(controller: bandeja),
        ],
        const SizedBox(height: 20),

        // Clases realizadas hace más de 48 horas sin foto (US-20)
        _buildEncabezadoSeccion(
          isDark,
          icon: Icons.no_photography_outlined,
          titulo: 'Evidencias pendientes (> 48 h)',
          cantidad: _evidenciasPendientes.length,
          color: NinasProColors.accent700,
        ),
        const SizedBox(height: 10),
        if (_evidenciasPendientes.isEmpty)
          _buildEstadoVacio(
            isDark,
            icon: Icons.photo_library_rounded,
            titulo: 'Fotos al día',
            mensaje: 'Todas las clases realizadas tienen su foto de evidencia.',
          )
        else
          ..._evidenciasPendientes.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTarjetaEvidenciaPendiente(isDark, e),
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

  // Clase sin foto de evidencia tras 48 horas, con sus tutoras para recordarles (US-20)
  Widget _buildTarjetaEvidenciaPendiente(bool isDark, EvidenciaPendiente e) {
    final secundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NinasProColors.accent500, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.cursoNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Text(
                  e.demora,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NinasProColors.accent900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [e.claseEtiqueta, e.tema, e.sedeNombre].whereType<String>().join(' · '),
              style: TextStyle(fontSize: 11.5, color: secundario),
            ),
            if (e.tutoras != null) ...[
              const SizedBox(height: 6),
              Text(
                'Recordar a: ${e.tutoras}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
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
