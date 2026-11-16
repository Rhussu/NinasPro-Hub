import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/roles_repository.dart';
import 'clase_sesion_controller.dart';
import '../../widgets/ninaspro_mascot.dart';
import '../../widgets/ninaspro_stat_card.dart';
import '../../widgets/ninaspro_vista_centrada.dart';
import '../../widgets/ninaspro_planificacion_hoy.dart';

/// Piezas de la pantalla de inicio compartidas por Tutora y Equipo de Gestión
/// (todas las integrantes de Gestión también son tutoras).

/// Abre una pantalla secundaria (asistencia, fotos, historial...) con su propia barra superior.
Future<void> abrirPantallaSecundaria(BuildContext context, String titulo, Widget vista) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: NinasProVistaCentrada(child: vista),
      ),
    ),
  );
}

/// Un rol de la tutora en una clase, con su cumplimiento (US-43, US-44)
class RolEnClase {
  final RolTarea rol;
  final TareaClase tarea;

  const RolEnClase({required this.rol, required this.tarea});

  RolEnClase conCumplimiento(bool completada) => RolEnClase(rol: rol, tarea: tarea.copyWith(completada: completada));
}

/// Una clase del curso vista desde la tutora: si asistió y qué roles tuvo (US-33, US-43).
class ClaseTutoraResumen {
  final SesionClase sesion;
  final EstadoAsistencia estado;

  /// 0, 1, 2 o más roles en la clase
  final List<RolEnClase> roles;

  const ClaseTutoraResumen({required this.sesion, required this.estado, this.roles = const []});
}

/// Historial de asistencia y roles de una tutora en todas las clases del curso.
Future<List<ClaseTutoraResumen>> cargarHistorialTutora({
  required ClaseRepository clase,
  required String? instanciaId,
  required String tutoraId,
  required List<SesionClase> sesiones,
  RolesRepository? roles,
}) async {
  if (instanciaId == null) {
    return [for (final s in sesiones) ClaseTutoraResumen(sesion: s, estado: EstadoAsistencia.pendiente)];
  }
  final asistencia = await clase.miAsistencia(instanciaId: instanciaId, tutoraId: tutoraId);
  final porClase = <String, List<RolEnClase>>{};
  if (roles != null) {
    // Con los inactivos: un rol desactivado sigue apareciendo en las clases en que se asignó
    final catalogo = {for (final r in await roles.roles(incluirInactivos: true)) r.id: r};
    for (final t in await roles.misRoles(instanciaId)) {
      final rol = catalogo[t.tarea.rolId];
      if (rol != null) (porClase[t.claseId] ??= []).add(RolEnClase(rol: rol, tarea: t.tarea));
    }
  }
  return [
    for (final sesion in sesiones)
      ClaseTutoraResumen(
        sesion: sesion,
        estado: asistencia[sesion.id] ?? EstadoAsistencia.pendiente,
        roles: porClase[sesion.id] ?? const [],
      ),
  ];
}

/// Aviso cuando no se pudo cargar la clase (ej. sin conexión al abrir la app)
class AvisoErrorClase extends StatelessWidget {
  final String mensaje;

  const AvisoErrorClase({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: NinasProColors.warning100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: NinasProColors.warning900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NinasProColors.warning900),
            ),
          ),
        ],
      ),
    );
  }
}

/// 'PCB · Sede Beauchef · Sección B': el curso con su sede (y su sección paralela)
String etiquetaCursoClase(Curso c) => '${c.nombre} · ${c.sedeNombre}${c.seccion > 1 ? ' · Sección ${c.seccionLetra}' : ''}';

/// Selector del curso cuando la usuaria opera más de uno
class SelectorCursoClase extends StatelessWidget {
  final List<Curso> cursos;
  final String? cursoId;
  final ValueChanged<String> onCambiar;

  const SelectorCursoClase({super.key, required this.cursos, required this.cursoId, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: cursoId,
          hint: const Text('Elige el curso'),
          items: [
            for (final c in cursos)
              DropdownMenuItem(
                value: c.id,
                child: Text(
                  etiquetaCursoClase(c),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onCambiar(id);
          },
        ),
      ),
    );
  }
}

/// Alumnas presentes según el último pase de lista guardado (US-13)
class TarjetaPresentesClase extends StatelessWidget {
  final ClaseSesionController controller;
  final VoidCallback? onTap;

  const TarjetaPresentesClase({super.key, required this.controller, this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = controller.registros.length;
    return NinasProStatCard(
      title: 'Alumnas presentes',
      value: controller.tienePaseLista ? '${controller.presentesGuardadas}/$total' : '—/$total',
      subtitle: controller.pendienteDeEnvio
          ? 'Pendiente de envío'
          : (controller.tienePaseLista ? 'Esta semana' : 'Sin pase de lista'),
      icon: Icons.fact_check_rounded,
      accentColor: NinasProColors.primary700,
      onTap: onTap,
    );
  }
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

/// Roles de la tutora en la clase de esta semana (US-43 escenario 4, US-44).
///
/// Con [onMarcar] cada rol tiene su casilla de cumplimiento; con [onVerEquipo]
/// la tarjeta abre los roles de todo el equipo (Gestión los edita ahí).
class TarjetaMisRoles extends StatelessWidget {
  final List<RolEnClase> roles;
  final int? numeroSesion;
  final String mensajeSinRol;
  final Future<void> Function(RolEnClase rol, bool completada)? onMarcar;
  final VoidCallback? onVerEquipo;
  final String etiquetaVerEquipo;

  const TarjetaMisRoles({
    super.key,
    required this.roles,
    required this.numeroSesion,
    required this.mensajeSinRol,
    this.onMarcar,
    this.onVerEquipo,
    this.etiquetaVerEquipo = 'Ver los roles del equipo',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cumplidos = roles.where((r) => r.tarea.completada).length;
    final color = roles.isEmpty ? NinasProColors.warning700 : roles.first.rol.color;
    final secundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    roles.isEmpty ? Icons.help_outline_rounded : Icons.assignment_ind_rounded,
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
                        numeroSesion == null ? 'Tus roles' : 'Tus roles · Clase $numeroSesion',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secundario),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roles.isEmpty
                            ? 'Sin rol asignado'
                            : '$cumplidos de ${roles.length} ${roles.length == 1 ? 'listo' : 'listos'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
                        ),
                      ),
                      if (roles.isEmpty) ...[
                        const SizedBox(height: 2),
                        Text(mensajeSinRol, style: TextStyle(fontSize: 11.5, color: secundario)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            for (final r in roles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: r.rol.color,
                value: r.tarea.completada,
                onChanged: onMarcar == null ? null : (v) => onMarcar!(r, v ?? false),
                title: Text(
                  r.rol.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: r.tarea.completada ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: r.rol.descripcion.isEmpty
                    ? null
                    : Text(r.rol.descripcion, style: TextStyle(fontSize: 11.5, color: secundario)),
              ),
            if (onVerEquipo != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onVerEquipo,
                  icon: const Icon(Icons.groups_rounded, size: 18),
                  label: Text(etiquetaVerEquipo),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
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

/// Registro individual de la tutora: a qué clases fue, a cuáles no y qué roles tuvo (US-33, US-43).
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
                        if (c.roles.isEmpty)
                          const Text(
                            'Sin rol asignado',
                            style: TextStyle(fontSize: 11.5, color: NinasProColors.neutral500),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            children: [
                              for (final r in c.roles)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Icon(
                                            r.tarea.completada
                                                ? Icons.check_circle_rounded
                                                : Icons.assignment_ind_rounded,
                                            size: 13,
                                            color: r.rol.color,
                                          ),
                                        ),
                                      ),
                                      TextSpan(text: r.rol.nombre),
                                    ],
                                  ),
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r.rol.color),
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
