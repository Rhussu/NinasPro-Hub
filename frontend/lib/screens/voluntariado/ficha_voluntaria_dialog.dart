import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/justificativos_repository.dart' show Resultado;
import '../../repositories/voluntariado_repository.dart';
import '../../utils/rut.dart';
import '../../utils/rut_input_formatter.dart';
import '../directorio/directorio_widgets.dart';

/// Etiqueta de un curso para elegirlo: PCB · Sede Beauchef · 2026-1 (Sección B)
String etiquetaCursoVoluntariado(Curso c) =>
    '${c.codigo} · ${c.sedeNombre} · ${c.anio}-${c.semestre}'
    '${c.seccion > 1 ? ' (Sección ${String.fromCharCode(64 + c.seccion)})' : ''}';

DateTime _hoy() {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

/// Alta individual de una voluntaria (US-30 escenario 3). Devuelve true si se creó.
Future<bool?> mostrarAltaVoluntaria(
  BuildContext context, {
  required VoluntariadoRepository repository,
  required List<Sede> sedes,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _AltaVoluntariaDialog(repository: repository, sedes: sedes),
);

/// Ficha de la voluntaria: cuenta, adhesión (US-31), rol, cursos y salida (US-32)
Future<void> mostrarFichaVoluntaria(
  BuildContext context, {
  required VoluntariadoRepository repository,
  required FichaVoluntaria ficha,
  required List<Curso> instancias,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FichaVoluntariaDialog(repository: repository, inicial: ficha, instancias: instancias),
);

class _AltaVoluntariaDialog extends StatefulWidget {
  final VoluntariadoRepository repository;
  final List<Sede> sedes;

  const _AltaVoluntariaDialog({required this.repository, required this.sedes});

  @override
  State<_AltaVoluntariaDialog> createState() => _AltaVoluntariaDialogState();
}

class _AltaVoluntariaDialogState extends State<_AltaVoluntariaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rut = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _institucion = TextEditingController();
  late String _sedeId = widget.sedes.first.id;
  RolVoluntaria _rol = RolVoluntaria.tutora;
  DateTime _ingreso = _hoy();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_rut, _nombres, _apellidos, _correo, _telefono, _institucion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirIngreso() async {
    final fecha = await elegirFecha(context, inicial: _ingreso, primera: DateTime(2015), ultima: _hoy());
    if (fecha != null) setState(() => _ingreso = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await widget.repository.alta(
      sedeId: _sedeId,
      datos: DatosVoluntaria(
        rut: _rut.text,
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        correo: _correo.text,
        telefono: _telefono.text,
        institucion: _institucion.text,
        rol: _rol,
        fechaIngreso: _ingreso,
      ),
    );
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _error = r.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva voluntaria'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CampoFormulario(
                  controller: _rut,
                  formateadores: const [RutInputFormatter()],
                  etiqueta: 'RUT',
                  validator: (v) =>
                      obligatorio(v) ?? (validarRut(v!) ? null : 'RUT inválido (revisa el dígito verificador)'),
                ),
                CampoFormulario(controller: _nombres, etiqueta: 'Nombres', validator: obligatorio),
                CampoFormulario(controller: _apellidos, etiqueta: 'Apellidos', validator: obligatorio),
                CampoFormulario(
                  controller: _correo,
                  etiqueta: 'Correo institucional',
                  teclado: TextInputType.emailAddress,
                  validator: (v) =>
                      obligatorio(v) ??
                      (v!.trim().toLowerCase().endsWith('@ninaspro.cl') ? null : 'Usa el correo @ninaspro.cl'),
                ),
                CampoFormulario(controller: _telefono, etiqueta: 'Teléfono (opcional)', teclado: TextInputType.phone),
                CampoFormulario(controller: _institucion, etiqueta: 'Institución u ocupación (opcional)'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _sedeId,
                    decoration: const InputDecoration(labelText: 'Sede', border: OutlineInputBorder()),
                    items: [for (final s in widget.sedes) DropdownMenuItem(value: s.id, child: Text(s.nombre))],
                    onChanged: (v) => setState(() => _sedeId = v ?? _sedeId),
                  ),
                ),
                SegmentedButton<RolVoluntaria>(
                  segments: [for (final r in RolVoluntaria.values) ButtonSegment(value: r, label: Text(r.etiqueta))],
                  selected: {_rol},
                  onSelectionChanged: (s) => setState(() => _rol = s.first),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Fecha de ingreso'),
                  subtitle: Text(formatearFecha(_ingreso)),
                  trailing: TextButton(onPressed: _elegirIngreso, child: const Text('Cambiar')),
                ),
                const Text(
                  'Al crear la ficha se autoriza su correo por 30 días para que cree su cuenta.',
                  style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
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
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Crear ficha')),
      ],
    );
  }
}

class _FichaVoluntariaDialog extends StatefulWidget {
  final VoluntariadoRepository repository;
  final FichaVoluntaria inicial;
  final List<Curso> instancias;

  const _FichaVoluntariaDialog({required this.repository, required this.inicial, required this.instancias});

  @override
  State<_FichaVoluntariaDialog> createState() => _FichaVoluntariaDialogState();
}

class _FichaVoluntariaDialogState extends State<_FichaVoluntariaDialog> {
  late FichaVoluntaria _ficha = widget.inicial;
  String? _cursoAsignar;
  bool _procesando = false;

  VoluntariadoRepository get _repo => widget.repository;

  List<Curso> get _cursosDisponibles {
    final asignados = {for (final c in _ficha.cursos) c.instanciaId};
    return widget.instancias.where((c) => !asignados.contains(c.id)).toList();
  }

  Future<void> _recargar() async {
    final fichas = await _repo.fichas();
    if (!mounted) return;
    setState(() => _ficha = fichas.where((f) => f.id == _ficha.id).firstOrNull ?? _ficha);
  }

  /// Ejecuta una acción, avisa el resultado y relee la ficha
  Future<void> _ejecutar(Future<Resultado<Object?>> Function() accion, String exito) async {
    setState(() => _procesando = true);
    final r = await accion();
    if (!mounted) return;
    mostrarAviso(context, r.ok ? exito : r.error ?? 'No pudimos guardar la ficha.', error: !r.ok);
    await _recargar();
    if (mounted) setState(() => _procesando = false);
  }

  Future<void> _cambiarAdhesion(bool firmada) async {
    DateTime? fecha;
    if (firmada) {
      fecha = await elegirFecha(context, inicial: _hoy(), primera: DateTime(2015), ultima: _hoy());
      if (fecha == null) return;
    }
    await _ejecutar(
      () => _repo.registrarAdhesion(_ficha.id, firmada: firmada, fecha: fecha),
      firmada ? '✅ Adhesión registrada: ya puede asignarse a cursos.' : 'Se quitó la adhesión registrada.',
    );
  }

  Future<void> _cambiarRol(RolVoluntaria rol) => _ejecutar(
    () => _repo.cambiarRol(_ficha.id, rol),
    rol == RolVoluntaria.equipoGestion
        ? '✅ ${_ficha.nombre} ahora es parte del Equipo de Gestión.'
        : '${_ficha.nombre} ahora solo tiene las funciones de tutora.',
  );

  Future<void> _asignar() async {
    final cursoId = _cursoAsignar;
    if (cursoId == null) return;
    _cursoAsignar = null;
    await _ejecutar(
      () => _repo.asignarCurso(_ficha.id, cursoId),
      '✅ Asignada al curso. Ya aparece en el pase de lista de tutoras.',
    );
  }

  Future<void> _quitar(CursoTrayectoria curso) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar del curso?'),
        content: Text(
          'Solo se puede quitar a ${_ficha.nombre} de ${curso.etiqueta} si aún no tiene clases ni roles '
          'registrados en ese curso.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(() => _repo.quitarCurso(_ficha.id, curso.instanciaId), 'Se quitó la asignación.');
  }

  Future<void> _registrarSalida() async {
    final fecha = await elegirFecha(context, inicial: _hoy(), primera: _ficha.fechaIngreso, ultima: _hoy());
    if (fecha == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Registrar la salida?'),
        content: Text(
          '${_ficha.nombre} quedará retirada desde el ${formatearFecha(fecha)}: su cuenta se desactiva y se '
          'quitan sus roles de las clases posteriores. Su ficha y sus cursos se conservan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar salida')),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(() => _repo.registrarSalida(_ficha.id, fecha), 'Salida registrada. Su trayectoria se conserva.');
  }

  Future<void> _reincorporar() =>
      _ejecutar(() => _repo.reincorporar(_ficha.id), '✅ ${_ficha.nombre} vuelve al voluntariado.');

  Future<void> _renovar() =>
      _ejecutar(() => _repo.renovarAutorizacion(_ficha.id), '✅ Su correo queda autorizado por 30 días más.');

  @override
  Widget build(BuildContext context) {
    final v = _ficha;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activa = !v.retirada && !_procesando;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(child: Text(v.nombre)),
          DirectorioChip(v.retirada ? 'Retirada' : 'Activa', tono: v.retirada ? TonoChip.neutro : TonoChip.exito),
          IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ],
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_procesando) const LinearProgressIndicator(),
              Text([v.rut, v.correo, if (v.telefono != null) v.telefono!].join(' · ')),
              Text(
                [v.rol.etiqueta, v.sedeNombre, if (v.institucion != null) v.institucion!].join(' · '),
                style: const TextStyle(color: NinasProColors.neutral500),
              ),
              const SizedBox(height: 4),
              Text(
                'Ingreso: ${formatearFecha(v.fechaIngreso)}'
                '${v.fechaSalida != null ? ' · Salida: ${formatearFecha(v.fechaSalida)}' : ''}',
                style: const TextStyle(color: NinasProColors.neutral500),
              ),
              const SizedBox(height: 12),
              _buildCuenta(v),
              const Divider(height: 28),
              _IndicadorAptitud(ficha: v, isDark: isDark),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Declaración de Conocimiento y Adhesión firmada'),
                subtitle: Text(
                  v.adhesionFirmada ? 'Firmada el ${formatearFecha(v.fechaFirmaAdhesion)}' : 'Sin firma registrada',
                ),
                value: v.adhesionFirmada,
                onChanged: activa ? _cambiarAdhesion : null,
              ),
              const SizedBox(height: 4),
              const Text('Rol', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SegmentedButton<RolVoluntaria>(
                segments: [for (final r in RolVoluntaria.values) ButtonSegment(value: r, label: Text(r.etiqueta))],
                selected: {v.rol},
                onSelectionChanged: activa ? (s) => _cambiarRol(s.first) : null,
              ),
              const SizedBox(height: 16),
              const Text('Trayectoria', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (v.cursos.isEmpty)
                const Text('Aún no participa en cursos.', style: TextStyle(color: NinasProColors.neutral500))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in v.cursos)
                      InputChip(
                        label: Text(c.etiqueta),
                        onDeleted: activa ? () => _quitar(c) : null,
                        deleteButtonTooltipMessage: 'Quitar del curso',
                      ),
                  ],
                ),
              if (!v.retirada) ...[const SizedBox(height: 16), _buildAsignar(v)],
            ],
          ),
        ),
      ),
      actions: [
        if (v.retirada)
          TextButton.icon(
            onPressed: _procesando ? null : _reincorporar,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reincorporar'),
          )
        else
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: NinasProColors.error700),
            onPressed: _procesando ? null : _registrarSalida,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Registrar salida'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }

  Widget _buildCuenta(FichaVoluntaria v) {
    final (tono, texto) = switch (v.cuenta) {
      CuentaVoluntaria.activa => (TonoChip.exito, 'Ya creó su cuenta y puede entrar a NiñasPro Hub.'),
      CuentaVoluntaria.inactiva => (TonoChip.neutro, 'Su cuenta está desactivada porque salió del voluntariado.'),
      CuentaVoluntaria.autorizada => (
        TonoChip.info,
        'Su correo está autorizado hasta el ${formatearFecha(v.autorizacionExpiraEn)}. Aún no crea su cuenta.',
      ),
      CuentaVoluntaria.sinAutorizacion => (
        TonoChip.advertencia,
        v.retirada
            ? 'No tiene cuenta.'
            : 'La autorización de su correo venció sin que creara su cuenta. Renuévala para que pueda entrar.',
      ),
    };
    return Row(
      children: [
        DirectorioChip(v.cuenta.etiqueta, tono: tono),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 12.5))),
        if (v.cuenta == CuentaVoluntaria.sinAutorizacion && !v.retirada)
          TextButton(onPressed: _procesando ? null : _renovar, child: const Text('Renovar autorización')),
      ],
    );
  }

  Widget _buildAsignar(FichaVoluntaria v) {
    final String? bloqueo = !v.adhesionFirmada
        ? 'Para asignarla a un curso debe tener la declaración de adhesión firmada.'
        : v.perfilId == null
        ? 'Podrás asignarla a un curso cuando cree su cuenta con ${v.correo}.'
        : _cursosDisponibles.isEmpty
        ? 'Ya está en todos los cursos vigentes.'
        : null;
    if (bloqueo != null) {
      return Text(bloqueo, style: const TextStyle(fontSize: 12.5, color: NinasProColors.neutral500));
    }
    return Row(
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
              for (final c in _cursosDisponibles)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(etiquetaCursoVoluntariado(c), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _procesando ? null : (id) => setState(() => _cursoAsignar = id),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _procesando || _cursoAsignar == null ? null : _asignar, child: const Text('Asignar')),
      ],
    );
  }
}

/// Apta para hacer clases: activa y con la adhesión firmada (US-31)
class _IndicadorAptitud extends StatelessWidget {
  final FichaVoluntaria ficha;
  final bool isDark;

  const _IndicadorAptitud({required this.ficha, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final apta = ficha.apta;
    final fondo = apta
        ? (isDark ? NinasProColors.success900 : NinasProColors.success100)
        : (isDark ? NinasProColors.warning900 : NinasProColors.warning100);
    final color = apta
        ? (isDark ? NinasProColors.success300 : NinasProColors.success900)
        : (isDark ? NinasProColors.warning300 : NinasProColors.warning900);
    final texto = apta
        ? 'Apta para hacer clases'
        : ficha.retirada
        ? 'No apta: está retirada'
        : 'No apta: falta la declaración de adhesión firmada';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(apta ? Icons.verified_rounded : Icons.gpp_maybe_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
