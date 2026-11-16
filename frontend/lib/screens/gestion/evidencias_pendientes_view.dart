import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../repositories/evidencias_repository.dart';

/// Clases realizadas hace más de 48 horas sin foto de evidencia (US-20).

/// Una clase sin foto, con sus tutoras para recordarles
class TarjetaEvidenciaPendiente extends StatelessWidget {
  final EvidenciaPendiente evidencia;

  const TarjetaEvidenciaPendiente({super.key, required this.evidencia});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;
    final e = evidencia;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NinasProColors.accent500, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.cursoNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Text(
                  e.demora,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NinasProColors.accent900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [e.claseEtiqueta, e.tema, e.sedeNombre].whereType<String>().join(' · '),
              style: TextStyle(fontSize: 11.5, color: secundario),
            ),
            if (e.tutoras != null) ...[
              const SizedBox(height: 6),
              Text('Recordar a: ${e.tutoras}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Todas las clases sin foto tras 48 horas, en una pantalla propia
class EvidenciasPendientesView extends StatelessWidget {
  final List<EvidenciaPendiente> pendientes;

  const EvidenciasPendientesView({super.key, required this.pendientes});

  @override
  Widget build(BuildContext context) {
    if (pendientes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todas las clases realizadas tienen su foto de evidencia.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pendientes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TarjetaEvidenciaPendiente(evidencia: pendientes[i]),
    );
  }
}
