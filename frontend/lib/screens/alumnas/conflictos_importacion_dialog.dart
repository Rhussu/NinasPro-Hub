import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../repositories/alumnas_repository.dart';
import '../../utils/rut.dart';
import 'filas_nomina.dart';

/// Filas que quedaron sin resolver en cargas anteriores (US-07, US-08). Cada
/// acción se aplica de inmediato: la fila se inscribe, sigue pendiente con su
/// diagnóstico nuevo o se descarta. Devuelve true si cambió algo.
Future<bool?> mostrarConflictosImportacion(BuildContext context, {required AlumnasRepository repository}) =>
    showDialog<bool>(context: context, builder: (_) => _ConflictosDialog(repository: repository));

class _ConflictosDialog extends StatefulWidget {
  final AlumnasRepository repository;

  const _ConflictosDialog({required this.repository});

  @override
  State<_ConflictosDialog> createState() => _ConflictosDialogState();
}

class _ConflictosDialogState extends State<_ConflictosDialog> {
  List<ConflictoImportacion> _conflictos = [];
  List<FilaNomina>? _filas;
  bool _procesando = false;
  bool _cambios = false;
  String? _error;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _procesando = true);
    final conflictos = await widget.repository.conflictosPendientes();
    final r = conflictos.isEmpty
        ? const ResultadoAlumnas<List<FilaNomina>>.ok([])
        : await widget.repository.revisarConflictos(conflictos);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _conflictos = conflictos;
      _filas = r.valor;
      _error = r.error;
    });
  }

  Future<void> _accion(int indice, AccionFila accion) async {
    final conflicto = _conflictos[indice];
    var fila = _filas![indice];
    setState(() {
      _error = null;
      _aviso = null;
    });

    if (accion == AccionFila.descartar) {
      await _aplicar(() => widget.repository.descartarConflicto(conflicto.id), 'Fila ${conflicto.numeroFila} descartada.');
      return;
    }
    if (accion == AccionFila.usarEstaFila) {
      // Se descartan los otros pendientes del mismo curso con este RUT
      final rut = normalizarRut('${fila.datos['rut'] ?? ''}');
      final otros = [
        for (final c in _conflictos)
          if (c.id != conflicto.id && c.instanciaId == conflicto.instanciaId && normalizarRut('${c.datos['rut'] ?? ''}') == rut) c,
      ];
      for (final c in otros) {
        final r = await widget.repository.descartarConflicto(c.id);
        if (!r.ok) return _fallo(r.error);
      }
    }
    if (!mounted) return;
    if (accion == AccionFila.corregir) {
      final datos = await editarFilaNomina(context, fila);
      if (datos == null) return;
      fila = fila.conDatos(datos);
    } else {
      fila = fila.conResolucion(resolucionDe(accion));
    }

    setState(() => _procesando = true);
    final r = await widget.repository.resolverConflicto(conflicto, fila);
    if (!mounted) return;
    final resultado = r.valor;
    if (resultado == null) return _fallo(r.error);
    _cambios = true;
    _aviso = switch (resultado.estado) {
      EstadoFilaNomina.nueva || EstadoFilaNomina.existente => '✅ ${resultado.nombre} quedó inscrita.',
      EstadoFilaNomina.inscrita => '${resultado.nombre} ya estaba inscrita en el curso: se quitó de pendientes.',
      _ => 'La fila ${conflicto.numeroFila} sigue pendiente: ${resultado.motivo ?? ''}',
    };
    await _cargar();
  }

  Future<void> _aplicar(Future<ResultadoAlumnas<void>> Function() operacion, String aviso) async {
    setState(() => _procesando = true);
    final r = await operacion();
    if (!mounted) return;
    if (!r.ok) return _fallo(r.error);
    _cambios = true;
    _aviso = aviso;
    await _cargar();
  }

  void _fallo(String? error) => setState(() {
    _procesando = false;
    _error = error;
  });

  String _origen(FilaNomina f) {
    final c = _conflictos.firstWhere((c) => c.id == f.conflictoId);
    return [c.cursoEtiqueta, if (c.archivo != null) c.archivo!].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filas;
    return AlertDialog(
      title: const Text('Conflictos de importación'),
      content: SizedBox(
        width: 1040,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filas que quedaron sin resolver al cargar una nómina. Resuélvelas con el menú ⋯: '
                'al quedar sin conflictos se inscriben en su curso.',
                style: TextStyle(fontSize: 12.5, color: NinasProColors.neutral500),
              ),
              const SizedBox(height: 12),
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_aviso!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              if (_procesando) const LinearProgressIndicator(),
              if (filas != null && filas.isEmpty && !_procesando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('✅ No quedan conflictos pendientes.')),
                )
              else if (filas != null)
                TablaFilasNomina(filas: filas, origen: _origen, onAccion: _procesando ? null : _accion),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context, _cambios), child: const Text('Cerrar')),
      ],
    );
  }
}

/// Botón de la nómina que abre los conflictos pendientes; no se muestra si no hay
class BotonConflictosImportacion extends StatelessWidget {
  final int cantidad;
  final VoidCallback onPressed;

  const BotonConflictosImportacion({super.key, required this.cantidad, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (cantidad == 0) return const SizedBox.shrink();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: NinasProColors.warning700),
      onPressed: onPressed,
      icon: const Icon(Icons.rule_rounded, size: 18),
      label: Text('Conflictos de importación ($cantidad)'),
    );
  }
}
