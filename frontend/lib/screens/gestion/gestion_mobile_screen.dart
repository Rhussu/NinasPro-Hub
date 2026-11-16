import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/alertas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/evidencias_repository.dart';
import '../../repositories/justificativos_repository.dart';
import '../../repositories/roles_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../../widgets/ninaspro_speed_dial.dart';
import '../ajustes/accesos_rol.dart';
import '../calendario/calendario_screen.dart';
import '../directorio/directorio_voluntariado_view.dart';
import '../tutora/accesos_clase.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/clase_sesion_views.dart';
import '../tutora/fotos_clase_view.dart';
import '../tutora/inicio_tutora_widgets.dart';
import 'alertas_desercion_view.dart';
import 'evidencias_pendientes_view.dart';
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
/// - US-39/US-40: Alertas de deserción de la sede y registro del contacto con la apoderada.
/// - Registra en [accesos] lo mismo que sus tarjetas y su Speed Dial, más el
///   calendario y el voluntariado de la sede, para que Ajustes llegue a todo.
class GestionMobileScreen extends StatefulWidget {
  /// La clase real: cursos de la sede, pase de lista de alumnas y de tutoras
  final ClaseRepository clase;

  /// Integrante del Equipo de Gestión autenticada
  final SesionUsuario sesion;

  /// Bandeja de justificativos de la sede (US-16, US-37)
  final JustificativosRepository? justificativos;

  /// Fotos de evidencia y clases sin foto tras 48 horas (US-18..US-20)
  final EvidenciasRepository? evidencias;

  /// Roles de cada clase del curso y su cumplimiento (US-43, US-44)
  final RolesRepository? roles;

  /// Alertas de deserción de la sede (US-39, US-40)
  final AlertasRepository? alertas;

  /// Calendario de clases de la sede (US-03)
  final CatalogoRepository? catalogo;

  /// Voluntariado de la sede en solo lectura (US-32)
  final VoluntariadoRepository? voluntariado;

  /// Entradas de Ajustes de Gestión
  final RegistroAccesos? accesos;

  const GestionMobileScreen({
    super.key,
    required this.clase,
    required this.sesion,
    this.justificativos,
    this.evidencias,
    this.roles,
    this.alertas,
    this.catalogo,
    this.voluntariado,
    this.accesos,
  });

  @override
  State<GestionMobileScreen> createState() => _GestionMobileScreenState();
}

class _GestionMobileScreenState extends State<GestionMobileScreen> {
  bool _cargando = true;
  bool _recargando = false;

  /// Alertas de deserción de la sede (US-39)
  List<AlertaDesercionDetalle> _alertas = const [];

  /// Bandeja de justificativos; null sin conexión con la base
  BandejaJustificativosController? _bandeja;

  /// Clases realizadas hace más de 48 horas sin foto (US-20)
  List<EvidenciaPendiente> _evidenciasPendientes = const [];

  // Mi registro como tutora: asistencia y rol de cada clase del curso
  List<ClaseTutoraResumen> _miHistorial = [];

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
    widget.accesos?.registrar(_construirAccesos);
    _cargarDatos();
  }

  @override
  void dispose() {
    widget.accesos?.retirar(_construirAccesos);
    _clase.dispose();
    _bandeja?.dispose();
    super.dispose();
  }

  // Cada cambio de la pantalla también actualiza sus entradas en Ajustes
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.accesos?.avisar();
  }

  Future<void> _cargarDatos() async {
    await _clase.cargar();
    await _bandeja?.cargar();
    await _cargarEvidenciasPendientes();
    await _cargarAlertas();
    await _cargarMiAsistencia();

    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _cargarAlertas() async {
    try {
      _alertas = await widget.alertas?.alertas() ?? const [];
    } catch (_) {
      // Sin conexión se mantienen las alertas anteriores
    }
  }

  Future<void> _refrescarAlertas() async {
    await _cargarAlertas();
    if (mounted) setState(() {});
  }

  Future<void> _registrarContacto(AlertaDesercionDetalle alerta) async {
    final repo = widget.alertas;
    if (repo == null || !await mostrarModalContactoAlerta(context, repo, alerta) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: NinasProColors.success700, content: Text('📞 Contacto registrado.')),
    );
    await _refrescarAlertas();
  }

  Future<void> _abrirAlertas() async {
    final repo = widget.alertas;
    if (repo == null) return;
    await _abrirPantallaClase(
      'Alertas de deserción',
      AlertasDesercionView(repository: repo, alCambiar: _refrescarAlertas),
    );
    await _refrescarAlertas();
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

  List<AlertaDesercionDetalle> get _alertasActivas => _alertas.where((a) => !a.atendida).toList();

  // Carga mi registro individual como tutora: asistencia y rol por clase (US-33)
  Future<void> _cargarMiAsistencia() async {
    try {
      _miHistorial = await cargarHistorialTutora(
        clase: widget.clase,
        instanciaId: _clase.curso?.id,
        tutoraId: widget.sesion.perfilId,
        sesiones: _clase.sesiones,
        roles: widget.roles,
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

  // Próxima clase del curso: la de los roles que se muestran en el inicio (US-44 escenario 1)
  SesionClase? get _claseRoles => claseParaRoles(_clase.sesiones, _clase.hoy());

  List<RolEnClase> get _misRoles =>
      _miHistorial.where((c) => c.sesion.id == _claseRoles?.id).firstOrNull?.roles ?? const [];

  Future<void> _marcarMiRol(RolEnClase rol, bool completada) async {
    final roles = widget.roles;
    if (roles == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await roles.marcarCumplido(rol.tarea.id, completada);
    if (!r.ok) messenger.showSnackBar(SnackBar(backgroundColor: NinasProColors.error700, content: Text(r.error!)));
    await _cargarMiAsistencia();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _abrirRolesSemanales() async {
    final roles = widget.roles;
    if (roles == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los roles necesitan la conexión con la base de datos.')),
      );
      return;
    }
    await _abrirPantallaClase(
      'Roles de Tutoras',
      RolesSemanalesView(controller: _clase, roles: roles, perfilId: widget.sesion.perfilId, editable: true),
    );
    // Refresca "Tus roles" al volver
    await _cargarMiAsistencia();
    if (!mounted) return;
    setState(() {});
  }

  // Abre una pantalla de la clase o de tutoras
  Future<void> _abrirPantallaClase(String titulo, Widget vista) =>
      abrirPantallaSecundaria(context, titulo, vista);

  Future<void> _abrirAsistencia() => _abrirPantallaClase('Asistencia', AsistenciaClaseView(controller: _clase));

  Future<void> _abrirEjercicios() => _abrirPantallaClase('Ejercicios', EjerciciosClaseView(controller: _clase));

  Future<void> _abrirMiAsistencia() => _abrirPantallaClase(
    'Mi Asistencia',
    MiHistorialTutoraView(historial: _miHistorial, sesionActualId: _clase.sesionId),
  );

  // La bandeja completa, la misma de la pantalla principal (US-37)
  Future<void> _abrirJustificativos(BandejaJustificativosController bandeja) async {
    await _abrirPantallaClase(
      'Justificativos',
      BandejaJustificativosView(controller: bandeja, onIngresar: _ingresarJustificativo),
    );
    if (mounted) setState(() {});
  }

  Future<void> _abrirEvidenciasPendientes() async {
    await _cargarEvidenciasPendientes();
    if (!mounted) return;
    await _abrirPantallaClase(
      'Evidencias pendientes (> 48 h)',
      EvidenciasPendientesView(pendientes: _evidenciasPendientes),
    );
  }

  /// Entradas de Ajustes: las mismas acciones de las tarjetas y el Speed Dial
  List<SeccionAccesos> _construirAccesos() {
    final bandeja = _bandeja;
    final catalogo = widget.catalogo;
    final voluntariado = widget.voluntariado;
    final alertas = _alertasActivas.length;
    final pendientes = bandeja?.cantidad(EstadoJustificativo.pendiente) ?? 0;
    final registradas = _misClasesRegistradas;
    return [
      SeccionAccesos(
        'La clase de hoy',
        accesosClaseDeHoy(
          context,
          _clase,
          onElegirCurso: _elegirCurso,
          abrirAsistencia: _abrirAsistencia,
          abrirEjercicios: _abrirEjercicios,
          abrirFotos: _abrirFotos,
        ),
      ),
      SeccionAccesos('Gestión de la sede', [
        AccesoRol(
          icono: Icons.assignment_turned_in_rounded,
          titulo: 'Justificativos',
          subtitulo: pendientes == 1 ? '1 por aprobar · filtros por estado' : '$pendientes por aprobar · filtros por estado',
          abrir: bandeja == null ? null : () => _abrirJustificativos(bandeja),
        ),
        AccesoRol(
          icono: Icons.note_add_rounded,
          titulo: 'Ingresar justificativo',
          subtitulo: 'El aviso de la apoderada: queda aprobado',
          abrir: bandeja == null ? null : _ingresarJustificativo,
        ),
        AccesoRol(
          icono: Icons.notifications_active_rounded,
          titulo: 'Alertas de deserción',
          subtitulo: alertas == 1 ? '1 por contactar' : '$alertas por contactar',
          abrir: widget.alertas == null ? null : _abrirAlertas,
        ),
        AccesoRol(
          icono: Icons.no_photography_rounded,
          titulo: 'Evidencias pendientes (> 48 h)',
          subtitulo: _evidenciasPendientes.isEmpty
              ? 'Fotos al día'
              : '${_evidenciasPendientes.length} clases sin foto',
          abrir: widget.evidencias == null ? null : _abrirEvidenciasPendientes,
        ),
        AccesoRol(
          icono: Icons.groups_rounded,
          titulo: 'Asistencia de tutoras',
          subtitulo: 'El pase de lista del equipo, con su historial',
          abrir: _abrirAsistenciaTutoras,
        ),
        AccesoRol(
          icono: Icons.assignment_ind_rounded,
          titulo: 'Roles de la clase',
          subtitulo: 'Asigna varios por tutora, también los tuyos, y marca su cumplimiento',
          abrir: widget.roles == null ? null : _abrirRolesSemanales,
        ),
        AccesoRol(
          icono: Icons.calendar_month_rounded,
          titulo: 'Calendario de clases',
          subtitulo: 'Suspende sesiones o agrega clases de recuperación',
          abrir: catalogo == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarioScreen(repository: catalogo))),
        ),
        AccesoRol(
          icono: Icons.volunteer_activism_rounded,
          titulo: 'Voluntariado de la sede',
          subtitulo: 'Fichas, adhesión y cursos, en solo lectura',
          abrir: voluntariado == null || catalogo == null
              ? null
              : () => _abrirPantallaClase(
                  'Voluntariado',
                  DirectorioVoluntariadoView(repository: voluntariado, catalogo: catalogo, soloLectura: true),
                ),
        ),
      ]),
      SeccionAccesos('Mi trabajo como tutora', [
        AccesoRol(
          icono: Icons.how_to_reg_rounded,
          titulo: 'Mi asistencia',
          subtitulo: '${registradas.where((c) => c.estado == EstadoAsistencia.presente).length} de '
              '${registradas.length} clases, con tus roles',
          abrir: _abrirMiAsistencia,
        ),
        ?accesoRecursosCurso(context, _clase.curso),
      ]),
    ];
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
            onTap: _abrirEjercicios,
          ),
          AccionRapida(
            icon: Icons.fact_check_rounded,
            tooltip: 'Asistencia',
            backgroundColor: NinasProColors.primary100,
            foregroundColor: NinasProColors.primary900,
            onTap: _abrirAsistencia,
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
                  onTap: _abrirAsistencia,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Abre mi registro individual; la de todas las tutoras está en el Speed Dial
              child: TarjetaMiAsistencia(
                asistidas: _misClasesRegistradas.where((c) => c.estado == EstadoAsistencia.presente).length,
                registradas: _misClasesRegistradas.length,
                onTap: _abrirMiAsistencia,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TarjetaMisRoles(
          roles: _misRoles,
          numeroSesion: _claseRoles?.numeroSesion,
          mensajeSinRol: 'Asígnate uno o varios roles en Roles de Tutoras.',
          onMarcar: widget.roles == null ? null : _marcarMiRol,
          onVerEquipo: _abrirRolesSemanales,
          etiquetaVerEquipo: 'Asignar roles del equipo',
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
                child: TarjetaEvidenciaPendiente(evidencia: e),
              )),
        const SizedBox(height: 20),

        // Alertas de deserción: 3 inasistencias seguidas sin justificar (US-39, US-40)
        if (widget.alertas != null) ...[
          _buildEncabezadoSeccion(
            isDark,
            icon: Icons.notifications_active_outlined,
            titulo: 'Alertas de deserción',
            cantidad: alertas.length,
            color: NinasProColors.warning700,
          ),
          const SizedBox(height: 10),
          if (alertas.isEmpty)
            _buildEstadoVacio(
              isDark,
              icon: Icons.favorite_rounded,
              titulo: 'Sin alertas por atender',
              mensaje: 'Ninguna alumna acumula inasistencias seguidas. ¡Sigan así!',
            )
          else ...[
            const NotaMetodologicaAlertas(),
            const SizedBox(height: 10),
            ...alertas.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TarjetaAlertaDesercion(alerta: a, onRegistrarContacto: () => _registrarContacto(a)),
                )),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _abrirAlertas,
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: Text(alertas.length > 3 ? 'Ver las ${alertas.length} alertas' : 'Ver todas las alertas'),
            ),
          ),
          const SizedBox(height: 20),
        ],

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
}
