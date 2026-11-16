import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../utils/rut.dart';
import '../../utils/rut_input_formatter.dart';
import 'directorio_importacion_dialog.dart';
import 'directorio_widgets.dart';

/// Nómina nacional de alumnas (US-07, US-08, US-09, US-10, US-12).
///
/// Filtros por sede, curso y estado, búsqueda por nombre o RUT, inscripción individual,
/// carga masiva simulada y ficha con autorizaciones, revocación de imagen y retiro.
class DirectorioAlumnasView extends StatefulWidget {
  final HubRepository repository;

  const DirectorioAlumnasView({super.key, required this.repository});

  @override
  State<DirectorioAlumnasView> createState() => _DirectorioAlumnasViewState();
}

class _DirectorioAlumnasViewState extends State<DirectorioAlumnasView> {
  bool _cargando = true;
  List<Alumna> _alumnas = [];
  List<Sede> _sedes = [];
  List<Curso> _cursos = [];

  String? _sedeId;
  String? _cursoId;
  String? _estado;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final alumnas = await widget.repository.getAlumnas();
    final sedes = await widget.repository.getSedes();
    final cursos = await widget.repository.getCursos();
    if (!mounted) return;
    setState(() {
      _alumnas = alumnas;
      _sedes = sedes;
      _cursos = cursos;
      _cargando = false;
    });
  }

  List<Alumna> get _filtradas {
    final texto = _busqueda.trim().toLowerCase();
    final rutTexto = normalizarRut(_busqueda);
    return _alumnas.where((a) {
      if (_sedeId != null && a.sedeId != _sedeId) return false;
      if (_cursoId != null && a.cursoId != _cursoId) return false;
      if (_estado != null && a.estado != _estado) return false;
      if (texto.isEmpty) return true;
      return a.nombre.toLowerCase().contains(texto) ||
          (rutTexto.isNotEmpty && normalizarRut(a.rut).contains(rutTexto));
    }).toList();
  }

  String _etiquetaCurso(Curso c) => '${c.codigo} · ${c.sedeNombre}';

  Future<void> _cargaMasiva() async {
    final inscritas = await mostrarDialogoImportacion(
      context,
      titulo: 'Carga masiva de nómina',
      etiquetaDestino: 'Curso de destino',
      destinos: {for (final c in _cursos) c.id: _etiquetaCurso(c)},
      columnasPlantilla: const ['nombre', 'rut', 'nombre_apoderado', 'telefono_apoderado', 'correo_apoderado'],
      etiquetaDetalle: 'Apoderado/a',
      previsualizar: (cursoId, columnasValidas) => widget.repository.previsualizarImportacionAlumnas(
        cursoId: cursoId,
        columnasValidas: columnasValidas,
      ),
      confirmar: (cursoId) => widget.repository.confirmarImportacionAlumnas(cursoId: cursoId),
    );
    if (inscritas == null || !mounted) return;
    mostrarAviso(context, '✅ $inscritas alumnas quedaron preinscritas.');
    _cargarDatos();
  }

  Future<void> _inscribir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoInscripcion(repository: widget.repository, cursos: _cursos),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, '✅ Alumna inscrita como preinscrita.');
    _cargarDatos();
  }

  Future<void> _abrirFicha(Alumna alumna) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FichaAlumnaDialog(repository: widget.repository, alumnaId: alumna.id),
    );
    if (mounted) _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final filtradas = _filtradas;
    final cursosFiltro = _cursos.where((c) => _sedeId == null || c.sedeId == _sedeId).toList();

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Alumnas',
          subtitulo: '${_alumnas.where((a) => a.estado == 'activa').length} activas en ${_sedes.length} sedes',
          acciones: [
            OutlinedButton.icon(
              onPressed: _cargaMasiva,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Carga masiva'),
            ),
            FilledButton.icon(
              onPressed: _inscribir,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Inscribir alumna'),
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Buscar por nombre o RUT',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Sede',
                    valor: _sedeId,
                    opciones: {for (final s in _sedes) s.id: s.nombre},
                    onChanged: (v) => setState(() {
                      _sedeId = v;
                      _cursoId = null;
                    }),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Curso',
                    valor: _cursoId,
                    opciones: {for (final c in cursosFiltro) c.id: c.codigo},
                    onChanged: (v) => setState(() => _cursoId = v),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Estado',
                    valor: _estado,
                    opciones: const {
                      'activa': 'Activa',
                      'preinscrita': 'Preinscrita',
                      'retirada': 'Retirada',
                      'egresada': 'Egresada',
                    },
                    onChanged: (v) => setState(() => _estado = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DirectorioTabla(
                columnas: const ['Alumna', 'RUT', 'Sede', 'Curso', 'Asistencia', 'Fotos', 'Estado'],
                filas: [
                  for (final a in filtradas)
                    DataRow(
                      onSelectChanged: (_) => _abrirFicha(a),
                      cells: [
                        DataCell(Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(a.rut)),
                        DataCell(Text(a.sedeNombre)),
                        DataCell(Text(a.cursoNombre)),
                        DataCell(Text('${a.porcentajeAsistencia.toStringAsFixed(1)}%')),
                        DataCell(Icon(
                          a.autorizaFoto ? Icons.photo_camera_rounded : Icons.no_photography_rounded,
                          size: 18,
                          color: a.autorizaFoto ? NinasProColors.success700 : NinasProColors.neutral500,
                        )),
                        DataCell(DirectorioChip(etiquetaEstado(a.estado), tono: tonoEstado(a.estado))),
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

/// Formulario de inscripción individual (US-09)
class _DialogoInscripcion extends StatefulWidget {
  final HubRepository repository;
  final List<Curso> cursos;

  const _DialogoInscripcion({required this.repository, required this.cursos});

  @override
  State<_DialogoInscripcion> createState() => _DialogoInscripcionState();
}

class _DialogoInscripcionState extends State<_DialogoInscripcion> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _rut = TextEditingController();
  final _apoderado = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  late String _cursoId = widget.cursos.first.id;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _rut, _apoderado, _telefono, _correo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.repository.inscribirAlumna(
      cursoId: _cursoId,
      nombre: _nombre.text,
      rut: _rut.text,
      apoderadoNombre: _apoderado.text,
      apoderadoTelefono: _telefono.text,
      apoderadoCorreo: _correo.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Esta alumna ya está inscrita en ese curso.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inscribir alumna'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _cursoId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder()),
                    items: [
                      for (final c in widget.cursos)
                        DropdownMenuItem(value: c.id, child: Text('${c.codigo} · ${c.sedeNombre}')),
                    ],
                    onChanged: (v) => setState(() => _cursoId = v ?? _cursoId),
                  ),
                ),
                CampoFormulario(controller: _nombre, etiqueta: 'Nombre completo', validator: obligatorio),
                CampoFormulario(
                  controller: _rut,
                  formateadores: const [RutInputFormatter()],
                  etiqueta: 'RUT',
                  ayuda: 'Si el RUT ya existe se reutiliza su ficha',
                  validator: (v) => obligatorio(v) ?? (validarRut(v!) ? null : 'RUT inválido (revisa el dígito verificador)'),
                ),
                CampoFormulario(controller: _apoderado, etiqueta: 'Nombre del apoderado/a', validator: obligatorio),
                CampoFormulario(
                  controller: _telefono,
                  etiqueta: 'Teléfono del apoderado/a',
                  teclado: TextInputType.phone,
                  validator: obligatorio,
                ),
                CampoFormulario(
                  controller: _correo,
                  etiqueta: 'Correo del apoderado/a',
                  teclado: TextInputType.emailAddress,
                  validator: (v) => obligatorio(v) ?? (v!.contains('@') ? null : 'Correo inválido'),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Inscribir')),
      ],
    );
  }
}

/// Ficha de la alumna: datos, apoderado, autorizaciones (US-10), revocación (US-12) y retiro (US-09)
class _FichaAlumnaDialog extends StatefulWidget {
  final HubRepository repository;
  final String alumnaId;

  const _FichaAlumnaDialog({required this.repository, required this.alumnaId});

  @override
  State<_FichaAlumnaDialog> createState() => _FichaAlumnaDialogState();
}

class _FichaAlumnaDialogState extends State<_FichaAlumnaDialog> {
  Alumna? _alumna;
  // Autorizaciones en edición (se guardan con "Guardar autorizaciones")
  bool _tratamientoDatos = false;
  Map<CanalImagen, EstadoAutorizacion> _canales = {};
  String? _respaldo;
  bool _cambiosSinGuardar = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final alumna = await widget.repository.getAlumnaById(widget.alumnaId);
    if (!mounted || alumna == null) return;
    setState(() {
      _alumna = alumna;
      _tratamientoDatos = alumna.autorizaciones.tratamientoDatos;
      _canales = {for (final c in CanalImagen.values) c: alumna.autorizaciones.estado(c)};
      _respaldo = alumna.autorizaciones.respaldoNombre;
      _cambiosSinGuardar = false;
    });
  }

  Future<void> _guardarAutorizaciones() async {
    final alumna = _alumna!;
    final ok = await widget.repository.actualizarAutorizaciones(
      alumnaId: alumna.id,
      autorizaciones: AutorizacionesAlumna(
        tratamientoDatos: _tratamientoDatos,
        canales: _canales,
        revocaciones: {
          for (final e in alumna.autorizaciones.revocaciones.entries)
            if (_canales[e.key] == EstadoAutorizacion.revocada) e.key: e.value,
        },
        respaldoNombre: _respaldo,
        fechaRegistro: DateTime.now(),
      ),
    );
    if (!mounted) return;
    mostrarAviso(context, ok ? '✅ Autorizaciones guardadas.' : 'No se pudieron guardar.', error: !ok);
    _cargar();
  }

  Future<void> _revocar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRevocacion(repository: widget.repository, alumna: _alumna!),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, '🚫 Revocación registrada. Rige desde la fecha indicada.');
    _cargar();
  }

  Future<void> _registrarRetiro() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRetiro(repository: widget.repository, alumna: _alumna!),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, 'Retiro registrado. Su historial de asistencia se conserva.');
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final alumna = _alumna;
    if (alumna == null) {
      return const AlertDialog(content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())));
    }
    final hayCanalesRevocables = _canales.values.any((e) => e == EstadoAutorizacion.otorgada);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(child: Text(alumna.nombre)),
          DirectorioChip(etiquetaEstado(alumna.estado), tono: tonoEstado(alumna.estado)),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _Dato('RUT', alumna.rut),
                  _Dato('Sede', alumna.sedeNombre),
                  _Dato('Curso', alumna.cursoNombre),
                  _Dato('Asistencia', '${alumna.porcentajeAsistencia.toStringAsFixed(1)}% (${alumna.asistenciasCount} clases)'),
                  _Dato('Apoderado/a', alumna.apoderadoNombre),
                  _Dato('Contacto', '${alumna.apoderadoTelefono} · ${alumna.apoderadoCorreo}'),
                  if (alumna.estado == 'retirada')
                    _Dato('Retiro', '${formatearFecha(alumna.fechaRetiro)} · ${alumna.motivoRetiro ?? ''}'),
                ],
              ),
              if (alumna.historialInscripciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Dato('Inscripciones anteriores', alumna.historialInscripciones.join('\n')),
              ],
              const Divider(height: 32),
              Row(
                children: [
                  const Expanded(
                    child: Text('Autorizaciones del apoderado/a',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  if (alumna.autorizaciones.fechaRegistro != null)
                    Text(
                      'Registradas el ${formatearFecha(alumna.autorizaciones.fechaRegistro)}',
                      style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tratamiento de datos personales'),
                subtitle: const Text('Requisito para participar en las clases'),
                value: _tratamientoDatos,
                onChanged: (v) => setState(() {
                  _tratamientoDatos = v;
                  _cambiosSinGuardar = true;
                }),
              ),
              const Text(
                'Uso de imagen por canal (sin respuesta = no autorizado)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NinasProColors.neutral500),
              ),
              for (final canal in CanalImagen.values) _buildCanal(alumna, canal),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _respaldo == null ? Icons.attach_file_rounded : Icons.picture_as_pdf_rounded,
                    size: 18,
                    color: NinasProColors.neutral500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_respaldo ?? 'Sin documento firmado adjunto')),
                  TextButton(
                    onPressed: () => setState(() {
                      _respaldo = 'autorizacion_firmada_${alumna.id}.pdf';
                      _cambiosSinGuardar = true;
                    }),
                    child: Text(_respaldo == null ? 'Adjuntar respaldo' : 'Reemplazar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (alumna.estado != 'retirada')
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: NinasProColors.error700),
            onPressed: _registrarRetiro,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Registrar retiro'),
          ),
        OutlinedButton.icon(
          onPressed: hayCanalesRevocables ? _revocar : null,
          icon: const Icon(Icons.no_photography_rounded, size: 18),
          label: const Text('Revocar autorización'),
        ),
        FilledButton.icon(
          onPressed: _cambiosSinGuardar ? _guardarAutorizaciones : null,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Guardar autorizaciones'),
        ),
      ],
    );
  }

  Widget _buildCanal(Alumna alumna, CanalImagen canal) {
    final estado = _canales[canal] ?? EstadoAutorizacion.noAutorizada;
    final revocacion = alumna.autorizaciones.revocaciones[canal];

    return Row(
      children: [
        Expanded(child: Text(canal.label)),
        if (estado == EstadoAutorizacion.revocada)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: revocacion?.motivo ?? '',
              child: DirectorioChip(
                'Revocada desde ${formatearFecha(revocacion?.fecha)}',
                tono: TonoChip.error,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DirectorioChip(
              estado.label,
              tono: estado == EstadoAutorizacion.otorgada ? TonoChip.exito : TonoChip.neutro,
            ),
          ),
        Switch(
          value: estado == EstadoAutorizacion.otorgada,
          onChanged: (v) => setState(() {
            _canales[canal] = v ? EstadoAutorizacion.otorgada : EstadoAutorizacion.noAutorizada;
            _cambiosSinGuardar = true;
          }),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NinasProColors.neutral500),
        ),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontSize: 13.5)),
      ],
    );
  }
}

/// Revocación de uno o todos los canales de imagen con fecha y motivo (US-12)
class _DialogoRevocacion extends StatefulWidget {
  final HubRepository repository;
  final Alumna alumna;

  const _DialogoRevocacion({required this.repository, required this.alumna});

  @override
  State<_DialogoRevocacion> createState() => _DialogoRevocacionState();
}

class _DialogoRevocacionState extends State<_DialogoRevocacion> {
  late final _otorgados = CanalImagen.values
      .where((c) => widget.alumna.autorizaciones.estado(c) == EstadoAutorizacion.otorgada)
      .toList();
  late final Set<CanalImagen> _seleccionados = {..._otorgados};
  DateTime _fecha = DateTime(2026, 4, 25);
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final ok = await widget.repository.revocarAutorizacionImagen(
      alumnaId: widget.alumna.id,
      canales: _seleccionados.toList(),
      fecha: _fecha,
      motivo: _motivo.text,
    );
    if (mounted) Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    final valido = _seleccionados.isNotEmpty && _motivo.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Revocar autorización de imagen'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Las fotos desde esta fecha dejan de ser aptas para los canales revocados. '
              'Los usos anteriores se conservan.',
              style: TextStyle(fontSize: 12.5, color: NinasProColors.neutral500),
            ),
            const SizedBox(height: 8),
            for (final canal in _otorgados)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(canal.label),
                value: _seleccionados.contains(canal),
                onChanged: (v) => setState(() => v == true ? _seleccionados.add(canal) : _seleccionados.remove(canal)),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('Fecha de la solicitud'),
              subtitle: Text(formatearFecha(_fecha)),
              trailing: TextButton(
                onPressed: () async {
                  final fecha = await elegirFecha(context, inicial: _fecha);
                  if (fecha != null) setState(() => _fecha = fecha);
                },
                child: const Text('Cambiar'),
              ),
            ),
            TextField(
              controller: _motivo,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
          onPressed: valido ? _confirmar : null,
          child: const Text('Revocar'),
        ),
      ],
    );
  }
}

/// Retiro formal con fecha y motivo, conservando el historial (US-09)
class _DialogoRetiro extends StatefulWidget {
  final HubRepository repository;
  final Alumna alumna;

  const _DialogoRetiro({required this.repository, required this.alumna});

  @override
  State<_DialogoRetiro> createState() => _DialogoRetiroState();
}

class _DialogoRetiroState extends State<_DialogoRetiro> {
  DateTime _fecha = DateTime(2026, 4, 25);
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final ok = await widget.repository.registrarRetiroAlumna(
      alumnaId: widget.alumna.id,
      motivo: _motivo.text.trim(),
      fecha: _fecha,
    );
    if (mounted) Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Registrar retiro de ${widget.alumna.nombre}'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('Fecha de retiro'),
              subtitle: Text(formatearFecha(_fecha)),
              trailing: TextButton(
                onPressed: () async {
                  final fecha = await elegirFecha(context, inicial: _fecha);
                  if (fecha != null) setState(() => _fecha = fecha);
                },
                child: const Text('Cambiar'),
              ),
            ),
            TextField(
              controller: _motivo,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Motivo formal', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
          onPressed: _motivo.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Registrar retiro'),
        ),
      ],
    );
  }
}
