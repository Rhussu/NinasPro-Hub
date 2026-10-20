import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../models/hub_models.dart';
import '../../../repositories/hub_repository.dart';
import '../directorio_widgets.dart';

/// Catálogo de roles semanales de tutoras (US-43): crear, editar y eliminar.
/// El Equipo de Gestión de cada sede asigna estos roles semana a semana.
class AjustesRolesView extends StatefulWidget {
  final HubRepository repository;

  const AjustesRolesView({super.key, required this.repository});

  @override
  State<AjustesRolesView> createState() => _AjustesRolesViewState();
}

class _AjustesRolesViewState extends State<AjustesRolesView> {
  bool _cargando = true;
  List<RolTutorConfig> _roles = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final roles = await widget.repository.getRolesTutora();
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([RolTutorConfig? rol]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRol(repository: widget.repository, rol: rol, roles: _roles),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, rol == null ? '✅ Rol creado.' : '✅ Rol actualizado.');
    _cargarDatos();
  }

  Future<void> _eliminar(RolTutorConfig rol) async {
    final asignaciones = await widget.repository.contarAsignacionesRol(rol.codigo);
    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${rol.nombre}"?'),
        content: Text(
          asignaciones == 0
              ? 'Ninguna tutora tiene este rol asignado.'
              : 'Se quitarán también $asignaciones asignaciones semanales de este rol.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await widget.repository.eliminarRolTutora(rol.codigo);
    if (!mounted) return;
    mostrarAviso(context, 'Rol eliminado.');
    _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Roles de tutoras',
          subtitulo: '${_roles.length} roles que Gestión asigna cada semana',
          acciones: [
            FilledButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo rol'),
            ),
          ],
        ),
        DirectorioPanel(
          child: DirectorioTabla(
            columnas: const ['Rol', 'Descripción', ''],
            filas: [
              for (final r in _roles)
                DataRow(cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: r.color),
                      const SizedBox(width: 10),
                      Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(r.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar ${r.nombre}',
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () => _abrirFormulario(r),
                      ),
                      IconButton(
                        tooltip: 'Eliminar ${r.nombre}',
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: NinasProColors.error700),
                        onPressed: () => _eliminar(r),
                      ),
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

class _DialogoRol extends StatefulWidget {
  final HubRepository repository;
  final RolTutorConfig? rol;
  final List<RolTutorConfig> roles;

  const _DialogoRol({required this.repository, required this.roles, this.rol});

  @override
  State<_DialogoRol> createState() => _DialogoRolState();
}

class _DialogoRolState extends State<_DialogoRol> {
  // Colores de la paleta de marca y estados, aptos para el punto de color del rol
  static const _colores = [
    '#FF78CF', '#8B3295', '#5A3295', '#95326D', '#1D5CA5', '#1D7C4D', '#E28F12', '#975F0C', '#AB212A', '#72637E',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.rol?.nombre);
  late final _descripcion = TextEditingController(text: widget.rol?.descripcion);
  late String _colorHex = widget.rol?.colorHex ?? _colores.first;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// Código estable derivado del nombre: 'Presentar el Kahoot' -> 'presentar_el_kahoot'
  String _codigoNuevo(String nombre) {
    const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    final base = nombre
        .trim()
        .toLowerCase()
        .split('')
        .map((c) => tildes[c] ?? c)
        .join()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    var codigo = base;
    var n = 2;
    while (widget.roles.any((r) => r.codigo == codigo)) {
      codigo = '${base}_${n++}';
    }
    return codigo;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final rol = RolTutorConfig(
      codigo: widget.rol?.codigo ?? _codigoNuevo(_nombre.text),
      nombre: _nombre.text.trim(),
      descripcion: _descripcion.text.trim(),
      colorHex: _colorHex,
      // Se conserva el valor de los roles existentes; los nuevos no son obligatorios
      esRequerido: widget.rol?.esRequerido ?? false,
    );
    final ok = widget.rol == null
        ? await widget.repository.crearRolTutora(rol)
        : await widget.repository.actualizarRolTutora(rol);
    if (mounted) Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rol == null ? 'Nuevo rol' : 'Editar rol'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoFormulario(
                controller: _nombre,
                etiqueta: 'Nombre del rol',
                validator: (v) {
                  final error = obligatorio(v);
                  if (error != null) return error;
                  final repetido = widget.roles.any((r) =>
                      r.codigo != widget.rol?.codigo && r.nombre.toLowerCase() == v!.trim().toLowerCase());
                  return repetido ? 'Ya existe un rol con ese nombre' : null;
                },
              ),
              CampoFormulario(controller: _descripcion, etiqueta: 'Qué hace la tutora', maxLineas: 2),
              const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hex in _colores)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _colorHex = hex),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: RolTutorConfig(codigo: '', nombre: '', descripcion: '', colorHex: hex).color,
                        child: _colorHex == hex
                            ? const Icon(Icons.check_rounded, size: 16, color: NinasProColors.white)
                            : null,
                      ),
                    ),
                ],
              ),
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
