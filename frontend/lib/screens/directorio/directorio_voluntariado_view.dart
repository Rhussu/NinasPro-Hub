import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../utils/rut.dart';
import 'directorio_importacion_dialog.dart';
import 'directorio_widgets.dart';

/// Directorio nacional de voluntariado (US-30, US-31, US-32).
///
/// Filtros por sede, rol y estado; alta manual y carga masiva simulada; ficha con la
/// declaración de adhesión, asignación a cursos (bloqueada sin adhesión) y registro de salida.
class DirectorioVoluntariadoView extends StatefulWidget {
  final HubRepository repository;

  const DirectorioVoluntariadoView({super.key, required this.repository});

  @override
  State<DirectorioVoluntariadoView> createState() => _DirectorioVoluntariadoViewState();
}

class _DirectorioVoluntariadoViewState extends State<DirectorioVoluntariadoView> {
  bool _cargando = true;
  List<Tutora> _voluntarias = [];
  List<Sede> _sedes = [];
  List<Curso> _cursos = [];

  String? _sedeId;
  String? _rol;
  String? _estado = 'activa';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final voluntarias = await widget.repository.getTutoras();
    final sedes = await widget.repository.getSedes();
    final cursos = await widget.repository.getCursos();
    if (!mounted) return;
    setState(() {
      _voluntarias = voluntarias;
      _sedes = sedes;
      _cursos = cursos;
      _cargando = false;
    });
  }

  List<Tutora> get _filtradas => _voluntarias.where((t) {
        if (_sedeId != null && t.sedeId != _sedeId) return false;
        if (_rol != null && t.rolVoluntariado != _rol) return false;
        if (_estado != null && t.estado != _estado) return false;
        return true;
      }).toList();

  String _codigoCurso(String cursoId) =>
      _cursos.where((c) => c.id == cursoId).firstOrNull?.codigo ?? cursoId;

  Future<void> _cargaMasiva() async {
    final creadas = await mostrarDialogoImportacion(
      context,
      titulo: 'Carga masiva de voluntariado',
      etiquetaDestino: 'Sede de destino',
      destinos: {for (final s in _sedes) s.id: s.nombre},
      columnasPlantilla: const ['nombre', 'rut', 'correo', 'institucion', 'rol'],
      etiquetaDetalle: 'Institución / ocupación',
      previsualizar: (_, columnasValidas) =>
          widget.repository.previsualizarImportacionVoluntariado(columnasValidas: columnasValidas),
      confirmar: (sedeId) => widget.repository.confirmarImportacionVoluntariado(sedeId: sedeId),
    );
    if (creadas == null || !mounted) return;
    mostrarAviso(context, '✅ $creadas fichas de voluntariado creadas (adhesión pendiente).');
    _cargarDatos();
  }

  Future<void> _altaManual() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAltaVoluntaria(repository: widget.repository, sedes: _sedes),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, '✅ Ficha creada. Falta registrar su declaración de adhesión.');
    _cargarDatos();
  }

  void _exportar() {
    mostrarAviso(
      context,
      '📄 voluntariado.xlsx generado con ${_filtradas.length} filas (mockup: sin descarga real).',
    );
  }

  Future<void> _abrirFicha(Tutora voluntaria) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FichaVoluntariaDialog(
        repository: widget.repository,
        voluntariaId: voluntaria.id,
        cursos: _cursos,
      ),
    );
    if (mounted) _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final filtradas = _filtradas;
    final sinAdhesion = _voluntarias.where((t) => t.estado == 'activa' && !t.adhesionFirmada).length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Voluntariado',
          subtitulo: '${_voluntarias.where((t) => t.estado == 'activa').length} voluntarias activas · '
              '$sinAdhesion sin declaración de adhesión',
          acciones: [
            OutlinedButton.icon(
              onPressed: _exportar,
              icon: const Icon(Icons.file_download_rounded, size: 18),
              label: const Text('Exportar'),
            ),
            OutlinedButton.icon(
              onPressed: _cargaMasiva,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Carga masiva'),
            ),
            FilledButton.icon(
              onPressed: _altaManual,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Nueva voluntaria'),
            ),
          ],
        ),
        DirectorioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FiltroDesplegable<String>(
                    etiqueta: 'Sede',
                    valor: _sedeId,
                    opciones: {for (final s in _sedes) s.id: s.nombre},
                    onChanged: (v) => setState(() => _sedeId = v),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Rol',
                    valor: _rol,
                    opciones: const {'Tutora': 'Tutora', 'Equipo de Gestión': 'Equipo de Gestión'},
                    onChanged: (v) => setState(() => _rol = v),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Estado',
                    valor: _estado,
                    opciones: const {'activa': 'Activa', 'retirada': 'Retirada'},
                    onChanged: (v) => setState(() => _estado = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DirectorioTabla(
                columnas: const ['Voluntaria', 'RUT', 'Sede', 'Rol', 'Ingreso', 'Cursos', 'Adhesión', 'Estado'],
                filas: [
                  for (final t in filtradas)
                    DataRow(
                      onSelectChanged: (_) => _abrirFicha(t),
                      cells: [
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(t.correo, style: const TextStyle(fontSize: 11.5, color: NinasProColors.neutral500)),
                          ],
                        )),
                        DataCell(Text(t.rut)),
                        DataCell(Text(t.sedeNombre)),
                        DataCell(Text(t.rolVoluntariado)),
                        DataCell(Text(formatearFecha(t.fechaIngreso))),
                        DataCell(Text(t.cursoIds.map(_codigoCurso).join(', '))),
                        DataCell(t.adhesionFirmada
                            ? const DirectorioChip('Firmada', tono: TonoChip.exito, icono: Icons.verified_rounded)
                            : const DirectorioChip('Pendiente', tono: TonoChip.advertencia)),
                        DataCell(DirectorioChip(etiquetaEstado(t.estado), tono: tonoEstado(t.estado))),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Alta manual individual de una voluntaria (US-30)
class _DialogoAltaVoluntaria extends StatefulWidget {
  final HubRepository repository;
  final List<Sede> sedes;

  const _DialogoAltaVoluntaria({required this.repository, required this.sedes});

  @override
  State<_DialogoAltaVoluntaria> createState() => _DialogoAltaVoluntariaState();
}

class _DialogoAltaVoluntariaState extends State<_DialogoAltaVoluntaria> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _rut = TextEditingController();
  final _correo = TextEditingController();
  final _institucion = TextEditingController();
  late String _sedeId = widget.sedes.first.id;
  bool _esEquipoGestion = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _rut, _correo, _institucion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.repository.crearVoluntaria(
      nombre: _nombre.text,
      rut: _rut.text,
      correo: _correo.text,
      institucion: _institucion.text,
      sedeId: _sedeId,
      esEquipoGestion: _esEquipoGestion,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Ya existe una ficha con ese RUT.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva voluntaria'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CampoFormulario(controller: _nombre, etiqueta: 'Nombre completo', validator: obligatorio),
                CampoFormulario(
                  controller: _rut,
                  etiqueta: 'RUT',
                  validator: (v) => obligatorio(v) ?? (validarRut(v!) ? null : 'RUT inválido (revisa el dígito verificador)'),
                ),
                CampoFormulario(
                  controller: _correo,
                  etiqueta: 'Correo',
                  teclado: TextInputType.emailAddress,
                  validator: (v) => obligatorio(v) ?? (v!.contains('@') ? null : 'Correo inválido'),
                ),
                CampoFormulario(controller: _institucion, etiqueta: 'Institución u ocupación', validator: obligatorio),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _sedeId,
                    decoration: const InputDecoration(labelText: 'Sede', border: OutlineInputBorder()),
                    items: [for (final s in widget.sedes) DropdownMenuItem(value: s.id, child: Text(s.nombre))],
                    onChanged: (v) => setState(() => _sedeId = v ?? _sedeId),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Tutora')),
                    ButtonSegment(value: true, label: Text('Equipo de Gestión')),
                  ],
                  selected: {_esEquipoGestion},
                  onSelectionChanged: (s) => setState(() => _esEquipoGestion = s.first),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Crear ficha')),
      ],
    );
  }
}

/// Ficha de la voluntaria: adhesión (US-31), asignación a cursos y salida (US-32)
class _FichaVoluntariaDialog extends StatefulWidget {
  final HubRepository repository;
  final String voluntariaId;
  final List<Curso> cursos;

  const _FichaVoluntariaDialog({required this.repository, required this.voluntariaId, required this.cursos});

  @override
  State<_FichaVoluntariaDialog> createState() => _FichaVoluntariaDialogState();
}

class _FichaVoluntariaDialogState extends State<_FichaVoluntariaDialog> {
  Tutora? _voluntaria;
  late String _cursoAsignar = widget.cursos.first.id;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final voluntarias = await widget.repository.getTutoras();
    if (!mounted) return;
    setState(() => _voluntaria = voluntarias.where((t) => t.id == widget.voluntariaId).firstOrNull);
  }

  Future<void> _cambiarAdhesion(bool firmada) async {
    var fecha = DateTime(2026, 4, 25);
    if (firmada) {
      final elegida = await elegirFecha(context, inicial: fecha);
      if (elegida == null) return;
      fecha = elegida;
    }
    final v = _voluntaria!;
    // copyWith no puede dejar la fecha en null, así que se reconstruye sin ella al desmarcar
    final actualizada = firmada
        ? v.copyWith(adhesionFirmada: true, fechaFirmaAdhesion: fecha)
        : Tutora(
            id: v.id,
            nombre: v.nombre,
            rol: v.rol,
            sedeId: v.sedeId,
            sedeNombre: v.sedeNombre,
            adhesionFirmada: false,
            presenteClaseActual: v.presenteClaseActual,
            esEquipoGestion: v.esEquipoGestion,
            rut: v.rut,
            correo: v.correo,
            institucion: v.institucion,
            fechaIngreso: v.fechaIngreso,
            fechaSalida: v.fechaSalida,
            estado: v.estado,
            cursoIds: v.cursoIds,
          );
    await widget.repository.actualizarVoluntaria(actualizada);
    _cargar();
  }

  Future<void> _cambiarEquipoGestion(bool esEquipoGestion) async {
    final v = _voluntaria!;
    await widget.repository.actualizarVoluntaria(v.copyWith(esEquipoGestion: esEquipoGestion));
    if (!mounted) return;
    mostrarAviso(
      context,
      esEquipoGestion
          ? '✅ ${v.nombre} ahora es parte del Equipo de Gestión.'
          : '${v.nombre} ya no es parte del Equipo de Gestión.',
    );
    _cargar();
  }

  Future<void> _asignar() async {
    final ok = await widget.repository.asignarVoluntariaACurso(
      tutoraId: widget.voluntariaId,
      cursoId: _cursoAsignar,
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      ok
          ? '✅ Asignada al curso. Ya aparece en el pase de lista de tutoras.'
          : '⛔ No se puede asignar: falta la declaración de adhesión firmada.',
      error: !ok,
    );
    _cargar();
  }

  Future<void> _registrarSalida() async {
    final v = _voluntaria!;
    final fecha = await elegirFecha(context, inicial: DateTime(2026, 4, 25));
    if (fecha == null) return;
    final ok = await widget.repository.actualizarVoluntaria(
      v.copyWith(estado: 'retirada', fechaSalida: fecha),
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      ok
          ? 'Salida registrada. Su trayectoria se conserva.'
          : 'La fecha de salida no puede ser anterior al ingreso (${formatearFecha(v.fechaIngreso)}).',
      error: !ok,
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final v = _voluntaria;
    if (v == null) {
      return const AlertDialog(content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())));
    }
    final apta = v.adhesionFirmada && v.estado == 'activa';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(child: Text(v.nombre)),
          DirectorioChip(etiquetaEstado(v.estado), tono: tonoEstado(v.estado)),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${v.rut} · ${v.correo}'),
              Text('${v.rolVoluntariado} · ${v.sedeNombre} · ${v.institucion}',
                  style: const TextStyle(color: NinasProColors.neutral500)),
              const SizedBox(height: 4),
              Text(
                'Ingreso: ${formatearFecha(v.fechaIngreso)}'
                '${v.fechaSalida != null ? ' · Salida: ${formatearFecha(v.fechaSalida)}' : ''}',
                style: const TextStyle(color: NinasProColors.neutral500),
              ),
              const Divider(height: 28),
              // Indicador de aptitud docente
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: apta
                      ? (isDark ? NinasProColors.success900 : NinasProColors.success100)
                      : (isDark ? NinasProColors.warning900 : NinasProColors.warning100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      apta ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                      color: apta
                          ? (isDark ? NinasProColors.success300 : NinasProColors.success900)
                          : (isDark ? NinasProColors.warning300 : NinasProColors.warning900),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        apta
                            ? 'Apta para hacer clases'
                            : (v.estado != 'activa'
                                ? 'No apta: está retirada'
                                : 'No apta: falta la declaración de adhesión firmada'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: apta
                              ? (isDark ? NinasProColors.success300 : NinasProColors.success900)
                              : (isDark ? NinasProColors.warning300 : NinasProColors.warning900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Declaración de Conocimiento y Adhesión firmada'),
                subtitle: Text(v.adhesionFirmada
                    ? 'Firmada el ${formatearFecha(v.fechaFirmaAdhesion)}'
                    : 'Sin firma registrada'),
                value: v.adhesionFirmada,
                onChanged: v.estado == 'activa' ? _cambiarAdhesion : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Equipo de Gestión'),
                subtitle: Text(v.esEquipoGestion
                    ? 'Tiene las funciones de Gestión de ${v.sedeNombre}, además de las de tutora'
                    : 'Solo tiene las funciones de tutora'),
                value: v.esEquipoGestion,
                onChanged: v.estado == 'activa' ? _cambiarEquipoGestion : null,
              ),
              const SizedBox(height: 8),
              const Text('Trayectoria', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in v.cursoIds)
                    DirectorioChip(
                      widget.cursos.where((c) => c.id == id).map((c) => '${c.codigo} · ${c.sedeNombre}').firstOrNull ?? id,
                    ),
                ],
              ),
              if (v.estado == 'activa') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _cursoAsignar,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Asignar a curso',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final c in widget.cursos)
                            DropdownMenuItem(value: c.id, child: Text('${c.codigo} · ${c.sedeNombre}')),
                        ],
                        onChanged: (id) => setState(() => _cursoAsignar = id ?? _cursoAsignar),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: _asignar, child: const Text('Asignar')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (v.estado == 'activa')
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: NinasProColors.error700),
            onPressed: _registrarSalida,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Registrar salida'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
