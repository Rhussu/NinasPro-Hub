import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/hub_repository.dart';
import '../directorio_widgets.dart';

/// Catálogo general de cursos (US-01): código institucional único y nombre obligatorio.
/// Cada curso del catálogo se dicta en una sede mediante una instancia (US-02).
class AjustesCursosView extends StatefulWidget {
  final HubRepository repository;

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
    final catalogo = await widget.repository.getCatalogoCursos();
    final instancias = await widget.repository.getCursos();
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
      builder: (_) => _DialogoCurso(repository: widget.repository, curso: curso),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, curso == null ? '✅ Curso agregado al catálogo.' : '✅ Curso actualizado.');
    _cargarDatos();
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
                  DataCell(IconButton(
                    tooltip: 'Editar ${c.nombre}',
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => _abrirFormulario(c),
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
  final HubRepository repository;
  final CursoCatalogo? curso;

  const _DialogoCurso({required this.repository, this.curso});

  @override
  State<_DialogoCurso> createState() => _DialogoCursoState();
}

class _DialogoCursoState extends State<_DialogoCurso> {
  final _formKey = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.curso?.codigo);
  late final _nombre = TextEditingController(text: widget.curso?.nombre);
  late final _descripcion = TextEditingController(text: widget.curso?.descripcion);
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final curso = widget.curso;
    final ok = curso == null
        ? await widget.repository.crearCursoCatalogo(
            codigo: _codigo.text,
            nombre: _nombre.text,
            descripcion: _descripcion.text,
          )
        : await widget.repository.actualizarCursoCatalogo(
            curso.copyWith(codigo: _codigo.text, nombre: _nombre.text, descripcion: _descripcion.text.trim()),
          );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'El código "${_codigo.text.trim().toUpperCase()}" ya está en uso.');
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
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
