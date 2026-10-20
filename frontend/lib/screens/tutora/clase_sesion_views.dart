import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import 'clase_sesion_controller.dart';

/// Vistas de la clase en curso, compartidas entre Tutora y Equipo de Gestión.
///
/// - [AsistenciaClaseView]: US-13, pase de lista táctil Presente ↔ Ausente, con historial por semana.
/// - [EjerciciosClaseView]: US-28, ejercicios resueltos y participación activa.
/// - [FotosClaseView]: US-18 y US-19, evidencia fotográfica y consentimientos de imagen.
/// - [mostrarModalRegistroKahoot]: US-29, podio Kahoot de la clase.

// Pase de lista táctil rápido (US-13) con historial semana a semana del curso
class AsistenciaClaseView extends StatefulWidget {
  final ClaseSesionController controller;

  const AsistenciaClaseView({super.key, required this.controller});

  @override
  State<AsistenciaClaseView> createState() => _AsistenciaClaseViewState();
}

class _AsistenciaClaseViewState extends State<AsistenciaClaseView> {
  // Clase que se está viendo; null = clase en curso (editable)
  String? _sesionVistaId;
  List<RegistroAsistencia> _historial = [];
  bool _cargandoHistorial = false;

  ClaseSesionController get controller => widget.controller;

  bool get _esClaseActual => _sesionVistaId == null || _sesionVistaId == controller.sesionId;

  Future<void> _verSesion(String id) async {
    if (id == controller.sesionId) {
      setState(() => _sesionVistaId = null);
      return;
    }
    setState(() {
      _sesionVistaId = id;
      _cargandoHistorial = true;
    });
    final regs = await controller.registrosDeSesion(id);
    if (!mounted || _sesionVistaId != id) return;
    setState(() {
      _historial = regs;
      _cargandoHistorial = false;
    });
  }

  void _ciclarEstado(BuildContext context, int index) {
    if (controller.ciclarEstado(index)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.warning900,
        content: Text('🔒 Justificada por Equipo de Gestión. Las tutoras solo marcan Presente o Ausente.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _guardarAsistencia(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ms = await controller.guardarAsistencia();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: NinasProColors.success700,
        content: Text(
          '✅ Asistencia guardada: ${controller.totalPresentes} presentes, ${controller.totalAusentes} ausentes, '
          '${controller.totalJustificadas} justificadas ($ms ms).',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        final editable = _esClaseActual;
        final registros = editable ? controller.registros : _historial;
        int contar(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;
        final sinPaseLista = registros.every((r) => r.estado == EstadoAsistencia.pendiente);

        return Column(
          children: [
            SelectorSemanaClase(
              sesiones: controller.sesiones,
              sesionVistaId: _sesionVistaId ?? controller.sesionId,
              sesionActualId: controller.sesionId,
              onCambiar: _verSesion,
            ),

            if (_cargandoHistorial)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (sinPaseLista)
              const Expanded(child: EstadoSinPaseLista())
            else ...[
              // Barra resumen sticky con contadores
              BarraContadoresAsistencia(
                contadores: [
                  ContadorAsistencia(label: 'Presentes', count: contar(EstadoAsistencia.presente), estado: EstadoAsistencia.presente),
                  ContadorAsistencia(label: 'Ausentes', count: contar(EstadoAsistencia.ausente), estado: EstadoAsistencia.ausente),
                  ContadorAsistencia(label: 'Justificadas', count: contar(EstadoAsistencia.justificada), estado: EstadoAsistencia.justificada),
                ],
              ),

              // Lista táctil de alumnas
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: registros.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final reg = registros[index];

                    return TarjetaAsistencia(
                      nombre: reg.alumnaNombre,
                      estado: reg.estado,
                      bloqueada: reg.estado == EstadoAsistencia.justificada,
                      onTap: editable ? () => _ciclarEstado(context, index) : null,
                      detalle: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            reg.alumnaRut,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                            ),
                          ),
                          if (!reg.autorizaImagen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: NinasProColors.warning100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Sin foto',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: NinasProColors.warning900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (editable)
                BarraGuardarAsistencia(
                  label: 'Guardar Asistencia de la Clase',
                  onGuardar: () => _guardarAsistencia(context),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Selector para recorrer semana a semana las clases del curso.
/// La clase en curso es editable; las demás se muestran como historial de solo lectura.
class SelectorSemanaClase extends StatelessWidget {
  final List<SesionClase> sesiones;
  final String sesionVistaId;
  final String sesionActualId;
  final ValueChanged<String> onCambiar;

  const SelectorSemanaClase({
    super.key,
    required this.sesiones,
    required this.sesionVistaId,
    required this.sesionActualId,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = sesiones.indexWhere((s) => s.id == sesionVistaId);
    final sesion = idx != -1 ? sesiones[idx] : null;
    final esActual = sesionVistaId == sesionActualId;

    final f = sesion?.fecha;
    final fechaStr = f == null ? '' : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    final etiqueta = esActual ? 'Clase actual' : 'Historial · solo lectura';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
            onPressed: idx > 0 ? () => onCambiar(sesiones[idx - 1].id) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  sesion != null ? 'Semana ${sesion.numeroSesion} · $fechaStr' : 'Semana',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (sesion != null)
                  Text(
                    sesion.tema,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: esActual
                        ? NinasProColors.brandPink
                        : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                ),
              ],
            ),
          ),
          if (!esActual)
            IconButton(
              tooltip: 'Volver a la clase actual',
              icon: const Icon(Icons.today_rounded, color: NinasProColors.brandPink),
              onPressed: () => onCambiar(sesionActualId),
            ),
          IconButton(
            tooltip: 'Semana siguiente',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: idx != -1 && idx < sesiones.length - 1 ? () => onCambiar(sesiones[idx + 1].id) : null,
          ),
        ],
      ),
    );
  }
}

/// Estado vacío de una clase que todavía no tiene pase de lista.
class EstadoSinPaseLista extends StatelessWidget {
  const EstadoSinPaseLista({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_rounded, size: 40, color: NinasProColors.brandPink),
            const SizedBox(height: 10),
            const Text(
              'Clase programada',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Esta clase aún no tiene pase de lista registrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos de un contador de la barra resumen de asistencia.
class ContadorAsistencia {
  final String label;
  final int count;
  final EstadoAsistencia estado;

  const ContadorAsistencia({required this.label, required this.count, required this.estado});
}

/// Barra resumen sticky con contadores por estado de asistencia.
class BarraContadoresAsistencia extends StatelessWidget {
  final List<ContadorAsistencia> contadores;

  const BarraContadoresAsistencia({super.key, required this.contadores});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < contadores.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _CounterChip(
                label: contadores[i].label,
                count: contadores[i].count,
                estado: contadores[i].estado,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de pase de lista: avatar, nombre, [detalle] y botón táctil de estado.
/// Si [onTap] es null la tarjeta es de solo lectura (historial).
class TarjetaAsistencia extends StatelessWidget {
  final String nombre;
  final EstadoAsistencia estado;
  final Widget detalle;
  final Widget? etiqueta;
  final bool bloqueada;
  final VoidCallback? onTap;

  const TarjetaAsistencia({
    super.key,
    required this.nombre,
    required this.estado,
    required this.detalle,
    this.etiqueta,
    this.bloqueada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tono = context.statusColors.asistencia(estado);
    final esAusente = estado == EstadoAsistencia.ausente;

    final botonEstado = Container(
      constraints: const BoxConstraints(minWidth: 105, minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: tono.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            bloqueada ? Icons.lock_outline_rounded : estado.icon,
            size: 16,
            color: tono.foreground,
          ),
          const SizedBox(width: 6),
          Text(estado.label, style: tono.textStyle(fontSize: 12)),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: esAusente
              ? NinasProColors.error700.withValues(alpha: 0.5)
              : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
          width: esAusente ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Avatar o iniciales
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
              child: Text(
                nombre.isNotEmpty ? nombre[0] : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nombre,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (etiqueta != null) ...[
                        const SizedBox(width: 6),
                        etiqueta!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  detalle,
                ],
              ),
            ),

            // Botón táctil grande (área táctil >= 48px) para alternar estado P/A
            if (onTap != null)
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: botonEstado,
              )
            else
              botonEstado,
          ],
        ),
      ),
    );
  }
}

/// Barra inferior fija con el botón de guardar asistencia.
class BarraGuardarAsistencia extends StatelessWidget {
  final String label;
  final VoidCallback onGuardar;

  const BarraGuardarAsistencia({super.key, required this.label, required this.onGuardar});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark900 : NinasProColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: NinasProTheme.brandButton,
            onPressed: onGuardar,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final String label;
  final int count;
  final EstadoAsistencia estado;

  const _CounterChip({required this.label, required this.count, required this.estado});

  @override
  Widget build(BuildContext context) {
    final tono = context.statusColors.asistencia(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: tono.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icon, size: 14, color: tono.foreground),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: tono.textStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// Registro de Ejercicios y Participación Activa (US-28)
class EjerciciosClaseView extends StatelessWidget {
  final ClaseSesionController controller;

  const EjerciciosClaseView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        final alumnasPresentes = controller.alumnasPresentes;

        if (alumnasPresentes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No hay alumnas marcadas como Presentes en esta sesión. '
                'Marca la asistencia primero.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NinasProColors.accent700.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: NinasProColors.accent700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrando únicamente a las alumnas Presentes (US-28). '
                      'Las alumnas ausentes tienen bloqueado el registro de ejercicios.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...alumnasPresentes.map((reg) {
              final partIndex = controller.participaciones.indexWhere((p) => p.alumnaId == reg.alumnaId);
              final part = partIndex != -1
                  ? controller.participaciones[partIndex]
                  : ParticipacionClase(
                      id: 'part-${reg.alumnaId}',
                      sesionId: controller.sesionId,
                      alumnaId: reg.alumnaId,
                      alumnaNombre: reg.alumnaNombre,
                      ejerciciosResueltos: 3,
                      participacionActiva: true,
                    );

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reg.alumnaNombre,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text('Ejercicios resueltos en aula:', style: TextStyle(fontSize: 12.5)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () {
                                  if (part.ejerciciosResueltos > 0) {
                                    controller.actualizarParticipacion(
                                      part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos - 1),
                                    );
                                  }
                                },
                              ),
                              Text(
                                '${part.ejerciciosResueltos}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () {
                                  controller.actualizarParticipacion(
                                    part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos + 1),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text('Participación activa en aula:', style: TextStyle(fontSize: 12.5)),
                          Switch(
                            value: part.participacionActiva,
                            activeThumbColor: NinasProColors.brandPink,
                            onChanged: (val) {
                              controller.actualizarParticipacion(part.copyWith(participacionActiva: val));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// Evidencia Fotográfica y Consentimientos de Imagen (US-18, US-19)
class FotosClaseView extends StatelessWidget {
  final ClaseSesionController controller;

  const FotosClaseView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        final alumnasSinFoto = controller.registros
            .where((r) => r.estado == EstadoAsistencia.presente && !r.autorizaImagen)
            .toList();

        final todasConFoto = alumnasSinFoto.isEmpty;
        final fotoSubida = controller.fotoSubida;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Card(
              elevation: 0,
              color: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          todasConFoto ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: todasConFoto ? NinasProColors.success700 : NinasProColors.warning700,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            todasConFoto
                                ? 'Foto 100% Apta para Redes / Sponsors'
                                : 'Atención: Restricción de Imagen',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (todasConFoto)
                      Text(
                        'Todas las alumnas presentes cuentan con autorización de imagen firmada por sus apoderados (US-19).',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      )
                    else ...[
                      Text(
                        'Las siguientes alumnas presentes NO tienen consentimiento de imagen:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...alumnasSinFoto.map((a) => Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(
                              '• ${a.alumnaNombre} (${a.alumnaRut})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: NinasProColors.error700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )),
                      const SizedBox(height: 6),
                      const Text(
                        '⚠️ La fotografía de la clase debe tomarse de espaldas o difuminar los rostros.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: NinasProColors.warning900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    fotoSubida ? Icons.photo_library_rounded : Icons.cloud_upload_outlined,
                    size: 48,
                    color: NinasProColors.brandPink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fotoSubida
                        ? 'Evidencia fotográfica lista y comprimida en cliente'
                        : 'Subir foto de la sesión desde el celular (US-18)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: () {
                      controller.marcarFotoSubida();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: NinasProColors.success700,
                          content: Text('📸 Foto comprimida (< 1.5 MB) y vinculada a la sesión.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text(fotoSubida ? 'Reemplazar Foto' : 'Tomar / Seleccionar Foto'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Modal para registrar podio Kahoot de la clase (US-29)
void mostrarModalRegistroKahoot(BuildContext context, ClaseSesionController controller) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final presentes = controller.alumnasPresentes;

  if (presentes.length < 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Se necesitan al menos 3 alumnas presentes para registrar el podio Kahoot.'),
      ),
    );
    return;
  }

  String primerId = controller.primerLugarId ?? presentes[0].alumnaId;
  String segundoId = controller.segundoLugarId ?? presentes[1].alumnaId;
  String tercerId = controller.tercerLugarId ?? presentes[2].alumnaId;

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
                      child: const Icon(Icons.emoji_events_rounded, color: NinasProColors.warning900, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Registrar Podio Kahoot (US-29)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Asigna las 3 alumnas ganadoras del desafío de hoy. Se actualizará su historial.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 16),

                // 1° Lugar
                _DropdownKahoot(
                  label: '🥇 1° Lugar (Medalla de Oro):',
                  selectedValue: primerId,
                  presentes: presentes,
                  onChanged: (val) {
                    if (val != null) setModalState(() => primerId = val);
                  },
                ),
                const SizedBox(height: 12),

                // 2° Lugar
                _DropdownKahoot(
                  label: '🥈 2° Lugar (Medalla de Plata):',
                  selectedValue: segundoId,
                  presentes: presentes,
                  onChanged: (val) {
                    if (val != null) setModalState(() => segundoId = val);
                  },
                ),
                const SizedBox(height: 12),

                // 3° Lugar
                _DropdownKahoot(
                  label: '🥉 3° Lugar (Medalla de Bronce):',
                  selectedValue: tercerId,
                  presentes: presentes,
                  onChanged: (val) {
                    if (val != null) setModalState(() => tercerId = val);
                  },
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await controller.guardarPodioKahoot(
                        primerId: primerId,
                        segundoId: segundoId,
                        tercerId: tercerId,
                      );
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: NinasProColors.success700,
                          content: Text('🏆 Podio Kahoot registrado con éxito.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Guardar Podio de la Sesión'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DropdownKahoot extends StatelessWidget {
  final String label;
  final String selectedValue;
  final List<RegistroAsistencia> presentes;
  final ValueChanged<String?> onChanged;

  const _DropdownKahoot({
    required this.label,
    required this.selectedValue,
    required this.presentes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
              items: presentes.map((a) {
                return DropdownMenuItem(
                  value: a.alumnaId,
                  child: Text(a.alumnaNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
