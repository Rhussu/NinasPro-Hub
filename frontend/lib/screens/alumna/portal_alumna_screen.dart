import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_mascot.dart';
import '../../widgets/ninaspro_planificacion_hoy.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../../widgets/ninaspro_skeleton.dart';

/// Portal Móvil de la Alumna en NiñasPro Hub.
///
/// Cubre:
/// - US-25: Dashboard de asistencia % y progreso académico vs. meta mínima (80% o 70% justificada).
/// - US-26: Cronograma de clases de sábados y recursos del curso (Classroom y Juez Virtual, únicos por curso).
/// - US-29: Historial acumulado de podios Kahoot (conteo de 1°, 2° y 3° lugar).
/// - US-35: Justificación de inasistencia especificando sábado/clase a faltar (sin advertencias médicas).
/// - Recuperación de clases justificadas mediante ejercicios resueltos (25 ej. = +1 clase, 50 ej. = +2 clases).
class PortalAlumnaScreen extends StatefulWidget {
  final HubRepository repository;
  final String alumnaId;

  const PortalAlumnaScreen({
    super.key,
    required this.repository,
    this.alumnaId = 'alumna-1', // Valentina Soto Morales por defecto
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
  late PortalAlumnaData _data;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final data = await widget.repository.getPortalAlumnaData(alumnaId: widget.alumnaId);
    if (!mounted) return;
    setState(() {
      _data = data;
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

  // Modal para justificar inasistencia especificando clase y fecha (US-35)
  void _abrirModalJustificativo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivoCtrl = TextEditingController();
    String motivoSeleccionado = 'Salud';

    // Lista de sesiones para seleccionar
    final sesionesDisponibles = _data.sesiones;
    String sesionSeleccionadaId = sesionesDisponibles.firstOrNull?.id ?? 'sesion-4';
    String? errorDetalle;

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
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    const Text(
                      'Justificar Inasistencia (US-35)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Indica la fecha y clase a la que faltarás. El Equipo de Gestión evaluará tu solicitud.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector obligatorio de clase / sábado a faltar
                    const Text(
                      '¿A qué clase faltarás? (Fecha del Sábado):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral100,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: sesionSeleccionadaId,
                          dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                          items: sesionesDisponibles.map((s) {
                            final f = s.fecha;
                            final fechaStr = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(
                                'Clase #${s.numeroSesion} ($fechaStr) - ${s.tema}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => sesionSeleccionadaId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Motivo tipificado:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Salud', 'Familiar', 'Escolar', 'Transporte', 'Otro'].map((m) {
                        final sel = motivoSeleccionado == m;
                        return ChoiceChip(
                          label: Text(m),
                          selected: sel,
                          selectedColor: NinasProColors.primary700,
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : (isDark ? Colors.white : Colors.black),
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => motivoSeleccionado = m);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Detalle de la justificación:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: motivoCtrl,
                      maxLines: 3,
                      onChanged: (_) {
                        if (errorDetalle != null) {
                          setModalState(() => errorDetalle = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Explica brevemente la razón de tu ausencia...',
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
                          if (motivoCtrl.text.trim().isEmpty) {
                            setModalState(
                              () => errorDetalle = 'Debes ingresar el detalle de la justificación.',
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          await widget.repository.enviarJustificativo(
                            alumnaId: widget.alumnaId,
                            sesionId: sesionSeleccionadaId,
                            motivoTipificado: motivoSeleccionado,
                            detalle: motivoCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('✅ Justificativo enviado al Equipo de Gestión.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Enviar Justificativo'),
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

    final alumna = _data.alumna;
    final asistenciaPorc = alumna.porcentajeAsistencia;
    final umbral = _data.umbralAprobacion;
    final aprueba = asistenciaPorc >= umbral;

    // Conteo de clases realizadas y asistidas
    final clasesRealizadas = _data.sesiones.where((s) => s.estado == 'realizada').length;

    // Referencia para escalar las barras del podio
    final maxPodios = [
      _data.podiosPrimerLugar,
      _data.podiosSegundoLugar,
      _data.podiosTercerLugar,
    ].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NinasProColors.brandPink,
        foregroundColor: NinasProColors.neutral900,
        onPressed: () => _abrirModalJustificativo(context),
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
                              '¡Hola, ${alumna.nombre.split(' ').first}! 💜',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? NinasProColors.white : NinasProColors.primary900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alumna.cursoNombre,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? NinasProColors.primary300 : NinasProColors.primary700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alumna.sedeNombre,
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
            if (_data.curso.classroomUrl != null || _data.curso.juezVirtualUrl != null) ...[
              NinasProRecursosCursoCard(curso: _data.curso),
              const SizedBox(height: 16),
            ],

            // Tarjeta de progreso de asistencia (US-25 & US-35)
            Card(
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
                            aprueba
                                ? 'Cumple meta (>= ${umbral.toInt()}%)'
                                : 'Bajo meta mínima (< ${umbral.toInt()}%)',
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
                          '${asistenciaPorc.toStringAsFixed(1)}%',
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
                                '${alumna.asistenciasCount} de $clasesRealizadas clases asistidas (Meta: ${umbral.toInt()}% para certificar)',
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

                    if (umbral == 70.0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NinasProColors.primary700.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: NinasProColors.brandPink),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Meta reducida al 70% gracias a que cuentas con al menos 1 justificativo aprobado.',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                                  value: (_data.totalEjerciciosResueltos / _maxEjercicios).clamp(0.0, 1.0),
                                  strokeWidth: 6,
                                  backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                                  valueColor: const AlwaysStoppedAnimation(NinasProColors.brandPink),
                                ),
                                Center(
                                  child: Text(
                                    '${_data.totalEjerciciosResueltos}',
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
                            clases: _data.clasesRecuperadasPorEjercicios,
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
                              veces: _data.podiosSegundoLugar,
                              maxVeces: maxPodios,
                              color: NinasProColors.neutral300,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildEscalonPodio(
                              medalla: '🥇',
                              veces: _data.podiosPrimerLugar,
                              maxVeces: maxPodios,
                              color: NinasProColors.warning500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildEscalonPodio(
                              medalla: '🥉',
                              veces: _data.podiosTercerLugar,
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
            const Text(
              'Cronograma de Clases (Sábados)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            ..._data.sesiones.map((sesion) {
              // Buscar registro de asistencia de la alumna
              final reg = _data.asistencias.where((a) => a.sesionId == sesion.id).firstOrNull;
              final estado = reg?.estado ??
                  (sesion.estado == 'realizada' ? EstadoAsistencia.ausente : EstadoAsistencia.pendiente);
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
                                  '${sesion.fecha.day}/${sesion.fecha.month}/${sesion.fecha.year}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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
    final total = _data.totalEjerciciosResueltos;

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
      ('🥇', '1° Lugar', _data.podiosPrimerLugar),
      ('🥈', '2° Lugar', _data.podiosSegundoLugar),
      ('🥉', '3° Lugar', _data.podiosTercerLugar),
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
