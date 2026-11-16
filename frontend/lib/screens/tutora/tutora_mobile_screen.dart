import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../../widgets/ninaspro_speed_dial.dart';
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
  /// Repositorio del mockup: solo para los roles semanales (US-43, se conectan en su PR)
  final HubRepository repository;

  /// La clase real: cursos, pase de lista, participación y podio
  final ClaseRepository clase;

  /// Tutora autenticada
  final SesionUsuario sesion;

  /// Id de la tutora en el mockup, para mostrar su rol semanal mientras tanto
  final String tutoraIdRoles;

  const TutoraMobileScreen({
    super.key,
    required this.repository,
    required this.clase,
    required this.sesion,
    this.tutoraIdRoles = 'tutora-3', // Daniela Valenzuela Castro en el mockup
  });

  @override
  State<TutoraMobileScreen> createState() => _TutoraMobileScreenState();
}

class _TutoraMobileScreenState extends State<TutoraMobileScreen> {
  bool _cargando = true;
  bool _recargando = false;

  List<ClaseTutoraResumen> _historial = [];

  // Clase en curso, compartida con las pantallas de Gestión
  late final ClaseSesionController _clase;

  @override
  void initState() {
    super.initState();
    _clase = ClaseSesionController(repository: widget.clase, tutoraId: widget.sesion.perfilId);
    _cargarDatos();
  }

  @override
  void dispose() {
    _clase.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await _clase.cargar();
    await _cargarHistorial();
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _cargarHistorial() async {
    try {
      _historial = await cargarHistorialTutora(
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

  Future<void> _elegirCurso(String instanciaId) async {
    await _clase.elegirCurso(instanciaId);
    await _cargarHistorial();
    if (!mounted) return;
    setState(() {});
  }

  // Recarga deslizando hacia abajo: sube lo pendiente y descarga los datos de la nube con el esqueleto
  Future<void> _recargar() async {
    setState(() => _recargando = true);
    await widget.clase.sincronizar();
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

        if (curso == null && _clase.error == null) ...[
          const TarjetaConsejo(texto: 'Aún no tienes cursos asignados. El Equipo de Gestión te asigna a un curso de tu sede.'),
          const SizedBox(height: 10),
        ],

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
        if (curso != null && (curso.classroomUrl != null || curso.juezVirtualUrl != null)) ...[
          NinasProRecursosCursoCard(curso: curso),
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
