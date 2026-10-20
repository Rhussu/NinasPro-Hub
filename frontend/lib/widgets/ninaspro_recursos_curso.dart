import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/ninaspro_colors.dart';
import '../models/hub_models.dart';

/// Tarjeta con los recursos del curso: un único Classroom y Juez Virtual por curso (US-26).
///
/// La usan la Alumna (su curso) y el Equipo de Gestión (el curso de su sede).
/// No muestra nada si el curso no tiene enlaces configurados.
class NinasProRecursosCursoCard extends StatelessWidget {
  final Curso curso;

  const NinasProRecursosCursoCard({super.key, required this.curso});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (curso.classroomUrl == null && curso.juezVirtualUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(Icons.folder_special_rounded, color: NinasProColors.brandPink, size: 18),
                SizedBox(width: 6),
                Text(
                  'Recursos del Curso',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (curso.classroomUrl != null)
            _EnlaceCurso(
              icono: Icons.school_rounded,
              titulo: 'Google Classroom',
              url: curso.classroomUrl!,
            ),
          if (curso.classroomUrl != null && curso.juezVirtualUrl != null)
            Divider(
              height: 1,
              indent: 62,
              color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
            ),
          if (curso.juezVirtualUrl != null)
            _EnlaceCurso(
              icono: Icons.terminal_rounded,
              titulo: 'Juez Virtual',
              url: curso.juezVirtualUrl!,
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// Fila de enlace del curso: tocar abre el enlace; botones para copiar y abrir
class _EnlaceCurso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String url;

  const _EnlaceCurso({required this.icono, required this.titulo, required this.url});

  Future<void> _abrirEnlace(BuildContext context) async {
    final abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (abierto || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.error700,
        content: Text('No se pudo abrir el enlace.'),
      ),
    );
  }

  Future<void> _copiarEnlace(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.primary700,
        content: Text('📋 Enlace copiado al portapapeles.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urlVisible = url.replaceFirst(RegExp(r'^https?://'), '');

    return InkWell(
      onTap: () => _abrirEnlace(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NinasProColors.primary700.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: NinasProColors.brandPink, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    urlVisible,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar enlace',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () => _copiarEnlace(context),
            ),
            IconButton(
              tooltip: 'Abrir enlace',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: NinasProColors.brandPink),
              onPressed: () => _abrirEnlace(context),
            ),
          ],
        ),
      ),
    );
  }
}
