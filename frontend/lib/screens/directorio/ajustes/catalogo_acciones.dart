import 'package:flutter/material.dart';

/// Acciones compartidas por las vistas de Sedes y Cursos (US-01).

/// Botón de eliminar de una fila del catálogo. Si [usos] no está vacío queda
/// deshabilitado y su tooltip explica qué lo está usando.
class BotonEliminarCatalogo extends StatelessWidget {
  final String nombre;
  final List<String> usos;
  final VoidCallback onEliminar;

  const BotonEliminarCatalogo({super.key, required this.nombre, required this.usos, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final libre = usos.isEmpty;
    return IconButton(
      tooltip: libre ? 'Eliminar $nombre' : 'No se puede eliminar $nombre: tiene ${usos.join(', ')}',
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      onPressed: libre ? onEliminar : null,
    );
  }
}

/// Pide confirmar la eliminación; true si se confirma
Future<bool> confirmarEliminacion(BuildContext context, {required String titulo, required String nombre}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Avisa que el nombre se parece a otros ya registrados; true si se decide guardar igual
Future<bool> confirmarNombreParecido(
  BuildContext context, {
  required String nombre,
  required List<String> parecidos,
  required String tipo, // 'sede' | 'curso'
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Es un nombre nuevo?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"$nombre" se parece mucho a ${_otros(tipo, parecidos.length)}:'),
          const SizedBox(height: 8),
          for (final p in parecidos)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text('• $p', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          Text(
            tipo == 'sede'
                ? 'Si es la misma sede, cancela y edita la existente.'
                : 'Si es el mismo curso, cancela y edita el existente.',
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar igual')),
      ],
    ),
  );
  return ok == true;
}

/// 'otra sede registrada', 'otros cursos registrados'…
String _otros(String tipo, int cantidad) {
  final femenino = tipo == 'sede';
  if (cantidad == 1) return femenino ? 'otra sede registrada' : 'otro curso registrado';
  return femenino ? 'otras sedes registradas' : 'otros cursos registrados';
}
