import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../repositories/alumnas_repository.dart';
import '../../utils/planilla.dart';
import '../../utils/rut.dart';
import '../directorio/directorio_widgets.dart';

/// Piezas compartidas por la carga masiva y la lista de conflictos pendientes
/// (US-07, US-08): tabla de filas con su diagnóstico, menú para resolver cada
/// una y editor de los datos de una fila.

/// Lo que se puede hacer con una fila que tiene conflictos o errores
enum AccionFila {
  corregir('Corregir datos', Icons.edit_rounded),
  usarEstaFila('Usar esta fila y descartar las repetidas', Icons.check_circle_outline_rounded),
  mantenerFicha('Mantener la ficha actual', Icons.person_rounded),
  actualizarFicha('Actualizar la ficha con la planilla', Icons.sync_rounded),
  sinCorreo('Inscribir sin correo', Icons.unsubscribe_rounded),
  descartar('Descartar fila', Icons.delete_outline_rounded),
  deshacer('Deshacer lo elegido', Icons.undo_rounded);

  final String label;
  final IconData icono;

  const AccionFila(this.label, this.icono);
}

/// Acciones que tienen sentido para la fila según su diagnóstico
List<AccionFila> accionesFila(FilaNomina f) {
  if (f.resolucion != null) return const [AccionFila.deshacer];
  if (f.estado == EstadoFilaNomina.inscrita) return const [AccionFila.descartar];
  if (!f.estado.porResolver) return const [];
  return [
    AccionFila.corregir,
    if (f.conflictos.contains(TipoConflicto.rutRepetido)) AccionFila.usarEstaFila,
    if (f.conflictos.contains(TipoConflicto.fichaDistinta)) ...[AccionFila.mantenerFicha, AccionFila.actualizarFicha],
    if (f.conflictos.contains(TipoConflicto.correoEnUso)) AccionFila.sinCorreo,
    AccionFila.descartar,
  ];
}

/// Resolución que corresponde a una acción (null para corregir y deshacer)
ResolucionFila? resolucionDe(AccionFila a) => switch (a) {
  AccionFila.mantenerFicha => ResolucionFila.mantenerFicha,
  AccionFila.actualizarFicha => ResolucionFila.actualizarFicha,
  AccionFila.sinCorreo => ResolucionFila.sinCorreo,
  AccionFila.descartar => ResolucionFila.descartar,
  _ => null,
};

/// Filas que comparten el RUT de [fila] (sin contarla)
Iterable<int> indicesRepetidos(List<FilaNomina> filas, int indice) {
  final rut = normalizarRut('${filas[indice].datos['rut'] ?? ''}');
  return [
    for (var i = 0; i < filas.length; i++)
      if (i != indice && rut.isNotEmpty && normalizarRut('${filas[i].datos['rut'] ?? ''}') == rut) i,
  ];
}

TonoChip tonoFila(EstadoFilaNomina e) => switch (e) {
  EstadoFilaNomina.nueva => TonoChip.exito,
  EstadoFilaNomina.existente => TonoChip.info,
  EstadoFilaNomina.inscrita => TonoChip.neutro,
  EstadoFilaNomina.conflicto => TonoChip.advertencia,
  EstadoFilaNomina.invalida => TonoChip.error,
  EstadoFilaNomina.descartada => TonoChip.neutro,
  EstadoFilaNomina.pendiente => TonoChip.advertencia,
};

/// Chips con el desglose de una revisión
class ResumenFilasNomina extends StatelessWidget {
  final List<FilaNomina> filas;

  const ResumenFilasNomina({super.key, required this.filas});

  @override
  Widget build(BuildContext context) {
    int contar(EstadoFilaNomina e) => filas.where((f) => f.estado == e).length;
    final porResolver = filas.where((f) => f.estado.porResolver).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DirectorioChip('${contar(EstadoFilaNomina.nueva)} nuevas', tono: TonoChip.exito),
        DirectorioChip('${contar(EstadoFilaNomina.existente)} ya tienen ficha', tono: TonoChip.info),
        if (contar(EstadoFilaNomina.inscrita) > 0)
          DirectorioChip('${contar(EstadoFilaNomina.inscrita)} ya inscritas en el curso'),
        DirectorioChip(
          '$porResolver por resolver',
          tono: porResolver == 0 ? TonoChip.neutro : TonoChip.advertencia,
          icono: porResolver == 0 ? null : Icons.warning_amber_rounded,
        ),
        if (contar(EstadoFilaNomina.descartada) > 0)
          DirectorioChip('${contar(EstadoFilaNomina.descartada)} descartadas'),
      ],
    );
  }
}

/// Tabla de filas con su estado, el detalle de cada conflicto y el menú para resolverlo
class TablaFilasNomina extends StatelessWidget {
  final List<FilaNomina> filas;
  final void Function(int indice, AccionFila accion)? onAccion;

  /// Texto de la primera columna (en los pendientes, el curso y el archivo)
  final String Function(FilaNomina fila)? origen;

  const TablaFilasNomina({super.key, required this.filas, this.onAccion, this.origen});

  @override
  Widget build(BuildContext context) {
    return DirectorioTabla(
      columnas: [if (origen != null) 'Origen', 'Fila', 'Alumna', 'RUT', 'Estado', 'Detalle', ''],
      mensajeVacio: 'No hay filas.',
      filas: [
        for (final (i, f) in filas.indexed)
          DataRow(
            cells: [
              if (origen != null) DataCell(Text(origen!(f), style: const TextStyle(fontSize: 12))),
              DataCell(Text('${f.numero}')),
              DataCell(Text(f.nombre.isEmpty ? '—' : f.nombre)),
              DataCell(Text(f.rut.isEmpty ? '—' : f.rut)),
              DataCell(DirectorioChip(f.estado.label, tono: tonoFila(f.estado))),
              DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: _Detalle(f))),
              DataCell(
                accionesFila(f).isEmpty || onAccion == null
                    ? const SizedBox.shrink()
                    : PopupMenuButton<AccionFila>(
                        tooltip: 'Resolver fila ${f.numero}',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (a) => onAccion!(i, a),
                        itemBuilder: (_) => [
                          for (final a in accionesFila(f))
                            PopupMenuItem(
                              value: a,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(a.icono, size: 18),
                                title: Text(a.label),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Detalle extends StatelessWidget {
  final FilaNomina fila;

  const _Detalle(this.fila);

  @override
  Widget build(BuildContext context) {
    final lineas = <String>[
      if (fila.resolucion != null) '✔ ${fila.resolucion!.label}',
      if (fila.motivo != null && fila.estado != EstadoFilaNomina.descartada) fila.motivo!,
      for (final d in fila.diferencias) '${d.campo}: «${d.ficha}» en la ficha, «${d.planilla}» en la planilla',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        lineas.isEmpty ? '—' : lineas.join('\n'),
        style: TextStyle(
          fontSize: 12,
          color: fila.estado.porResolver ? NinasProColors.warning700 : null,
        ),
      ),
    );
  }
}

/// Etiquetas de las columnas de la plantilla en el editor
const _etiquetasColumnas = {
  'rut': 'RUT',
  'nombres': 'Nombres',
  'apellidos': 'Apellidos',
  'fecha_nacimiento': 'Fecha de nacimiento (dd-mm-aaaa)',
  'correo': 'Correo de la alumna',
  'establecimiento': 'Establecimiento',
  'curso_escolar': 'Curso escolar',
  'rut_apoderado': 'RUT del apoderado/a',
  'nombres_apoderado': 'Nombres del apoderado/a',
  'apellidos_apoderado': 'Apellidos del apoderado/a',
  'telefono_apoderado': 'Teléfono del apoderado/a',
  'correo_apoderado': 'Correo del apoderado/a',
  'parentesco': 'Parentesco',
};

/// Edita los datos de una fila. Devuelve los datos corregidos, o null si se canceló.
Future<Map<String, Object?>?> editarFilaNomina(BuildContext context, FilaNomina fila) =>
    showDialog(context: context, builder: (_) => _EditorFila(fila: fila));

class _EditorFila extends StatefulWidget {
  final FilaNomina fila;

  const _EditorFila({required this.fila});

  @override
  State<_EditorFila> createState() => _EditorFilaState();
}

class _EditorFilaState extends State<_EditorFila> {
  late final Map<String, TextEditingController> _campos = {
    for (final clave in _etiquetasColumnas.keys)
      clave: TextEditingController(text: _inicial(clave, '${widget.fila.datos[clave] ?? ''}')),
  };

  /// La fecha ISO se muestra como dd-mm-aaaa
  static String _inicial(String clave, String valor) {
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(valor);
    return clave == 'fecha_nacimiento' && iso != null ? '${iso[3]}-${iso[2]}-${iso[1]}' : valor;
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final datos = <String, Object?>{...widget.fila.datos};
    for (final MapEntry(key: clave, value: c) in _campos.entries) {
      final texto = c.text.trim();
      datos[clave] = clave == 'fecha_nacimiento' ? fechaIso(texto) ?? texto : texto;
    }
    Navigator.pop(context, datos);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Corregir la fila ${widget.fila.numero}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fila.motivo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(widget.fila.motivo!, style: const TextStyle(color: NinasProColors.warning700)),
                ),
              for (final MapEntry(key: clave, value: etiqueta) in _etiquetasColumnas.entries)
                CampoFormulario(controller: _campos[clave]!, etiqueta: etiqueta),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Aplicar')),
      ],
    );
  }
}
