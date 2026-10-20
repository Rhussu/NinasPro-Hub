import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';
import '../models/hub_models.dart';

/// Fecha larga de una clase, p. ej. «Sábado 25 de Abril».
String formatearFechaClase(DateTime fecha) {
  const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  return '${dias[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}';
}

/// Planificación de la clase de hoy: número, fecha, tema y materiales.
/// Se muestra dentro del banner de bienvenida de Alumna, Tutora y Gestión.
class NinasProPlanificacionHoy extends StatelessWidget {
  final SesionClase sesion;

  const NinasProPlanificacionHoy({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? NinasProColors.dark900 : NinasProColors.white).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clase ${sesion.numeroSesion} · ${formatearFechaClase(sesion.fecha)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NinasProColors.brandPink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hoy toca: ${sesion.tema}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          if (sesion.recursos.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final recurso in sesion.recursos)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        recurso.titulo,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
