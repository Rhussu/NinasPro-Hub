import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../repositories/alumnas_repository.dart' show ArchivoAdjunto;
import '../../repositories/justificativos_repository.dart';
import '../gestion/justificativos_gestion.dart'
    show CampoRespaldoJustificativo, EtiquetaEstadoJustificativo, SelectorMotivoJustificativo;

/// La alumna justifica una inasistencia desde su portal (US-35, US-36): elige
/// la clase, el motivo tipificado y explica con sus palabras; el respaldo es
/// opcional. Queda pendiente para el Equipo de Gestión de su sede. Devuelve
/// true si se envió.
Future<bool> mostrarModalJustificarFalta(BuildContext context, JustificativosRepository repository) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final messenger = ScaffoldMessenger.of(context);

  List<ClaseJustificable> clases;
  try {
    clases = (await repository.clasesParaJustificar()).where((c) => c.disponible).toList();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.error700,
        content: Text('No pudimos cargar tus clases. Revisa tu conexión.'),
      ),
    );
    return false;
  }
  if (!context.mounted) return false;
  if (clases.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('No tienes clases por justificar.')));
    return false;
  }

  // Por defecto, la próxima clase (o la última si el curso ya terminó)
  final hoy = DateUtils.dateOnly(DateTime.now());
  var clase = clases.where((c) => !c.fecha.isBefore(hoy)).firstOrNull ?? clases.last;
  MotivoJustificativo? motivo;
  ArchivoAdjunto? respaldo;
  final detalleCtrl = TextEditingController();
  String? error;
  var enviando = false;

  final enviado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        Future<void> enviar() async {
          if (motivo == null) return setModal(() => error = 'Elige el motivo de tu inasistencia.');
          if (detalleCtrl.text.trim().isEmpty) {
            return setModal(() => error = 'Cuéntanos brevemente qué pasó.');
          }
          setModal(() {
            enviando = true;
            error = null;
          });
          final r = await repository.enviar(
            clase: clase,
            motivo: motivo!,
            explicacion: detalleCtrl.text,
            respaldo: respaldo,
          );
          if (!ctx.mounted) return;
          if (!r.ok) {
            return setModal(() {
              enviando = false;
              error = r.error;
            });
          }
          Navigator.pop(ctx, true);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                const Text('Justificar Inasistencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Elige la clase a la que faltarás o faltaste. El Equipo de Gestión de tu sede revisará tu solicitud.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 18),
                const Text('¿A qué clase?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: clase.claseId,
                      dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                      items: [
                        for (final c in clases)
                          DropdownMenuItem(
                            value: c.claseId,
                            child: Text(
                              c.etiqueta,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setModal(() => clase = clases.firstWhere((c) => c.claseId == v)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Motivo:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SelectorMotivoJustificativo(motivo: motivo, onCambiar: (m) => setModal(() => motivo = m)),
                const SizedBox(height: 16),
                const Text('Cuéntanos qué pasó:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: detalleCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Explica brevemente la razón de tu ausencia...'),
                ),
                const SizedBox(height: 8),
                CampoRespaldoJustificativo(
                  archivo: respaldo,
                  error: respaldo?.error,
                  onCambiar: (a) => setModal(() => respaldo = a),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: NinasProColors.error700, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: enviando ? null : enviar,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar Justificativo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  if (enviado == true) {
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.success700,
        content: Text('✅ Justificativo enviado al Equipo de Gestión de tu sede.'),
      ),
    );
    return true;
  }
  return false;
}

/// Los justificativos de la alumna con su estado y la observación de Gestión (US-17 escenario 2, US-37 escenario 3)
class MisJustificativosCard extends StatefulWidget {
  final JustificativosRepository repository;

  const MisJustificativosCard({super.key, required this.repository});

  @override
  State<MisJustificativosCard> createState() => _MisJustificativosCardState();
}

class _MisJustificativosCardState extends State<MisJustificativosCard> {
  List<JustificativoDetalle>? _lista;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await widget.repository.justificativos();
      if (!mounted) return;
      setState(() => _lista = lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lista = _lista;
    final secundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;

    return Card(
      elevation: 0,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Justificativos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_error)
              Text('No pudimos cargar tus justificativos.', style: TextStyle(fontSize: 12, color: secundario))
            else if (lista == null)
              const LinearProgressIndicator()
            else if (lista.isEmpty)
              Text(
                'Aún no has enviado justificativos. Si vas a faltar, toca "Justificar Falta".',
                style: TextStyle(fontSize: 12, color: secundario),
              )
            else
              for (final j in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${j.claseEtiqueta} · ${j.motivo.label}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          EtiquetaEstadoJustificativo(estado: j.estado),
                        ],
                      ),
                      if (j.observacion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Equipo de Gestión: ${j.observacion}',
                            style: TextStyle(fontSize: 12, color: secundario),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
