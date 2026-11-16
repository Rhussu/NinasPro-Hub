import 'package:flutter/material.dart';

import '../../models/hub_models.dart';
import '../../widgets/ninaspro_recursos_curso.dart';
import '../ajustes/accesos_rol.dart';
import 'clase_sesion_controller.dart';
import 'clase_sesion_views.dart';
import 'inicio_tutora_widgets.dart';

/// Entradas de Ajustes que comparten Tutora y Gestión (todas las de Gestión
/// también son tutoras): la clase de hoy y los recursos del curso.

/// Pide el curso en un diálogo; null si se cancela
Future<String?> elegirCursoClase(BuildContext context, List<Curso> cursos, String? cursoId) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Elige el curso'),
      children: [
        for (final c in cursos)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c.id),
            child: Row(
              children: [
                Icon(c.id == cursoId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(etiquetaCursoClase(c))),
              ],
            ),
          ),
      ],
    ),
  );
}

/// La clase de hoy: el curso (si opera más de uno) y las mismas acciones del Speed Dial
List<AccesoRol> accesosClaseDeHoy(
  BuildContext context,
  ClaseSesionController clase, {
  required Future<void> Function(String instanciaId) onElegirCurso,
  required Future<void> Function() abrirAsistencia,
  required Future<void> Function() abrirEjercicios,
  required Future<void> Function() abrirFotos,
}) {
  final curso = clase.curso;
  final sesion = clase.sesionActual;
  return [
    if (clase.cursos.length > 1)
      AccesoRol(
        icono: Icons.swap_horiz_rounded,
        titulo: 'Curso',
        subtitulo: curso == null ? 'Elige el curso' : etiquetaCursoClase(curso),
        abrir: () async {
          final id = await elegirCursoClase(context, clase.cursos, curso?.id);
          if (id != null) await onElegirCurso(id);
        },
      ),
    AccesoRol(
      icono: Icons.fact_check_rounded,
      titulo: 'Asistencia',
      subtitulo: sesion == null
          ? 'Pase de lista, historial y correcciones'
          : 'Clase ${sesion.numeroSesion}: pase de lista, historial, correcciones y justificativos',
      abrir: abrirAsistencia,
    ),
    AccesoRol(
      icono: Icons.code_rounded,
      titulo: 'Ejercicios',
      subtitulo: 'Los ejercicios resueltos de cada alumna',
      abrir: abrirEjercicios,
    ),
    AccesoRol(icono: Icons.camera_alt_rounded, titulo: 'Fotos', subtitulo: 'Evidencia de la clase', abrir: abrirFotos),
    AccesoRol(
      icono: Icons.emoji_events_rounded,
      titulo: 'Podio Kahoot',
      subtitulo: 'Los primeros lugares de la clase',
      abrir: () => mostrarModalRegistroKahoot(context, clase),
    ),
  ];
}

/// Classroom y Juez Virtual del curso (US-26); null si el curso no tiene enlaces
AccesoRol? accesoRecursosCurso(BuildContext context, Curso? curso) {
  if (curso == null || (curso.classroomUrl == null && curso.juezVirtualUrl == null)) return null;
  return AccesoRol(
    icono: Icons.link_rounded,
    titulo: 'Recursos del curso',
    subtitulo: 'Classroom y Juez Virtual',
    abrir: () => abrirPantallaSecundaria(
      context,
      'Recursos del curso',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [NinasProRecursosCursoCard(curso: curso)],
      ),
    ),
  );
}
