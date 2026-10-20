import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/hub_repository.dart';
import '../directorio_widgets.dart';

/// Administración de sedes e instituciones anfitrionas (US-01).
/// El nombre de la sede es único.
class AjustesSedesView extends StatefulWidget {
  final HubRepository repository;

  const AjustesSedesView({super.key, required this.repository});

  @override
  State<AjustesSedesView> createState() => _AjustesSedesViewState();
}

class _AjustesSedesViewState extends State<AjustesSedesView> {
  bool _cargando = true;
  List<Sede> _sedes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final sedes = await widget.repository.getSedes();
    if (!mounted) return;
    setState(() {
      _sedes = sedes;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([Sede? sede]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoSede(repository: widget.repository, sede: sede),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, sede == null ? '✅ Sede creada y activa.' : '✅ Sede actualizada.');
    _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Sedes',
          subtitulo: 'Sedes territoriales e instituciones anfitrionas',
          acciones: [
            FilledButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva sede'),
            ),
          ],
        ),
        DirectorioPanel(
          child: DirectorioTabla(
            columnas: const ['Sede', 'Institución anfitriona', 'Región', 'Modalidad', 'Coordinadora', 'Estado', ''],
            filas: [
              for (final s in _sedes)
                DataRow(cells: [
                  DataCell(Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text(s.universidad)),
                  DataCell(Text(s.region)),
                  DataCell(Text(s.modalidad)),
                  DataCell(Text(s.coordinadoraNombre)),
                  DataCell(DirectorioChip(etiquetaEstado(s.estado), tono: tonoEstado(s.estado))),
                  DataCell(IconButton(
                    tooltip: 'Editar ${s.nombre}',
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => _abrirFormulario(s),
                  )),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogoSede extends StatefulWidget {
  final HubRepository repository;
  final Sede? sede;

  const _DialogoSede({required this.repository, this.sede});

  @override
  State<_DialogoSede> createState() => _DialogoSedeState();
}

class _DialogoSedeState extends State<_DialogoSede> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.sede?.nombre);
  late final _universidad = TextEditingController(text: widget.sede?.universidad);
  late final _region = TextEditingController(text: widget.sede?.region);
  late final _coordinadora = TextEditingController(text: widget.sede?.coordinadoraNombre);
  late String _modalidad = widget.sede?.modalidad ?? 'Presencial';
  late bool _activa = (widget.sede?.estado ?? 'activa') == 'activa';
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _universidad, _region, _coordinadora]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final sede = widget.sede;
    final ok = sede == null
        ? await widget.repository.crearSede(
            nombre: _nombre.text,
            universidad: _universidad.text,
            region: _region.text,
            modalidad: _modalidad,
            coordinadoraNombre: _coordinadora.text,
          )
        : await widget.repository.actualizarSede(
            sede.copyWith(
              nombre: _nombre.text.trim(),
              universidad: _universidad.text.trim(),
              region: _region.text.trim(),
              modalidad: _modalidad,
              coordinadoraNombre: _coordinadora.text.trim(),
              estado: _activa ? 'activa' : 'inactiva',
            ),
          );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Ya existe una sede llamada "${_nombre.text.trim()}".');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.sede == null ? 'Nueva sede' : 'Editar sede'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CampoFormulario(controller: _nombre, etiqueta: 'Nombre de la sede', validator: obligatorio),
                CampoFormulario(controller: _universidad, etiqueta: 'Institución anfitriona', validator: obligatorio),
                CampoFormulario(controller: _region, etiqueta: 'Región', validator: obligatorio),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Presencial', label: Text('Presencial')),
                      ButtonSegment(value: 'Online', label: Text('Online')),
                    ],
                    selected: {_modalidad},
                    onSelectionChanged: (s) => setState(() => _modalidad = s.first),
                  ),
                ),
                CampoFormulario(controller: _coordinadora, etiqueta: 'Coordinadora', validator: obligatorio),
                if (widget.sede != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sede activa'),
                    value: _activa,
                    onChanged: (v) => setState(() => _activa = v),
                  ),
                if (_error != null) Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ],
            ),
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
