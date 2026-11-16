import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/justificativos_repository.dart';
import '../tutora/clase_sesion_controller.dart';

/// Aviso de minimización de datos de salud junto a la explicación (RB-8)
const avisoPrivacidadJustificativo =
    'Por tu privacidad, no incluyas diagnósticos médicos ni datos de salud sensibles: basta con el motivo general.';

/// Bandeja de justificativos del Equipo de Gestión de la sede (US-16, US-37).
///
/// Filtra por estado, aprueba o rechaza con observación, registra el aviso de
/// la apoderada (queda aprobado) y elimina lo vinculado por error. Cada cambio
/// puede mover la asistencia, así que avisa con [alCambiarAsistencia].
class BandejaJustificativosController extends ChangeNotifier {
  final JustificativosRepository repository;

  /// Se llama tras aprobar, registrar o eliminar: la asistencia de la clase cambió
  final Future<void> Function()? alCambiarAsistencia;

  BandejaJustificativosController(this.repository, {this.alCambiarAsistencia});

  List<JustificativoDetalle> todos = const [];
  bool cargando = true;
  String? error;
  EstadoJustificativo filtro = EstadoJustificativo.pendiente;

  List<JustificativoDetalle> get filtrados => todos.where((j) => j.estado == filtro).toList();

  int cantidad(EstadoJustificativo estado) => todos.where((j) => j.estado == estado).length;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      todos = await repository.justificativos();
    } catch (_) {
      error = 'No pudimos cargar los justificativos. Desliza hacia abajo para reintentar.';
    }
    cargando = false;
    notifyListeners();
  }

  void filtrar(EstadoJustificativo estado) {
    filtro = estado;
    notifyListeners();
  }

  Future<Resultado<void>> _tras(Future<Resultado<void>> operacion, {bool mueveAsistencia = true}) async {
    final r = await operacion;
    if (r.ok) {
      await cargar();
      if (mueveAsistencia) await alCambiarAsistencia?.call();
    }
    return r;
  }

  Future<Resultado<void>> resolver(JustificativoDetalle j, {required bool aprobar, String? observacion}) => _tras(
    repository.resolver(j.id, aprobar: aprobar, observacion: observacion),
    mueveAsistencia: aprobar,
  );

  Future<Resultado<void>> eliminar(JustificativoDetalle j) => _tras(repository.eliminar(j.id));

  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
  }) => _tras(
    repository.registrar(claseId: claseId, inscripcionId: inscripcionId, motivo: motivo, explicacion: explicacion),
  );
}

void _avisar(ScaffoldMessengerState messenger, String texto, {bool error = false}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(backgroundColor: error ? NinasProColors.error700 : NinasProColors.success700, content: Text(texto)),
    );
}

/// Colores (fondo, texto) del estado de un justificativo
(Color, Color) coloresEstadoJustificativo(EstadoJustificativo estado) => switch (estado) {
  EstadoJustificativo.pendiente => (NinasProColors.warning100, NinasProColors.warning900),
  EstadoJustificativo.aceptado => (NinasProColors.success100, NinasProColors.success900),
  EstadoJustificativo.rechazado => (NinasProColors.error100, NinasProColors.error900),
};

/// Etiqueta del estado de un justificativo
class EtiquetaEstadoJustificativo extends StatelessWidget {
  final EstadoJustificativo estado;

  const EtiquetaEstadoJustificativo({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = coloresEstadoJustificativo(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Text(
        estado.label.toUpperCase(),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: texto),
      ),
    );
  }
}

/// Sección de la pantalla de Gestión con la bandeja y sus filtros (US-37 escenario 4)
class SeccionJustificativos extends StatelessWidget {
  final BandejaJustificativosController controller;

  const SeccionJustificativos({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lista = controller.filtrados;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final e in EstadoJustificativo.values)
                  ChoiceChip(
                    label: Text(
                      '${e == EstadoJustificativo.aceptado ? 'Aprobados' : '${e.label}s'} (${controller.cantidad(e)})',
                    ),
                    selected: controller.filtro == e,
                    onSelected: (_) => controller.filtrar(e),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (controller.cargando && controller.todos.isEmpty)
              const Center(
                child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
              )
            else if (controller.error != null)
              Text(
                controller.error!,
                style: const TextStyle(color: NinasProColors.error700, fontWeight: FontWeight.w600),
              )
            else if (lista.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.task_alt_rounded, size: 36, color: NinasProColors.success700),
                    const SizedBox(height: 8),
                    Text(
                      controller.filtro == EstadoJustificativo.pendiente
                          ? 'No hay justificativos esperando tu aprobación.'
                          : 'No hay justificativos ${controller.filtro == EstadoJustificativo.aceptado ? 'aprobados' : 'rechazados'}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final j in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TarjetaJustificativo(justificativo: j, controller: controller),
                ),
          ],
        );
      },
    );
  }
}

/// Justificativo de la bandeja con sus acciones (US-37)
class TarjetaJustificativo extends StatelessWidget {
  final JustificativoDetalle justificativo;
  final BandejaJustificativosController controller;

  const TarjetaJustificativo({super.key, required this.justificativo, required this.controller});

  Future<void> _eliminar(BuildContext context) async {
    final j = justificativo;
    final messenger = ScaffoldMessenger.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar justificativo'),
        content: Text(
          'Se eliminará el justificativo de ${j.alumnaNombre} (${j.claseEtiqueta})'
          '${j.estado == EstadoJustificativo.aceptado ? ' y su asistencia de esa clase volverá a Ausente' : ''}. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final r = await controller.eliminar(j);
    _avisar(messenger, r.ok ? '🗑️ Justificativo eliminado.' : '⚠️ ${r.error}', error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final j = justificativo;
    final (borde, _) = coloresEstadoJustificativo(j.estado);
    final secundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: j.estado == EstadoJustificativo.pendiente ? NinasProColors.warning500 : borde,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(j.alumnaNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                EtiquetaEstadoJustificativo(estado: j.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${j.claseEtiqueta} · ${j.cursoNombre}\nMotivo: ${j.motivo.label}'
              '${j.enviadoPorAlumna ? '' : ' · Registrado por Gestión'}',
              style: TextStyle(fontSize: 11.5, color: secundario),
            ),
            if (j.explicacion != null) ...[
              const SizedBox(height: 8),
              Text('"${j.explicacion}"', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
            ],
            if (j.observacion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Observación${j.resueltoPor == null ? '' : ' de ${j.resueltoPor}'}: ${j.observacion}',
                style: TextStyle(fontSize: 12, color: secundario, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: NinasProColors.error700),
                  onPressed: () => _eliminar(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Eliminar'),
                ),
                if (j.estado == EstadoJustificativo.pendiente)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                    onPressed: () => mostrarModalResolverJustificativo(context, controller, j),
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text('Evaluar Justificativo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _asa(bool isDark) => Center(
  child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

ShapeBorder get _formaModal =>
    const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

/// Aprobar o rechazar un pendiente; el rechazo exige la observación para la alumna (US-37)
Future<void> mostrarModalResolverJustificativo(
  BuildContext context,
  BandejaJustificativosController controller,
  JustificativoDetalle j,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final messenger = ScaffoldMessenger.of(context);
  final obsCtrl = TextEditingController();
  String? errorObs;
  var guardando = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
    shape: _formaModal,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        Future<void> resolver(bool aprobar) async {
          if (!aprobar && obsCtrl.text.trim().isEmpty) {
            setModal(() => errorObs = 'Indica el motivo del rechazo para que la alumna lo sepa.');
            return;
          }
          setModal(() => guardando = true);
          final r = await controller.resolver(j, aprobar: aprobar, observacion: obsCtrl.text);
          if (!ctx.mounted) return;
          if (!r.ok) {
            setModal(() {
              guardando = false;
              errorObs = r.error;
            });
            return;
          }
          Navigator.pop(ctx);
          _avisar(
            messenger,
            aprobar
                ? '✅ Justificativo aprobado: la asistencia de esa clase quedó Justificada.'
                : '❌ Justificativo rechazado.',
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _asa(isDark),
                const SizedBox(height: 16),
                const Text('Revisar Justificativo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  'Exclusivo Equipo de Gestión',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumna: ${j.alumnaNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text('${j.claseEtiqueta} · ${j.cursoNombre}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${j.motivo.label}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (j.explicacion != null) ...[
                        const SizedBox(height: 6),
                        Text('"${j.explicacion}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Observación (obligatoria al rechazar):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  onChanged: (_) {
                    if (errorObs != null) setModal(() => errorObs = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Ej: Falta la constancia de atención…',
                    errorText: errorObs,
                    errorMaxLines: 3,
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
                        onPressed: guardando ? null : () => resolver(false),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: guardando ? null : () => resolver(true),
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
    ),
  );
}

/// Selector de motivo tipificado (US-35 escenario 2, RB-8)
class SelectorMotivoJustificativo extends StatelessWidget {
  final MotivoJustificativo? motivo;
  final ValueChanged<MotivoJustificativo> onCambiar;

  const SelectorMotivoJustificativo({super.key, required this.motivo, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final m in MotivoJustificativo.values)
          ChoiceChip(label: Text(m.label), selected: motivo == m, onSelected: (_) => onCambiar(m)),
      ],
    );
  }
}

/// Aviso de privacidad junto a la explicación del justificativo (RB-8)
class AvisoPrivacidadJustificativo extends StatelessWidget {
  const AvisoPrivacidadJustificativo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: NinasProColors.info100, borderRadius: BorderRadius.circular(10)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 18, color: NinasProColors.info900),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              avisoPrivacidadJustificativo,
              style: TextStyle(fontSize: 11.5, color: NinasProColors.info900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gestión registra el aviso de la apoderada: queda aprobado y la asistencia
/// de esa clase, justificada, aunque sea una clase futura (US-16)
Future<void> mostrarModalRegistrarJustificativo(
  BuildContext context,
  BandejaJustificativosController controller,
  ClaseSesionController clase,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final messenger = ScaffoldMessenger.of(context);
  final sesiones = clase.sesiones.where((s) => !s.suspendida).toList();
  if (sesiones.isEmpty) {
    _avisar(messenger, 'El curso no tiene clases para justificar.', error: true);
    return Future.value();
  }

  final detalleCtrl = TextEditingController();
  var sesionId = sesiones.any((s) => s.id == clase.sesionId) ? clase.sesionId : sesiones.first.id;
  List<RegistroAsistencia>? alumnas;
  String? inscripcionId;
  MotivoJustificativo? motivo;
  String? error;
  var guardando = false;
  var cargandoAlumnas = false;

  final campo = BoxDecoration(
    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
    borderRadius: BorderRadius.circular(12),
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
    shape: _formaModal,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        // Alumnas de la clase elegida que pueden justificarse (no presentes ni ya justificadas)
        Future<void> cargarAlumnas() async {
          List<RegistroAsistencia> lista;
          try {
            lista = (await clase.listaDeSesion(sesionId)).registros
                .where(
                  (r) =>
                      r.estado != EstadoAsistencia.presente &&
                      r.estado != EstadoAsistencia.justificada &&
                      r.justificativo != EstadoJustificativo.aceptado &&
                      r.justificativo != EstadoJustificativo.pendiente,
                )
                .toList();
          } catch (_) {
            lista = const [];
            error = 'No pudimos cargar las alumnas de esa clase.';
          }
          if (!ctx.mounted) return;
          setModal(() {
            alumnas = lista;
            inscripcionId = lista.firstOrNull?.id;
            cargandoAlumnas = false;
          });
        }

        if (alumnas == null && !cargandoAlumnas) {
          cargandoAlumnas = true;
          Future.microtask(cargarAlumnas);
        }

        Future<void> guardar() async {
          final insc = inscripcionId;
          if (insc == null) return setModal(() => error = 'Elige a la alumna.');
          if (motivo == null) return setModal(() => error = 'Elige el motivo de la inasistencia.');
          if (detalleCtrl.text.trim().isEmpty) {
            return setModal(() => error = 'Escribe la descripción del aviso.');
          }
          setModal(() {
            guardando = true;
            error = null;
          });
          final r = await controller.registrar(
            claseId: sesionId,
            inscripcionId: insc,
            motivo: motivo!,
            explicacion: detalleCtrl.text,
          );
          if (!ctx.mounted) return;
          if (!r.ok) {
            return setModal(() {
              guardando = false;
              error = r.error;
            });
          }
          Navigator.pop(ctx);
          _avisar(messenger, '✅ Justificativo registrado y aprobado.');
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _asa(isDark),
                const SizedBox(height: 16),
                const Text('Ingresar Justificativo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Para avisos de la apoderada: se registra aprobado y la asistencia de esa clase queda Justificada, '
                  'también si la clase aún no se realiza.',
                  style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                ),
                const SizedBox(height: 16),
                const Text('Clase:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: campo,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: sesionId,
                      dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                      items: [
                        for (final s in sesiones)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              'Clase #${s.numeroSesion} · ${fechaCorta(s.fecha)} · ${s.tema}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null || v == sesionId) return;
                        setModal(() {
                          sesionId = v;
                          alumnas = null;
                          inscripcionId = null;
                          error = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Alumna:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (cargandoAlumnas || alumnas == null)
                  const LinearProgressIndicator()
                else if (alumnas!.isEmpty)
                  const Text(
                    'No hay alumnas con inasistencia por justificar en esa clase.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: campo,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: inscripcionId,
                        dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                        items: [
                          for (final a in alumnas!)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                a.alumnaNombre,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setModal(() => inscripcionId = v),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                const Text('Motivo:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelectorMotivoJustificativo(motivo: motivo, onCambiar: (m) => setModal(() => motivo = m)),
                const SizedBox(height: 14),
                const Text('Descripción:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const AvisoPrivacidadJustificativo(),
                const SizedBox(height: 8),
                TextField(
                  controller: detalleCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Ej: La apoderada avisó por teléfono que no podrá asistir…',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: NinasProColors.error700, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: guardando || (alumnas?.isEmpty ?? true) ? null : guardar,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Registrar y Aprobar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
