import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../../widgets/ninaspro_speed_dial.dart';
import '../../widgets/ninaspro_stat_card.dart';
import 'clase_sesion_controller.dart';
import 'clase_sesion_views.dart';
import 'inicio_tutora_widgets.dart';

/// Pantalla móvil de inicio de la Tutora en NiñasPro Hub.
///
/// Es la misma base que la pantalla de Gestión, sin las funciones exclusivas de gestión
/// (justificativos, alertas, asistencia y roles de otras tutoras):
/// - Resumen: alumnas presentes, mi asistencia como tutora y mi rol de la semana (solo lectura).
/// - Recursos del curso (Classroom y Juez Virtual).
/// - Speed Dial con la operación de la clase: US-13 asistencia, US-28 ejercicios,
///   US-18/US-19 fotos y US-29 podio Kahoot (vistas en [clase_sesion_views.dart]).
class TutoraMobileScreen extends StatefulWidget {
  final HubRepository repository;

  /// Tutora que usa la app
  final String tutoraId;

  const TutoraMobileScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-3', // Daniela Valenzuela Castro por defecto
  });

  @override
  State<TutoraMobileScreen> createState() => _TutoraMobileScreenState();
}

class _TutoraMobileScreenState extends State<TutoraMobileScreen> {
  bool _cargando = true;
  bool _recargando = false;

  Tutora? _tutora;
  Curso? _curso;
  List<ClaseTutoraResumen> _historial = [];

  // Curso de la sede (mockup: un único curso por sede)
  static const _cursoId = 'curso-pcb-stgo';

  // Clase en curso, compartida con las pantallas de Gestión
  late final ClaseSesionController _clase;

  @override
  void initState() {
    super.initState();
    _clase = ClaseSesionController(repository: widget.repository, cursoId: _cursoId);
    _cargarDatos();
  }

  @override
  void dispose() {
    _clase.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final tutoras = await widget.repository.getTutoras();
    final cursos = await widget.repository.getCursos();
    final roles = await widget.repository.getRolesTutora();
    await _clase.cargar();
    final historial = await cargarHistorialTutora(
      repository: widget.repository,
      tutoraId: widget.tutoraId,
      sesiones: _clase.sesiones,
      roles: roles,
    );

    if (!mounted) return;
    setState(() {
      _tutora = tutoras.where((t) => t.id == widget.tutoraId).firstOrNull;
      _curso = cursos.where((c) => c.id == _cursoId).firstOrNull;
      _historial = historial;
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

  ClaseTutoraResumen? get _claseActual =>
      _historial.where((c) => c.sesion.id == _clase.sesionId).firstOrNull;

  Iterable<ClaseTutoraResumen> get _clasesRegistradas =>
      _historial.where((c) => c.estado != EstadoAsistencia.pendiente);

  Future<void> _abrirPantallaClase(String titulo, Widget vista) =>
      abrirPantallaSecundaria(context, titulo, vista);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Deslizar hacia abajo recarga; mientras tanto se muestra el esqueleto de la pantalla
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: _cargando || _recargando ? const NinasProSkeletonInicio() : _buildPantallaPrincipal(),
      ),
      // Speed Dial: el primer elemento de la lista queda arriba y el último junto al rayito
      floatingActionButton: NinasProSpeedDial(
        acciones: [
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

  // Pantalla principal: resumen de la clase, mi asistencia, mi rol y recursos del curso
  Widget _buildPantallaPrincipal() {
    final miRol = _claseActual?.rol;
    final registradas = _clasesRegistradas;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        // Planificación de la clase de hoy, curso y sede
        BannerBienvenidaTutora(
          nombre: _tutora?.nombre,
          sesion: _clase.sesionActual,
          cursoNombre: _curso?.nombre,
          sedeNombre: _tutora?.sedeNombre,
        ),
        const SizedBox(height: 14),

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
              // Abre mi registro individual de clases y roles
              child: TarjetaMiAsistencia(
                asistidas: registradas.where((c) => c.estado == EstadoAsistencia.presente).length,
                registradas: registradas.length,
                onTap: () => _abrirPantallaClase(
                  'Mi Asistencia',
                  MiHistorialTutoraView(historial: _historial, sesionActualId: _clase.sesionId),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Solo lectura: los roles los asigna el Equipo de Gestión
        TarjetaMiRol(
          rol: miRol,
          semana: _clase.sesionActual?.numeroSesion ?? 1,
          mensajeSinRol: 'El Equipo de Gestión aún no te asigna un rol esta semana.',
        ),
        const SizedBox(height: 10),

        // Recursos del curso (Classroom y Juez Virtual, US-26)
        if (_curso != null && (_curso!.classroomUrl != null || _curso!.juezVirtualUrl != null)) ...[
          NinasProRecursosCursoCard(curso: _curso!),
          const SizedBox(height: 20),
        ],

        const TarjetaConsejo(
          texto: 'Tip: toca ⚡ para pasar lista, registrar ejercicios, subir la foto de la clase '
              'o guardar el podio Kahoot.',
        ),
      ],
    );
  }
}
