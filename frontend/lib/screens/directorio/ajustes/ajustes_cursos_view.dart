import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/catalogo_repository.dart';
import '../../../utils/nombres.dart';
import '../directorio_widgets.dart';
import 'catalogo_acciones.dart';

/// Catálogo general de cursos (US-01): código institucional único y nombre obligatorio.
/// Cada curso del catálogo se dicta en una sede mediante una instancia (US-02).
/// Se avisa si el nombre se parece al de otro curso y solo se eliminan los
/// cursos que aún no tienen instancias.
class AjustesCursosView extends StatefulWidget {
  final CatalogoRepository repository;

  const AjustesCursosView({super.key, required this.repository});

  @override
  State<AjustesCursosView> createState() => _AjustesCursosViewState();
}

class _AjustesCursosViewState extends State<AjustesCursosView> {
  bool _cargando = true;
  List<CursoCatalogo> _catalogo = [];
  List<Curso> _instancias = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final catalogo = await widget.repository.cursos();
    final instancias = await widget.repository.instancias();
    if (!mounted) return;
    setState(() {
      _catalogo = catalogo;
      _instancias = instancias;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([CursoCatalogo? curso]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCurso(
        repository: widget.repository,
        curso: curso,
        otrosCursos: [for (final c in _catalogo) if (c.id != curso?.id) c],
      ),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, curso == null ? '✅ Curso agregado al catálogo.' : '✅ Curso actualizado.');
    _cargarDatos();
  }

  Future<void> _eliminar(CursoCatalogo curso) async {
    final nombre = '${curso.codigo} · ${curso.nombre}';
    if (!await confirmarEliminacion(context, titulo: 'Eliminar curso', nombre: nombre) || !mounted) return;
    final resultado = await widget.repository.eliminarCurso(curso.id);
    if (!mounted) return;
    if (resultado.ok) {
      mostrarAviso(context, 'Curso ${curso.codigo} eliminado del catálogo.');
      _cargarDatos();
    } else {
      mostrarAviso(context, resultado.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Cursos',
          subtitulo: 'Catálogo general. Para dictarlo en una sede, crea una instancia.',
          acciones: [
            FilledButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo curso'),
            ),
          ],
        ),
        DirectorioPanel(
          child: DirectorioTabla(
            columnas: const ['Código', 'Nombre', 'Descripción', 'Instancias', ''],
            filas: [
              for (final c in _catalogo)
                DataRow(cells: [
                  DataCell(DirectorioChip(c.codigo)),
                  DataCell(Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(c.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text('${_instancias.where((i) => i.catalogoId == c.id).length}')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar ${c.nombre}',
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () => _abrirFormulario(c),
                      ),
                      BotonEliminarCatalogo(nombre: c.nombre, usos: c.usos, onEliminar: () => _eliminar(c)),
                    ],
                  )),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogoCurso extends StatefulWidget {
  final CatalogoRepository repository;
  final CursoCatalogo? curso;

  /// Los demás cursos del catálogo, para detectar códigos repetidos y nombres parecidos
  final List<CursoCatalogo> otrosCursos;

  const _DialogoCurso({required this.repository, this.curso, this.otrosCursos = const []});

  @override
  State<_DialogoCurso> createState() => _DialogoCursoState();
}

class _DialogoCursoState extends State<_DialogoCurso> {
  final _formKey = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.curso?.codigo);
  late final _nombre = TextEditingController(text: widget.curso?.nombre);
  late final _descripcion = TextEditingController(text: widget.curso?.descripcion);
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final codigo = _codigo.text.trim().toUpperCase();
    final codigoRepetido = nombreRepetido(codigo, [for (final c in widget.otrosCursos) c.codigo]);
    if (codigoRepetido != null) {
      setState(
        () => _error = codigoRepetido == codigo
            ? 'El código "$codigo" ya está en uso.'
            : 'El código "$codigo" ya está en uso como "$codigoRepetido".',
      );
      return;
    }
    final nombre = _nombre.text.trim();
    final cambioNombre = widget.curso == null || claveNombre(widget.curso!.nombre) != claveNombre(nombre);
    final nombres = [for (final c in widget.otrosCursos) c.nombre];
    final parecidos = cambioNombre
        ? [?nombreRepetido(nombre, nombres), ...nombresParecidos(nombre, nombres)]
        : const <String>[];
    if (parecidos.isNotEmpty) {
      final guardar = await confirmarNombreParecido(context, nombre: nombre, parecidos: parecidos, tipo: 'curso');
      if (!guardar || !mounted) return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = DatosCurso(codigo: _codigo.text, nombre: _nombre.text, descripcion: _descripcion.text);
    final curso = widget.curso;
    final resultado = curso == null
        ? await widget.repository.crearCurso(datos)
        : await widget.repository.actualizarCurso(curso.id, datos);
    if (!mounted) return;
    if (resultado.ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _error = resultado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.curso == null ? 'Nuevo curso' : 'Editar curso'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CampoFormulario(
                controller: _codigo,
                etiqueta: 'Código institucional',
                ayuda: 'Único, por ejemplo PCB',
                validator: obligatorio,
              ),
              CampoFormulario(controller: _nombre, etiqueta: 'Nombre', validator: obligatorio),
              CampoFormulario(controller: _descripcion, etiqueta: 'Descripción', maxLineas: 3),
              if (_error != null) Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
