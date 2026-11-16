import 'package:flutter/material.dart';
import '../../../config/ninaspro_colors.dart';
import '../../../repositories/roles_repository.dart';
import '../../../utils/nombres.dart';
import '../directorio_widgets.dart';

/// Catálogo de roles de las tutoras (US-43 escenario 1): crear, editar,
/// marcar como obligatorio, desactivar y eliminar. Gestión de cada sede asigna
/// estos roles en cada clase; una tutora puede tener varios.
class AjustesRolesView extends StatefulWidget {
  final RolesRepository repository;

  const AjustesRolesView({super.key, required this.repository});

  @override
  State<AjustesRolesView> createState() => _AjustesRolesViewState();
}

class _AjustesRolesViewState extends State<AjustesRolesView> {
  bool _cargando = true;
  String? _error;
  List<RolTarea> _roles = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final roles = await widget.repository.roles(incluirInactivos: true);
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar los roles. Revisa tu conexión.';
      });
    }
  }

  Future<void> _abrirFormulario([RolTarea? rol]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRol(repository: widget.repository, rol: rol, roles: _roles),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, rol == null ? '✅ Rol creado.' : '✅ Rol actualizado.');
    _cargarDatos();
  }

  Future<void> _eliminar(RolTarea rol) async {
    final usos = await widget.repository.usosRol(rol.id);
    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(usos == 0 ? '¿Eliminar "${rol.nombre}"?' : '¿Desactivar "${rol.nombre}"?'),
        content: Text(
          usos == 0
              ? 'Ninguna tutora ha tenido este rol: se elimina del catálogo.'
              : 'Este rol se ha asignado $usos ${usos == 1 ? 'vez' : 'veces'}. Para conservar el historial se '
                    'desactiva: deja de ofrecerse en las clases nuevas y puedes reactivarlo cuando quieras.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(usos == 0 ? 'Eliminar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final r = await widget.repository.eliminarRol(rol.id);
    if (!mounted) return;
    mostrarAviso(context, r.ok ? (usos == 0 ? 'Rol eliminado.' : 'Rol desactivado.') : r.error!, error: !r.ok);
    _cargarDatos();
  }

  Future<void> _reactivar(RolTarea rol) async {
    final r = await widget.repository.actualizarRol(rol.copyWith(activo: true));
    if (!mounted) return;
    mostrarAviso(context, r.ok ? '✅ "${rol.nombre}" vuelve a ofrecerse en las clases.' : r.error!, error: !r.ok);
    _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final activos = _roles.where((r) => r.activo).length;
    final obligatorios = _roles.where((r) => r.activo && r.esRequerido).length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Roles de tutoras',
          subtitulo: '$activos roles que Gestión asigna en cada clase · $obligatorios obligatorios',
          acciones: [
            FilledButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo rol'),
            ),
          ],
        ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
          const SizedBox(height: 12),
        ],
        DirectorioPanel(
          child: DirectorioTabla(
            columnas: const ['Rol', 'Descripción', 'Tipo', ''],
            filas: [
              for (final r in _roles)
                DataRow(cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: r.color),
                      const SizedBox(width: 10),
                      Text(
                        r.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: r.activo ? null : NinasProColors.neutral500,
                        ),
                      ),
                    ],
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(r.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(
                    !r.activo
                        ? const DirectorioChip('Inactivo', tono: TonoChip.neutro)
                        : r.esRequerido
                        ? const DirectorioChip('Obligatorio', tono: TonoChip.advertencia)
                        : const DirectorioChip('Opcional', tono: TonoChip.info),
                  ),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar ${r.nombre}',
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () => _abrirFormulario(r),
                      ),
                      if (r.activo)
                        IconButton(
                          tooltip: 'Eliminar ${r.nombre}',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: NinasProColors.error700),
                          onPressed: () => _eliminar(r),
                        )
                      else
                        IconButton(
                          tooltip: 'Reactivar ${r.nombre}',
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          onPressed: () => _reactivar(r),
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
  final RolesRepository repository;
  final RolTarea? rol;
  final List<RolTarea> roles;

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
  late bool _esRequerido = widget.rol?.esRequerido ?? false;
  bool _guardando = false;
  String? _error;

  Iterable<String> get _otrosNombres => widget.roles.where((r) => r.id != widget.rol?.id).map((r) => r.nombre);

  @override
  void initState() {
    super.initState();
    // El aviso de nombres parecidos se actualiza mientras se escribe
    _nombre.addListener(_alEscribir);
  }

  void _alEscribir() => setState(() {});

  @override
  void dispose() {
    _nombre.removeListener(_alEscribir);
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final base = widget.rol ?? const RolTarea(id: '', nombre: '');
    final rol = base.copyWith(
      nombre: _nombre.text.trim(),
      descripcion: _descripcion.text.trim(),
      colorHex: _colorHex,
      esRequerido: _esRequerido,
    );
    final error = widget.rol == null
        ? (await widget.repository.crearRol(rol)).error
        : (await widget.repository.actualizarRol(rol)).error;
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parecidos = nombresParecidos(_nombre.text, _otrosNombres);

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
                  final repetido = nombreRepetido(v!, _otrosNombres);
                  return repetido == null ? null : 'Ya existe el rol "$repetido"';
                },
              ),
              if (parecidos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Se parece a: ${parecidos.join(', ')}. Revisa que no sea el mismo rol.',
                    style: const TextStyle(fontSize: 12, color: NinasProColors.warning700),
                  ),
                ),
              CampoFormulario(controller: _descripcion, etiqueta: 'Qué hace la tutora', maxLineas: 2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Obligatorio en cada clase'),
                subtitle: const Text('Gestión verá un aviso si nadie lo tiene asignado'),
                value: _esRequerido,
                onChanged: (v) => setState(() => _esRequerido = v),
              ),
              const SizedBox(height: 4),
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
                        backgroundColor: RolTarea(id: '', nombre: '', colorHex: hex).color,
                        child: _colorHex == hex
                            ? const Icon(Icons.check_rounded, size: 16, color: NinasProColors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
