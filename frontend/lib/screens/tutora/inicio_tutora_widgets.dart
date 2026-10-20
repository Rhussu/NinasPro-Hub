import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_mascot.dart';
import '../../widgets/ninaspro_mobile_shell.dart';
import '../../widgets/ninaspro_planificacion_hoy.dart';

/// Piezas de la pantalla de inicio compartidas por Tutora y Equipo de Gestión
/// (todas las integrantes de Gestión también son tutoras).

/// Abre una pantalla secundaria (asistencia, fotos, historial...) dentro del marco móvil.
Future<void> abrirPantallaEnMarco(BuildContext context, String titulo, Widget vista) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NinasProMobileShell(
        child: Scaffold(
          appBar: AppBar(title: Text(titulo)),
          body: vista,
        ),
      ),
    ),
  );
}

/// Una clase del curso vista desde la tutora: si asistió y qué rol tuvo (US-33, US-43).
class ClaseTutoraResumen {
  final SesionClase sesion;
  final EstadoAsistencia estado;
  final RolTutorConfig? rol;

  const ClaseTutoraResumen({required this.sesion, required this.estado, this.rol});
}

/// Historial de asistencia y roles de una tutora en todas las clases del curso.
Future<List<ClaseTutoraResumen>> cargarHistorialTutora({
  required HubRepository repository,
  required String tutoraId,
  required List<SesionClase> sesiones,
  required List<RolTutorConfig> roles,
}) async {
  final historial = <ClaseTutoraResumen>[];
  for (final sesion in sesiones) {
    final registros = await repository.getAsistenciaTutoras(sesionId: sesion.id);
    final asignaciones = await repository.getAsignacionesSemanales(semanaNumero: sesion.numeroSesion);
    final codigo = asignaciones.where((a) => a.tutoraId == tutoraId).firstOrNull?.rolCodigo;
    historial.add(ClaseTutoraResumen(
      sesion: sesion,
      estado: registros.where((r) => r.tutoraId == tutoraId).firstOrNull?.estado ?? EstadoAsistencia.pendiente,
      rol: roles.where((r) => r.codigo == codigo).firstOrNull,
    ));
  }
  return historial;
}

/// Banner de bienvenida con la mascota, el nombre de la tutora y la planificación de la clase de hoy.
class BannerBienvenidaTutora extends StatelessWidget {
  final String? nombre;

  /// Clase de hoy según la planificación del curso
  final SesionClase? sesion;
  final String? cursoNombre;
  final String? sedeNombre;

  const BannerBienvenidaTutora({
    super.key,
    required this.nombre,
    required this.sesion,
    this.cursoNombre,
    this.sedeNombre,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sesion = this.sesion;
    final contexto = [?cursoNombre, ?sedeNombre].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NinasProColors.primary700.withValues(alpha: isDark ? 0.35 : 0.14),
            NinasProColors.brandPink.withValues(alpha: isDark ? 0.18 : 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NinasProMascot(size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre != null ? '¡Hola, ${nombre!.split(' ').first}!' : '¡Hola!',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    if (contexto.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contexto,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (sesion != null) ...[
            const SizedBox(height: 12),
            NinasProPlanificacionHoy(sesion: sesion),
          ],
        ],
      ),
    );
  }
}

/// Mi % de asistencia como tutora con gráfico circular (US-33).
class TarjetaMiAsistencia extends StatelessWidget {
  final int asistidas;
  final int registradas;
  final VoidCallback? onTap;

  const TarjetaMiAsistencia({
    super.key,
    required this.asistidas,
    required this.registradas,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final porcentaje = registradas == 0 ? 0.0 : asistidas / registradas;
    final color = porcentaje >= 0.8
        ? NinasProColors.success700
        : (porcentaje >= 0.6 ? NinasProColors.warning700 : NinasProColors.error700);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: porcentaje,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: color.withValues(alpha: isDark ? 0.22 : 0.12),
                    ),
                    Center(
                      child: Text(
                        '${(porcentaje * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mi asistencia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$asistidas/$registradas',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clases como tutora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rol asignado a la tutora esta semana (US-43).
/// Con [onTap] es un acceso (Gestión edita roles); sin él es solo informativa (Tutora).
class TarjetaMiRol extends StatelessWidget {
  final RolTutorConfig? rol;
  final int semana;
  final String mensajeSinRol;
  final VoidCallback? onTap;

  const TarjetaMiRol({
    super.key,
    required this.rol,
    required this.semana,
    required this.mensajeSinRol,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rol?.color ?? NinasProColors.warning700;

    final contenido = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              rol != null ? Icons.assignment_ind_rounded : Icons.help_outline_rounded,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu rol esta semana · Semana $semana',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rol?.nombre ?? 'Sin rol asignado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rol?.descripcion ?? mensajeSinRol,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
            ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: onTap == null
          ? contenido
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: contenido),
    );
  }
}

/// Tarjeta de consejo al final de la pantalla de inicio.
class TarjetaConsejo extends StatelessWidget {
  final String texto;

  const TarjetaConsejo({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NinasProColors.accent700.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 20, color: NinasProColors.accent700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registro individual de la tutora: a qué clases fue, a cuáles no y qué rol tuvo (US-33, US-43).
class MiHistorialTutoraView extends StatelessWidget {
  final List<ClaseTutoraResumen> historial;
  final String sesionActualId;

  const MiHistorialTutoraView({
    super.key,
    required this.historial,
    required this.sesionActualId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final registradas = historial.where((c) => c.estado != EstadoAsistencia.pendiente).toList();
    final asistidas = registradas.where((c) => c.estado == EstadoAsistencia.presente).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        TarjetaMiAsistencia(asistidas: asistidas, registradas: registradas.length),
        const SizedBox(height: 14),
        ...historial.map((c) {
          final f = c.sesion.fecha;
          final fechaStr = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
          final programada = c.estado == EstadoAsistencia.pendiente;
          final tono = context.statusColors.asistencia(c.estado);
          final esActual = c.sesion.id == sesionActualId;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: esActual
                    ? NinasProColors.brandPink
                    : (c.estado == EstadoAsistencia.ausente
                        ? NinasProColors.error700.withValues(alpha: 0.5)
                        : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100)),
                width: esActual || c.estado == EstadoAsistencia.ausente ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Semana ${c.sesion.numeroSesion} · $fechaStr',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (esActual) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'HOY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: NinasProColors.brandPink,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          c.sesion.tema,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_ind_rounded,
                              size: 13,
                              color: c.rol?.color ?? NinasProColors.neutral500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                c.rol?.nombre ?? 'Sin rol asignado',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: c.rol != null ? FontWeight.w700 : FontWeight.w400,
                                  color: c.rol?.color ?? NinasProColors.neutral500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: tono.decoration,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.estado.icon, size: 14, color: tono.foreground),
                        const SizedBox(width: 4),
                        Text(
                          programada ? 'Programada' : c.estado.label,
                          style: tono.textStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
