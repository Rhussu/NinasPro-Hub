import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../repositories/justificativos_repository.dart';
import '../../repositories/portal_repository.dart';
import '../../widgets/ninaspro_mascot.dart';
import '../../widgets/ninaspro_planificacion_hoy.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';
import '../ajustes/accesos_rol.dart';
import '../tutora/inicio_tutora_widgets.dart' show abrirPantallaSecundaria;
import 'justificativos_alumna.dart';

/// Portal Móvil de la Alumna en NiñasPro Hub.
///
/// Cubre:
/// - US-25: Dashboard de asistencia % y progreso académico vs. meta mínima (80% o 70% justificada).
/// - US-26: Cronograma de clases de sábados, recursos del curso (Classroom y Juez Virtual) y
///   los recursos de cada clase con enlaces HTTPS.
/// - US-27: La base arma el portal de la alumna autenticada; nunca recibe el id de otra.
/// - US-40 E4: Sin avisos de riesgo: solo su porcentaje y mensajes de motivación.
/// - US-29: Historial acumulado de podios Kahoot (conteo de 1°, 2° y 3° lugar).
/// - US-35: Justificación de inasistencia eligiendo la clase y explicándola en texto, y
///   la lista de sus justificativos con la observación de Gestión (con [JustificativosRepository]).
/// - Recuperación de clases justificadas mediante ejercicios resueltos (25 ej. = +1 clase, 50 ej. = +2 clases).
/// - Registra en [accesos] las mismas acciones de sus tarjetas para que Ajustes llegue a todo.
class PortalAlumnaScreen extends StatefulWidget {
  /// Asistencia, cronograma, recursos, ejercicios y podios de la alumna autenticada
  final PortalRepository repository;

  /// Justificativos reales de la alumna autenticada (US-35)
  final JustificativosRepository? justificativos;

  /// Entradas de Ajustes de la alumna
  final RegistroAccesos? accesos;

  const PortalAlumnaScreen({
    super.key,
    required this.repository,
    this.justificativos,
    this.accesos,
  });

  @override
  State<PortalAlumnaScreen> createState() => _PortalAlumnaScreenState();
}

class _PortalAlumnaScreenState extends State<PortalAlumnaScreen> {
  static const _ejerciciosPorClase = 25;
  static const _maxEjercicios = 50; // 2 clases compensables como máximo
  static const _colorBronce = Color(0xFFCD7F32);

  bool _cargando = true;
  bool _recargando = false;
  String? _error;
  PortalAlumna? _portal;

  PortalAlumna get _data => _portal!;

  @override
  void initState() {
    super.initState();
    widget.accesos?.registrar(_construirAccesos);
    _cargarDatos();
  }

  @override
  void dispose() {
    widget.accesos?.retirar(_construirAccesos);
    super.dispose();
  }

  // Cada cambio del portal también actualiza sus entradas en Ajustes
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.accesos?.avisar();
  }

  Future<void> _abrirMisJustificativos(JustificativosRepository repo) => abrirPantallaSecundaria(
    context,
    'Mis justificativos',
    ListView(padding: const EdgeInsets.all(16), children: [MisJustificativosCard(repository: repo)]),
  );

  Future<void> _abrirMiAsistencia() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return abrirPantallaSecundaria(
      context,
      'Mi asistencia',
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [_buildTarjetaAsistencia(isDark), const SizedBox(height: 20), ..._buildCronograma(isDark)],
      ),
    );
  }

  /// Entradas de Ajustes: las mismas acciones de las tarjetas y el botón del portal
  List<SeccionAccesos> _construirAccesos() {
    final portal = _portal;
    final justificativos = widget.justificativos;
    const sinPortal = 'Necesita tu portal: revisa tu conexión y desliza hacia abajo en el inicio.';
    final curso = portal?.curso;
    return [
      SeccionAccesos('Mi asistencia', [
        AccesoRol(
          icono: Icons.event_note_rounded,
          titulo: 'Asistencia y cronograma',
          subtitulo: portal?.asistencia.porcentaje == null
              ? 'El estado de cada clase y sus recursos'
              : '${portal!.asistencia.porcentaje!.toStringAsFixed(1)}% · el estado de cada clase y sus recursos',
          abrir: portal == null ? null : _abrirMiAsistencia,
          sinConexion: sinPortal,
        ),
        AccesoRol(
          icono: Icons.edit_calendar_rounded,
          titulo: 'Justificar falta',
          subtitulo: 'Elige la clase y explica el motivo',
          abrir: justificativos == null ? null : _justificarFalta,
        ),
        AccesoRol(
          icono: Icons.assignment_turned_in_rounded,
          titulo: 'Mis justificativos',
          subtitulo: 'Su estado y la observación de Gestión',
          abrir: justificativos == null ? null : () => _abrirMisJustificativos(justificativos),
        ),
      ]),
      SeccionAccesos('Mi progreso', [
        AccesoRol(
          icono: Icons.code_rounded,
          titulo: 'Mis ejercicios',
          subtitulo: portal == null ? null : '${portal.ejercicios} resueltos · recuperan clases justificadas',
          abrir: portal == null ? null : () => _mostrarDetalleEjercicios(context),
          sinConexion: sinPortal,
        ),
        AccesoRol(
          icono: Icons.emoji_events_rounded,
          titulo: 'Mis podios Kahoot',
          subtitulo: portal == null
              ? null
              : '🥇 ${portal.podiosPrimero} · 🥈 ${portal.podiosSegundo} · 🥉 ${portal.podiosTercero}',
          abrir: portal == null ? null : () => _mostrarDetallePodios(context),
          sinConexion: sinPortal,
        ),
      ]),
      if (curso != null && (curso.classroomUrl != null || curso.juezVirtualUrl != null))
        SeccionAccesos('Mi curso', [
          AccesoRol(
            icono: Icons.link_rounded,
            titulo: 'Recursos del curso',
            subtitulo: 'Classroom y Juez Virtual',
            abrir: () => abrirPantallaSecundaria(
              context,
              'Recursos del curso',
              ListView(padding: const EdgeInsets.all(16), children: [NinasProRecursosCursoCard(curso: curso)]),
            ),
          ),
        ]),
    ];
  }

  Future<void> _cargarDatos() async {
    try {
      final portal = await widget.repository.portal();
      if (!mounted) return;
      setState(() {
        _portal = portal;
        _error = null;
        _cargando = false;
      });
    } on PortalDenegado catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu portal. Revisa tu conexión y desliza hacia abajo para reintentar.';
        _cargando = false;
      });
    }
  }

  // Recarga deslizando hacia abajo mostrando el esqueleto
  Future<void> _recargar() async {
    setState(() => _recargando = true);
    await _cargarDatos();
    if (!mounted) return;
    setState(() => _recargando = false);
  }

  // Al enviar uno nuevo se recarga la lista de "Mis Justificativos"
  int _versionJustificativos = 0;

  // Justificar una inasistencia eligiendo la clase (US-35)
  Future<void> _justificarFalta() async {
    final repo = widget.justificativos;
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los justificativos necesitan la conexión con la base de datos.')),
      );
      return;
    }
    if (await mostrarModalJustificarFalta(context, repo) && mounted) {
      setState(() => _versionJustificativos++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Esqueleto de la pantalla mientras carga o se recarga deslizando hacia abajo
    if (_cargando || _recargando) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _recargar,
          child: const NinasProSkeletonInicio(filas: NinasProSkeletonInicio.filasAlumna),
        ),
      );
    }

    if (_portal == null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const NinasProMascot(size: 96),
              const SizedBox(height: 16),
              Text(_error ?? 'No pudimos cargar tu portal.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final curso = _data.curso;

    // Referencia para escalar las barras del podio
    final maxPodios = [
      _data.podiosPrimero,
      _data.podiosSegundo,
      _data.podiosTercero,
    ].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NinasProColors.brandPink,
        foregroundColor: NinasProColors.neutral900,
        onPressed: _justificarFalta,
        icon: const Icon(Icons.edit_calendar_rounded, size: 20),
        label: const Text(
          'Justificar Falta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // Recargar deslizando hacia abajo desde el inicio de la lista
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            // Banner de bienvenida con gatita astronauta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [NinasProColors.primary900, NinasProColors.accent900]
                      : [NinasProColors.primary100, NinasProColors.accent100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola, ${_data.nombres.split(' ').first}! 💜',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? NinasProColors.white : NinasProColors.primary900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              curso?.nombre ?? 'Aún no tienes un curso asignado',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? NinasProColors.primary300 : NinasProColors.primary700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              curso?.sedeNombre ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const NinasProMascot(size: 72, showStars: true),
                    ],
                  ),
                  // Lo que toca hoy según la planificación del curso
                  if (_data.sesionHoy != null) ...[
                    const SizedBox(height: 12),
                    NinasProPlanificacionHoy(sesion: _data.sesionHoy!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recursos del curso: un único Classroom y Juez Virtual para todo el curso (US-26)
            if (curso != null && (curso.classroomUrl != null || curso.juezVirtualUrl != null)) ...[
              NinasProRecursosCursoCard(curso: curso),
              const SizedBox(height: 16),
            ],

            // Tarjeta de progreso de asistencia (US-25 & US-35)
            _buildTarjetaAsistencia(isDark),
            const SizedBox(height: 16),

            if (widget.justificativos != null) ...[
              MisJustificativosCard(
                key: ValueKey(_versionJustificativos),
                repository: widget.justificativos!,
              ),
              const SizedBox(height: 16),
            ],

            // Recuperación por Ejercicios + Podios Kahoot (US-29), lado a lado
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildTarjetaCompacta(
                      isDark: isDark,
                      icono: Icons.code_rounded,
                      colorIcono: NinasProColors.brandPink,
                      onTap: () => _mostrarDetalleEjercicios(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: (_data.ejercicios / _maxEjercicios).clamp(0.0, 1.0),
                                  strokeWidth: 6,
                                  backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                                  valueColor: const AlwaysStoppedAnimation(NinasProColors.brandPink),
                                ),
                                Center(
                                  child: Text(
                                    '${_data.ejercicios}',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                      color: isDark ? NinasProColors.white : NinasProColors.neutral900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInsigniaClases(
                            clases: _data.hitosEjercicios,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTarjetaCompacta(
                      isDark: isDark,
                      icono: Icons.emoji_events_rounded,
                      colorIcono: NinasProColors.warning700,
                      onTap: () => _mostrarDetallePodios(context),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildEscalonPodio(
                              medalla: '🥈',
                              veces: _data.podiosSegundo,
                              maxVeces: maxPodios,
                              color: NinasProColors.neutral300,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildEscalonPodio(
                              medalla: '🥇',
                              veces: _data.podiosPrimero,
                              maxVeces: maxPodios,
                              color: NinasProColors.warning500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildEscalonPodio(
                              medalla: '🥉',
                              veces: _data.podiosTercero,
                              maxVeces: maxPodios,
                              color: _colorBronce,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cronograma de Sábados (US-25)
            ..._buildCronograma(isDark),
          ],
        ),
      ),
    );
  }

  // Asistencia acumulada contra la meta (US-25, US-35): en el inicio y en "Mi asistencia"
  Widget _buildTarjetaAsistencia(bool isDark) {
    final asistencia = _data.asistencia;
    final asistenciaPorc = asistencia.porcentaje ?? 0;
    final umbral = asistencia.umbral;
    final aprueba = asistencia.cumpleMeta;

    return Card(
      elevation: 0,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  'Mi Asistencia Acumulada',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: aprueba ? NinasProColors.success100 : NinasProColors.warning100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    aprueba ? 'Cumple meta para certificar' : 'Meta: $umbral%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: aprueba ? NinasProColors.success900 : NinasProColors.warning900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  asistencia.porcentaje == null ? '—' : '${asistenciaPorc.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: NinasProColors.brandPink,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (asistenciaPorc / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: isDark
                              ? NinasProColors.dark700
                              : NinasProColors.neutral100,
                          valueColor: AlwaysStoppedAnimation(
                            aprueba ? NinasProColors.success500 : NinasProColors.warning500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${asistencia.asistidas} de ${asistencia.realizadas} clases asistidas '
                        '(Meta: $umbral% para certificar)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!aprueba || asistencia.recuperadas > 0) ...[
              const SizedBox(height: 10),
              _buildMensajeMeta(asistencia),
            ],
            if (asistencia.umbralReducido) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NinasProColors.primary700.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: NinasProColors.brandPink),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Meta reducida al $umbral% gracias a que cuentas con al menos 1 justificativo aprobado.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Cronograma de clases con el estado de cada una y sus recursos (US-25, US-26 E2)
  List<Widget> _buildCronograma(bool isDark) {
    return [
      const Text(
        'Cronograma de Clases (Sábados)',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),

      if (_data.sesiones.isEmpty)
        const Text('Tu cronograma aparecerá cuando tengas un curso asignado.'),
      ..._data.sesiones.map((sesion) {
        final estado = _data.estadoDe(sesion);
        final tono = context.statusColors.asistencia(estado);

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${sesion.numeroSesion}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sesion.tema,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${fechaCorta(sesion.fecha)}'
                            '${sesion.suspendida ? ' · Suspendida${sesion.motivoSuspension == null ? '' : ': ${sesion.motivoSuspension}'}' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!sesion.suspendida)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: tono.decoration,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(estado.icon, size: 14, color: tono.foreground),
                            const SizedBox(width: 4),
                            Text(estado.label, style: tono.textStyle(fontSize: 11.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                // Recursos de la clase en una hoja inferior (US-26 E2)
                if (sesion.recursos.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _mostrarRecursosSesion(context, sesion),
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text('Ver recursos (${sesion.recursos.length})'),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  // Cuántas clases le faltan para la meta, o la clase recuperada con ejercicios (US-25 E2, E3).
  // Siempre en tono de motivación: el portal no muestra avisos de riesgo (US-40 E4).
  Widget _buildMensajeMeta(AsistenciaPortal a) {
    final String texto;
    if (a.cumpleMeta) {
      texto = a.recuperadas == 1
          ? '¡Tus ejercicios recuperaron 1 clase justificada! 🎉'
          : '¡Tus ejercicios recuperaron ${a.recuperadas} clases justificadas! 🎉';
    } else if (a.clasesNecesarias == 0) {
      texto = '¡Vas muy bien! Sigue asistiendo para llegar a la meta.';
    } else if (a.clasesNecesarias <= a.restantes) {
      final clases = a.clasesNecesarias == 1 ? '1 clase más' : '${a.clasesNecesarias} clases más';
      texto = '¡Tú puedes! Asiste a $clases de las ${a.restantes} que quedan para llegar a la meta. 💪';
    } else {
      texto = '¡Cada clase cuenta! Asiste a las que quedan y conversa con tu tutora '
          'sobre cómo recuperar clases con ejercicios. 💪';
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NinasProColors.primary700.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: NinasProColors.brandPink),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  static IconData _iconoRecurso(String tipo) => switch (tipo) {
        'slides' => Icons.slideshow_rounded,
        'codigo' => Icons.code_rounded,
        'guia' => Icons.picture_as_pdf_rounded,
        'video' => Icons.ondemand_video_rounded,
        _ => Icons.link_rounded,
      };

  static String _categoriaRecurso(String tipo) => switch (tipo) {
        'slides' => 'Diapositivas',
        'codigo' => 'Código interactivo',
        'guia' => 'Guía de problemas',
        'video' => 'Grabación de apoyo',
        'ejercicios' => 'Ejercicios',
        _ => 'Recurso',
      };

  // Recursos de una clase con su insignia HTTPS; se abren en una pestaña externa (US-26 E2, E3)
  void _mostrarRecursosSesion(BuildContext context, SesionClase sesion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManijaSheet(isDark),
              const SizedBox(height: 16),
              _buildEncabezadoSheet(
                icono: Icons.folder_open_rounded,
                colorIcono: NinasProColors.brandPink,
                titulo: 'Recursos de la clase #${sesion.numeroSesion}',
                subtitulo: sesion.tema,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              for (final recurso in sesion.recursos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconoRecurso(recurso.tipo), color: NinasProColors.brandPink),
                  title: Text(recurso.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(_categoriaRecurso(recurso.tipo), style: const TextStyle(fontSize: 11.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (recurso.esSeguraHttps)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NinasProColors.success100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: NinasProColors.success900),
                              SizedBox(width: 2),
                              Text('HTTPS',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NinasProColors.success900)),
                            ],
                          ),
                        ),
                      const Icon(Icons.open_in_new_rounded, size: 18),
                    ],
                  ),
                  onTap: () => _abrirRecurso(ctx, recurso),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirRecurso(BuildContext context, RecursoEducativo recurso) async {
    final abierto = recurso.esSeguraHttps &&
        await launchUrl(Uri.parse(recurso.url), mode: LaunchMode.externalApplication);
    if (abierto || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: NinasProColors.error700, content: Text('No se pudo abrir el enlace.')),
    );
  }

  // Tarjeta compacta (media pantalla) que abre un bottomsheet con el detalle
  Widget _buildTarjetaCompacta({
    required bool isDark,
    required IconData icono,
    required Color colorIcono,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icono, color: colorIcono, size: 18),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: NinasProColors.neutral500),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  // Insignia dorada +N: brilla si la clase ya fue ganada, bloqueada si aún no
  Widget _buildInsigniaClases({
    required int clases,
    required bool isDark,
    bool compacta = false,
  }) {
    final ganada = clases > 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacta ? 8 : 12, vertical: compacta ? 4 : 6),
      decoration: BoxDecoration(
        gradient: ganada
            ? const LinearGradient(
                colors: [NinasProColors.warning100, NinasProColors.warning300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: ganada ? null : (isDark ? NinasProColors.dark700 : NinasProColors.neutral50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ganada
              ? NinasProColors.warning500
              : (isDark ? NinasProColors.dark600 : NinasProColors.neutral300),
          width: 1.5,
        ),
        boxShadow: ganada
            ? [
                BoxShadow(
                  color: NinasProColors.warning500.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ganada ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
            size: compacta ? 12 : 14,
            color: ganada ? NinasProColors.warning700 : NinasProColors.neutral500,
          ),
          const SizedBox(width: 4),
          Text(
            ganada ? '+$clases' : '+1',
            style: TextStyle(
              fontSize: compacta ? 12 : 14,
              fontWeight: FontWeight.w900,
              color: ganada ? NinasProColors.warning900 : NinasProColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  // Escalón del podio: medalla arriba, cantidad de veces dentro de la barra.
  // La altura es proporcional a las veces, con un mínimo para que el número siempre se lea.
  Widget _buildEscalonPodio({
    required String medalla,
    required int veces,
    required int maxVeces,
    required Color color,
  }) {
    const alturaMin = 24.0;
    const alturaMax = 64.0;
    final altura = maxVeces == 0
        ? alturaMin
        : alturaMin + (alturaMax - alturaMin) * (veces / maxVeces);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medalla, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Container(
          height: altura,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            '$veces',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: NinasProColors.neutral900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManijaSheet(bool isDark) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEncabezadoSheet({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: NinasProColors.primary700.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: colorIcono, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Detalle de recuperación de clases por ejercicios resueltos
  void _mostrarDetalleEjercicios(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _data.ejercicios;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManijaSheet(isDark),
              const SizedBox(height: 16),
              _buildEncabezadoSheet(
                icono: Icons.code_rounded,
                colorIcono: NinasProColors.brandPink,
                titulo: 'Recuperación por Ejercicios',
                subtitulo: 'Cada $_ejerciciosPorClase ejercicios compensas 1 inasistencia justificada',
                isDark: isDark,
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: NinasProColors.brandPink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        'ejercicios resueltos en clase y plataforma',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (total / _maxEjercicios).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                  valueColor: const AlwaysStoppedAnimation(NinasProColors.brandPink),
                ),
              ),
              const SizedBox(height: 16),
              ...[1, 2].map((clases) {
                final meta = clases * _ejerciciosPorClase;
                final lograda = total >= meta;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: _buildInsigniaClases(
                      clases: lograda ? clases : 0,
                      isDark: isDark,
                      compacta: true,
                    ),
                    title: Text(
                      '$clases ${clases == 1 ? 'clase recuperada' : 'clases recuperadas'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    subtitle: Text(
                      lograda ? '$meta ejercicios completados' : 'Te faltan ${meta - total} ejercicios',
                      style: const TextStyle(fontSize: 11.5, color: NinasProColors.neutral500),
                    ),
                    trailing: Icon(
                      lograda ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: lograda ? NinasProColors.success500 : NinasProColors.neutral300,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              const Text(
                'Máximo 2 clases compensables.',
                style: TextStyle(fontSize: 11, color: NinasProColors.neutral500),
              ),
            ],
          ),
        );
      },
    );
  }

  // Detalle del historial de podios Kahoot (US-29)
  void _mostrarDetallePodios(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final podios = [
      ('🥇', '1° Lugar', _data.podiosPrimero),
      ('🥈', '2° Lugar', _data.podiosSegundo),
      ('🥉', '3° Lugar', _data.podiosTercero),
    ];
    final total = podios.fold<int>(0, (suma, p) => suma + p.$3);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManijaSheet(isDark),
              const SizedBox(height: 16),
              _buildEncabezadoSheet(
                icono: Icons.emoji_events_rounded,
                colorIcono: NinasProColors.warning700,
                titulo: 'Historial de Podios Kahoot',
                subtitulo: '$total ${total == 1 ? 'podio acumulado' : 'podios acumulados'}',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              ...podios.map((p) {
                final (medalla, posicion, veces) = p;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Text(medalla, style: const TextStyle(fontSize: 26)),
                    title: Text(
                      posicion,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    trailing: Text(
                      '$veces ${veces == 1 ? 'vez' : 'veces'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? NinasProColors.white : NinasProColors.neutral900,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
