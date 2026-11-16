import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../services/selector_archivos.dart';
import '../directorio/directorio_widgets.dart';

/// Abre la ficha única de la alumna (US-09, US-10, US-12). En pantallas
/// angostas (Gestión en el celular) ocupa toda la pantalla.
Future<void> mostrarFichaAlumna(BuildContext context, {required AlumnasRepository repository, required String alumnaId}) {
  final angosta = MediaQuery.sizeOf(context).width < 640;
  return showDialog<void>(
    context: context,
    builder: (_) => angosta
        ? Dialog.fullscreen(child: FichaAlumnaView(repository: repository, alumnaId: alumnaId))
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780, maxHeight: 860),
              child: FichaAlumnaView(repository: repository, alumnaId: alumnaId),
            ),
          ),
  );
}

/// Ficha: datos de la alumna y su apoderado/a, historial de inscripciones con
/// retiro, y autorizaciones con respaldo firmado y revocación por canal.
class FichaAlumnaView extends StatefulWidget {
  final AlumnasRepository repository;
  final String alumnaId;

  const FichaAlumnaView({super.key, required this.repository, required this.alumnaId});

  @override
  State<FichaAlumnaView> createState() => _FichaAlumnaViewState();
}

class _FichaAlumnaViewState extends State<FichaAlumnaView> {
  FichaAlumna? _ficha;
  bool _cargando = true;

  // Autorizaciones en edición (se guardan con "Guardar autorizaciones")
  ConsentimientoDatos _tratamiento = ConsentimientoDatos.pendiente;
  Map<CanalImagen, bool> _canales = {};
  ArchivoAdjunto? _respaldoNuevo;
  DateTime? _fechaFirma;
  bool _cambios = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final ficha = await widget.repository.ficha(widget.alumnaId);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _ficha = ficha;
      if (ficha == null) return;
      final a = ficha.autorizaciones;
      _tratamiento = a.tratamientoDatos;
      _canales = {for (final c in CanalImagen.values) c: a.autorizado(c)};
      _fechaFirma = a.fechaFirma;
      _respaldoNuevo = null;
      _cambios = false;
      _error = null;
    });
  }

  void _cambiar(VoidCallback cambio) => setState(() {
    cambio();
    _cambios = true;
  });

  Future<void> _adjuntar() async {
    final archivo = await elegirArchivo(ArchivoAdjunto.extensiones);
    if (archivo == null || !mounted) return;
    final error = archivo.error;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _cambiar(() {
      _error = null;
      _respaldoNuevo = archivo;
      _fechaFirma ??= DateTime.now();
    });
  }

  Future<void> _verRespaldo(String documento) async {
    final r = await widget.repository.urlRespaldo(documento);
    if (!mounted) return;
    final url = r.valor;
    if (url == null) {
      setState(() => _error = r.error ?? 'No pudimos abrir el respaldo.');
      return;
    }
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await widget.repository.registrarAutorizaciones(
      alumnaId: widget.alumnaId,
      tratamientoDatos: _tratamiento,
      canales: _canales,
      respaldo: _respaldoNuevo,
      fechaFirma: _fechaFirma,
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    mostrarAviso(context, '✅ Autorizaciones guardadas.');
    await _cargar();
  }

  Future<void> _revocar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRevocacion(repository: widget.repository, ficha: _ficha!),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, '🚫 Revocación registrada. Rige desde la fecha indicada.');
    await _cargar();
  }

  Future<void> _retirar(InscripcionNomina inscripcion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRetiro(repository: widget.repository, ficha: _ficha!, inscripcion: inscripcion),
    );
    if (ok != true || !mounted) return;
    mostrarAviso(context, 'Retiro registrado. Su historial de asistencia se conserva.');
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ficha = _ficha;
    if (_cargando) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    if (ficha == null) {
      return const SizedBox(height: 160, child: Center(child: Text('No encontramos la ficha de esta alumna.')));
    }
    final hayCanalesRevocables = ficha.autorizaciones.canales.values.any((v) => v);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(ficha.nombreCompleto, style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 32,
                  runSpacing: 12,
                  children: [
                    _Dato('RUT', ficha.rut),
                    _Dato('Fecha de nacimiento', formatearFecha(ficha.fechaNacimiento)),
                    if (ficha.establecimiento != null)
                      _Dato(
                        'Establecimiento',
                        [ficha.establecimiento, ficha.cursoEscolar].whereType<String>().join(' · '),
                      ),
                    if (ficha.correo != null) _Dato('Correo', ficha.correo!),
                    if (ficha.apoderado case final ap?) ...[
                      _Dato(
                        'Apoderado/a',
                        [ap.nombreCompleto, if (ap.parentesco.isNotEmpty) '(${ap.parentesco})'].join(' '),
                      ),
                      _Dato('Contacto', '${ap.telefono} · ${ap.correo}'),
                    ],
                  ],
                ),
                const Divider(height: 32),
                const _Titulo('Inscripciones'),
                for (final i in ficha.inscripciones) _buildInscripcion(i),
                const Divider(height: 32),
                _buildAutorizaciones(ficha),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: hayCanalesRevocables && !_guardando ? _revocar : null,
                icon: const Icon(Icons.no_photography_rounded, size: 18),
                label: const Text('Revocar autorización'),
              ),
              FilledButton.icon(
                onPressed: _cambios && !_guardando ? _guardar : null,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar autorizaciones'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInscripcion(InscripcionNomina i) {
    final asistencia = i.porcentajeAsistencia;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i.cursoNombre} · ${i.sedeNombre}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  [
                    i.cursoEtiqueta,
                    'inscrita el ${formatearFecha(i.fechaInscripcion)}',
                    if (asistencia != null) 'asistencia ${asistencia.toStringAsFixed(1)}% (${i.clasesAsistidas}/${i.clasesComputables})',
                    if (i.estado == 'retirada') 'retiro el ${formatearFecha(i.fechaRetiro)}: ${i.motivoRetiro ?? ''}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DirectorioChip(etiquetaEstado(i.estado), tono: tonoEstado(i.estado)),
              if (i.vigente)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: NinasProColors.error700,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _retirar(i),
                  child: const Text('Registrar retiro'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutorizaciones(FichaAlumna ficha) {
    final a = ficha.autorizaciones;
    final documento = _respaldoNuevo?.nombre ?? a.nombreDocumento;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _Titulo('Autorizaciones del apoderado/a')),
            if (a.registradas)
              Flexible(
                child: Text(
                  'Registradas el ${formatearFecha(a.actualizadoEn)}${a.registradoPor == null ? '' : ' por ${a.registradoPor}'}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Tratamiento de datos personales', style: TextStyle(fontWeight: FontWeight.w600)),
        const Text(
          'Requisito para participar: al otorgarlo, sus inscripciones preinscritas pasan a activas.',
          style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ConsentimientoDatos>(
          showSelectedIcon: false,
          segments: [
            for (final c in ConsentimientoDatos.values) ButtonSegment(value: c, label: Text(c.label)),
          ],
          selected: {_tratamiento},
          onSelectionChanged: (v) => _cambiar(() => _tratamiento = v.first),
        ),
        const SizedBox(height: 16),
        const Text(
          'Uso de imagen por canal (sin respuesta = no autorizado)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NinasProColors.neutral500),
        ),
        for (final canal in CanalImagen.values) _buildCanal(a, canal),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              documento == null ? Icons.attach_file_rounded : Icons.description_rounded,
              size: 18,
              color: NinasProColors.neutral500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                documento == null
                    ? 'Sin documento firmado adjunto'
                    : '$documento${_respaldoNuevo == null ? '' : ' (se sube al guardar)'}',
              ),
            ),
            if (_respaldoNuevo == null && a.documento != null)
              TextButton(onPressed: () => _verRespaldo(a.documento!), child: const Text('Ver')),
            TextButton(
              onPressed: _adjuntar,
              child: Text(documento == null ? 'Adjuntar respaldo' : 'Reemplazar'),
            ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.event_rounded, size: 20),
          title: const Text('Fecha de firma'),
          subtitle: Text(formatearFecha(_fechaFirma)),
          trailing: TextButton(
            onPressed: () async {
              final fecha = await elegirFecha(context, inicial: _fechaFirma ?? DateTime.now(), ultima: DateTime.now());
              if (fecha != null) _cambiar(() => _fechaFirma = fecha);
            },
            child: const Text('Cambiar'),
          ),
        ),
      ],
    );
  }

  Widget _buildCanal(AutorizacionesFicha guardadas, CanalImagen canal) {
    final autorizado = _canales[canal] ?? false;
    final revocacion = guardadas.revocaciones[canal];

    return Row(
      children: [
        Expanded(child: Text(canal.label)),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: !autorizado && revocacion != null
              ? Tooltip(
                  message: revocacion.motivo,
                  child: DirectorioChip('Revocada desde ${formatearFecha(revocacion.fecha)}', tono: TonoChip.error),
                )
              : DirectorioChip(
                  autorizado ? 'Autorizada' : 'No autorizada',
                  tono: autorizado ? TonoChip.exito : TonoChip.neutro,
                ),
        ),
        Switch(value: autorizado, onChanged: (v) => _cambiar(() => _canales[canal] = v)),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
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

/// Revocación de uno o todos los canales autorizados con fecha y motivo (US-12)
class _DialogoRevocacion extends StatefulWidget {
  final AlumnasRepository repository;
  final FichaAlumna ficha;

  const _DialogoRevocacion({required this.repository, required this.ficha});

  @override
  State<_DialogoRevocacion> createState() => _DialogoRevocacionState();
}

class _DialogoRevocacionState extends State<_DialogoRevocacion> {
  late final _autorizados = CanalImagen.values.where(widget.ficha.autorizaciones.autorizado).toList();
  late final Set<CanalImagen> _seleccionados = {..._autorizados};
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _guardando = true);
    final r = await widget.repository.revocarImagen(
      alumnaId: widget.ficha.id,
      canales: _seleccionados.toList(),
      fecha: _fecha,
      motivo: _motivo.text,
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
    final valido = _seleccionados.isNotEmpty && _motivo.text.trim().isNotEmpty && !_guardando;

    return AlertDialog(
      title: const Text('Revocar autorización de imagen'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Las fotos de las clases desde esta fecha dejan de ser aptas para los canales revocados. '
                'Los usos anteriores se conservan.',
                style: TextStyle(fontSize: 12.5, color: NinasProColors.neutral500),
              ),
              const SizedBox(height: 8),
              for (final canal in _autorizados)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(canal.label),
                  value: _seleccionados.contains(canal),
                  onChanged: (v) =>
                      setState(() => v == true ? _seleccionados.add(canal) : _seleccionados.remove(canal)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('Fecha de la solicitud'),
                subtitle: Text(formatearFecha(_fecha)),
                trailing: TextButton(
                  onPressed: () async {
                    final fecha = await elegirFecha(context, inicial: _fecha, ultima: DateTime.now());
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
                ),
            ],
          ),
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

/// Retiro formal de una inscripción con fecha y motivo, conservando el historial (US-09)
class _DialogoRetiro extends StatefulWidget {
  final AlumnasRepository repository;
  final FichaAlumna ficha;
  final InscripcionNomina inscripcion;

  const _DialogoRetiro({required this.repository, required this.ficha, required this.inscripcion});

  @override
  State<_DialogoRetiro> createState() => _DialogoRetiroState();
}

class _DialogoRetiroState extends State<_DialogoRetiro> {
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _guardando = true);
    final r = await widget.repository.retirar(
      inscripcionId: widget.inscripcion.inscripcionId,
      fecha: _fecha,
      motivo: _motivo.text,
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
      title: Text('Registrar retiro de ${widget.ficha.nombreCompleto}'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.inscripcion.cursoNombre} · ${widget.inscripcion.sedeNombre}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('Fecha de retiro'),
              subtitle: Text(formatearFecha(_fecha)),
              trailing: TextButton(
                onPressed: () async {
                  final fecha = await elegirFecha(
                    context,
                    inicial: _fecha,
                    primera: widget.inscripcion.fechaInscripcion,
                    ultima: DateTime.now(),
                  );
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
          onPressed: _motivo.text.trim().isEmpty || _guardando ? null : _confirmar,
          child: const Text('Registrar retiro'),
        ),
      ],
    );
  }
}
