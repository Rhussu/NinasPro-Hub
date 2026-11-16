import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import '../../utils/exportacion.dart';
import '../voluntariado/ficha_voluntaria_dialog.dart';
import '../voluntariado/importacion_voluntariado_dialog.dart';
import 'directorio_widgets.dart';

/// Directorio nacional de voluntariado (US-30, US-31, US-32).
///
/// Filtros por sede, rol, curso y estado; alta individual y carga masiva; ficha
/// con la cuenta, la declaración de adhesión, el rol, los cursos y la salida;
/// exportación del listado filtrado a CSV o XLSX. Todo lo administra la Directiva.
/// Gestión lo ve con [soloLectura]: las fichas de su sede, sin cambios ni exportación.
class DirectorioVoluntariadoView extends StatefulWidget {
  final VoluntariadoRepository repository;
  final CatalogoRepository catalogo;

  /// Sin alta, carga masiva, exportación ni ficha editable (Gestión)
  final bool soloLectura;

  /// Se abre apenas carga, cuando se llega desde Ajustes (ej. la carga masiva)
  final AccionVoluntariado? accionInicial;

  const DirectorioVoluntariadoView({
    super.key,
    required this.repository,
    required this.catalogo,
    this.soloLectura = false,
    this.accionInicial,
  });

  @override
  State<DirectorioVoluntariadoView> createState() => _DirectorioVoluntariadoViewState();
}

/// Lo que la Directiva puede abrir directo desde Ajustes
enum AccionVoluntariado { cargaMasiva, nuevaVoluntaria }

class _DirectorioVoluntariadoViewState extends State<DirectorioVoluntariadoView> {
  bool _cargando = true;
  String? _error;
  List<FichaVoluntaria> _fichas = [];
  List<Sede> _sedes = [];
  List<Curso> _instancias = [];

  String? _sedeId;
  RolVoluntaria? _rol;
  String? _cursoId;
  bool? _retirada = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos().then((_) => _ejecutarAccionInicial());
  }

  Future<void> _ejecutarAccionInicial() async {
    if (!mounted || widget.soloLectura || _error != null) return;
    switch (widget.accionInicial) {
      case AccionVoluntariado.cargaMasiva:
        await _cargaMasiva();
      case AccionVoluntariado.nuevaVoluntaria:
        await _altaIndividual();
      case null:
        break;
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final fichas = await widget.repository.fichas();
      final sedes = await widget.catalogo.sedes();
      final instancias = await widget.catalogo.instancias();
      if (!mounted) return;
      setState(() {
        _fichas = fichas;
        _sedes = sedes;
        _instancias = instancias;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar el voluntariado. Revisa tu conexión.';
      });
    }
  }

  List<FichaVoluntaria> get _filtradas => _fichas.where((f) {
    if (_sedeId != null && !f.sedeIds.contains(_sedeId)) return false;
    if (_rol != null && f.rol != _rol) return false;
    if (_cursoId != null && !f.cursos.any((c) => c.instanciaId == _cursoId)) return false;
    if (_retirada != null && f.retirada != _retirada) return false;
    return true;
  }).toList();

  Future<void> _cargaMasiva() async {
    if (_sedes.isEmpty) {
      mostrarAviso(context, 'Primero crea una sede en Ajustes.', error: true);
      return;
    }
    final revision = await mostrarImportacionVoluntariado(context, repository: widget.repository, sedes: _sedes);
    if (revision == null || !mounted) return;
    mostrarAviso(
      context,
      '✅ ${revision.creadas} fichas nuevas y ${revision.actualizadas} actualizadas'
      '${revision.rechazadas > 0 ? ' · ${revision.rechazadas} filas rechazadas' : ''}. '
      'Falta registrar la adhesión de las nuevas.',
    );
    _cargarDatos();
  }

  Future<void> _altaIndividual() async {
    if (_sedes.isEmpty) {
      mostrarAviso(context, 'Primero crea una sede en Ajustes.', error: true);
      return;
    }
    final ok = await mostrarAltaVoluntaria(context, repository: widget.repository, sedes: _sedes);
    if (ok != true || !mounted) return;
    mostrarAviso(context, '✅ Ficha creada y correo autorizado. Falta registrar su declaración de adhesión.');
    _cargarDatos();
  }

  void _exportar(FormatoExportacion formato) {
    final filas = _filtradas;
    exportarTabla(
      nombreBase: 'voluntariado',
      hoja: 'Voluntariado',
      formato: formato,
      encabezados: const [
        'rut',
        'nombres',
        'apellidos',
        'correo',
        'telefono',
        'institucion',
        'rol',
        'sede',
        'fecha_ingreso',
        'fecha_salida',
        'estado',
        'adhesion_firmada',
        'fecha_firma_adhesion',
        'cursos',
      ],
      filas: [
        for (final f in filas)
          [
            f.rut,
            f.nombres,
            f.apellidos,
            f.correo,
            f.telefono ?? '',
            f.institucion ?? '',
            f.rol.etiqueta,
            f.sedeNombre,
            formatearFecha(f.fechaIngreso),
            f.fechaSalida == null ? '' : formatearFecha(f.fechaSalida),
            f.retirada ? 'Retirada' : 'Activa',
            f.adhesionFirmada ? 'Sí' : 'No',
            f.fechaFirmaAdhesion == null ? '' : formatearFecha(f.fechaFirmaAdhesion),
            f.cursos.map((c) => c.etiqueta).join('; '),
          ],
      ],
    );
    mostrarAviso(context, '📄 voluntariado.${formato.extension} con ${filas.length} filas.');
  }

  Future<void> _abrirFicha(FichaVoluntaria ficha) async {
    await mostrarFichaVoluntaria(context, repository: widget.repository, ficha: ficha, instancias: _instancias);
    if (mounted) _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final filtradas = _filtradas;
    final activas = _fichas.where((f) => !f.retirada);
    final sinAdhesion = activas.where((f) => !f.adhesionFirmada).length;
    final sinCuenta = activas.where((f) => f.perfilId == null).length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Voluntariado',
          subtitulo: widget.soloLectura
              ? '${activas.length} voluntarias activas · $sinAdhesion sin declaración de adhesión · solo lectura'
              : '${activas.length} voluntarias activas · $sinAdhesion sin declaración de adhesión · '
                  '$sinCuenta aún sin cuenta',
          acciones: [
            if (!widget.soloLectura) ...[
              PopupMenuButton<FormatoExportacion>(
                tooltip: 'Exportar el listado filtrado',
                onSelected: _exportar,
                itemBuilder: (_) => [
                  for (final f in FormatoExportacion.values) PopupMenuItem(value: f, child: Text(f.etiqueta)),
                ],
                child: const IgnorePointer(
                  child: OutlinedButton(
                    onPressed: null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.file_download_rounded, size: 18), SizedBox(width: 8), Text('Exportar')],
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cargaMasiva,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Carga masiva'),
              ),
              FilledButton.icon(
                onPressed: _altaIndividual,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Nueva voluntaria'),
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
          const SizedBox(height: 12),
        ],
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
                  FiltroDesplegable<RolVoluntaria>(
                    etiqueta: 'Rol',
                    valor: _rol,
                    opciones: {for (final r in RolVoluntaria.values) r: r.etiqueta},
                    onChanged: (v) => setState(() => _rol = v),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Curso',
                    valor: _cursoId,
                    opciones: {for (final c in _instancias) c.id: etiquetaCursoVoluntariado(c)},
                    onChanged: (v) => setState(() => _cursoId = v),
                  ),
                  FiltroDesplegable<bool>(
                    etiqueta: 'Estado',
                    valor: _retirada,
                    opciones: const {false: 'Activa', true: 'Retirada'},
                    onChanged: (v) => setState(() => _retirada = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtradas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay voluntarias con estos filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NinasProColors.neutral500),
                  ),
                )
              else
                DirectorioTabla(
                  columnas: const ['Voluntaria', 'RUT', 'Sede', 'Rol', 'Ingreso', 'Cursos', 'Adhesión', 'Cuenta', 'Estado'],
                  filas: [
                    for (final f in filtradas)
                      DataRow(
                        onSelectChanged: widget.soloLectura ? null : (_) => _abrirFicha(f),
                        cells: [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(f.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(f.correo, style: const TextStyle(fontSize: 11.5, color: NinasProColors.neutral500)),
                            ],
                          )),
                          DataCell(Text(f.rut)),
                          DataCell(Text(f.sedeNombre)),
                          DataCell(Text(f.rol.etiqueta)),
                          DataCell(Text(formatearFecha(f.fechaIngreso))),
                          DataCell(Text(f.cursos.map((c) => c.cursoCodigo).join(', '))),
                          DataCell(f.adhesionFirmada
                              ? const DirectorioChip('Firmada', tono: TonoChip.exito, icono: Icons.verified_rounded)
                              : const DirectorioChip('Pendiente', tono: TonoChip.advertencia)),
                          DataCell(DirectorioChip(f.cuenta.etiqueta, tono: _tonoCuenta(f.cuenta))),
                          DataCell(f.retirada
                              ? const DirectorioChip('Retirada', tono: TonoChip.neutro)
                              : const DirectorioChip('Activa', tono: TonoChip.exito)),
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

  TonoChip _tonoCuenta(CuentaVoluntaria c) => switch (c) {
    CuentaVoluntaria.activa => TonoChip.exito,
    CuentaVoluntaria.autorizada => TonoChip.info,
    CuentaVoluntaria.inactiva => TonoChip.neutro,
    CuentaVoluntaria.sinAutorizacion => TonoChip.advertencia,
  };
}
