import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../utils/rut.dart';
import '../alumnas/ficha_alumna_dialog.dart';
import '../alumnas/importacion_alumnas_dialog.dart';
import '../alumnas/inscripcion_dialog.dart';
import 'directorio_widgets.dart';

/// Nómina nacional de alumnas (US-07, US-08, US-09, US-10, US-11, US-12).
///
/// Una fila por inscripción, con filtros por sede, curso, estado y
/// consentimiento, búsqueda por nombre o RUT, inscripción individual, carga
/// masiva desde CSV o XLSX y la ficha con autorizaciones, revocación y retiro.
class DirectorioAlumnasView extends StatefulWidget {
  final AlumnasRepository repository;

  const DirectorioAlumnasView({super.key, required this.repository});

  @override
  State<DirectorioAlumnasView> createState() => _DirectorioAlumnasViewState();
}

class _DirectorioAlumnasViewState extends State<DirectorioAlumnasView> {
  bool _cargando = true;
  String? _errorCarga;
  List<InscripcionNomina> _nomina = [];
  List<Curso> _instancias = [];

  String? _sedeId;
  String? _instanciaId;
  String? _estado;
  ConsentimientoDatos? _consentimiento;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final nomina = await widget.repository.nomina();
      final instancias = await widget.repository.instancias();
      if (!mounted) return;
      setState(() {
        _nomina = nomina;
        _instancias = instancias;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No pudimos cargar la nómina. Revisa tu conexión e inténtalo nuevamente.';
      });
    }
  }

  /// Sedes con instancias o alumnas, por nombre
  Map<String, String> get _sedes {
    final sedes = <String, String>{
      for (final c in _instancias) c.sedeId: c.sedeNombre,
      for (final i in _nomina) i.sedeId: i.sedeNombre,
    };
    return Map.fromEntries(sedes.entries.toList()..sort((a, b) => a.value.compareTo(b.value)));
  }

  List<InscripcionNomina> get _filtradas {
    final texto = _busqueda.trim().toLowerCase();
    final rutTexto = normalizarRut(_busqueda);
    return _nomina.where((i) {
      if (_sedeId != null && i.sedeId != _sedeId) return false;
      if (_instanciaId != null && i.instanciaId != _instanciaId) return false;
      if (_estado != null && i.estado != _estado) return false;
      if (_consentimiento != null && i.consentimiento != _consentimiento) return false;
      if (texto.isEmpty) return true;
      return i.nombreCompleto.toLowerCase().contains(texto) ||
          (rutTexto.isNotEmpty && normalizarRut(i.rut).contains(rutTexto));
    }).toList();
  }

  Future<void> _cargaMasiva() async {
    final r = await mostrarImportacionAlumnas(context, repository: widget.repository, instancias: _instancias);
    if (r == null || !mounted) return;
    mostrarAviso(
      context,
      '✅ ${r.inscritas} ${r.inscritas == 1 ? 'alumna inscrita' : 'alumnas inscritas'}'
      '${r.rechazadas == 0 ? '' : ' · ${r.rechazadas} filas rechazadas'}.',
    );
    _cargarDatos();
  }

  Future<void> _inscribir() async {
    final ok = await mostrarInscripcionAlumna(context, repository: widget.repository, instancias: _instancias);
    if (ok != true || !mounted) return;
    mostrarAviso(context, '✅ Alumna inscrita. Su matrícula se activa al registrar el consentimiento de datos.');
    _cargarDatos();
  }

  Future<void> _abrirFicha(InscripcionNomina inscripcion) async {
    await mostrarFichaAlumna(context, repository: widget.repository, alumnaId: inscripcion.alumnaId);
    if (mounted) _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_errorCarga != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorCarga!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _cargarDatos, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final filtradas = _filtradas;
    final sedes = _sedes;
    final instanciasFiltro = _instancias.where((c) => _sedeId == null || c.sedeId == _sedeId).toList();
    final activas = _nomina.where((i) => i.estado == 'activa').length;
    final urgentes = _nomina.where((i) => i.regularizacionUrgente).length;
    final sinInstancias = _instancias.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Alumnas',
          subtitulo: '$activas activas en ${sedes.length} ${sedes.length == 1 ? 'sede' : 'sedes'}',
          acciones: [
            Tooltip(
              message: sinInstancias ? 'Primero programa una instancia de curso en Ajustes' : '',
              child: OutlinedButton.icon(
                onPressed: sinInstancias ? null : _cargaMasiva,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Carga masiva'),
              ),
            ),
            FilledButton.icon(
              onPressed: sinInstancias ? null : _inscribir,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Inscribir alumna'),
            ),
          ],
        ),
        if (urgentes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _estado = 'preinscrita';
                  _consentimiento = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DirectorioChip(
                    '$urgentes ${urgentes == 1 ? 'alumna sigue' : 'alumnas siguen'} sin consentimiento de datos '
                    'tras 2 sesiones · ver preinscritas',
                    tono: TonoChip.advertencia,
                    icono: Icons.warning_amber_rounded,
                  ),
                ),
              ),
            ),
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
                    opciones: sedes,
                    onChanged: (v) => setState(() {
                      _sedeId = v;
                      _instanciaId = null;
                    }),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Curso',
                    valor: _instanciaId,
                    opciones: {for (final c in instanciasFiltro) c.id: c.codigo},
                    onChanged: (v) => setState(() => _instanciaId = v),
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
                  FiltroDesplegable<ConsentimientoDatos>(
                    etiqueta: 'Consentimiento',
                    valor: _consentimiento,
                    opciones: {for (final c in ConsentimientoDatos.values) c: c.label},
                    onChanged: (v) => setState(() => _consentimiento = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DirectorioTabla(
                columnas: const ['Alumna', 'RUT', 'Sede', 'Curso', 'Asistencia', 'Consentimiento', 'Fotos', 'Estado'],
                mensajeVacio: _nomina.isEmpty
                    ? 'Aún no hay alumnas inscritas. Usa "Carga masiva" o "Inscribir alumna".'
                    : 'Ninguna alumna coincide con los filtros.',
                filas: [
                  for (final i in filtradas)
                    DataRow(
                      onSelectChanged: (_) => _abrirFicha(i),
                      cells: [
                        DataCell(Text(i.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(i.rut)),
                        DataCell(Text(i.sedeNombre)),
                        DataCell(Text(i.cursoEtiqueta)),
                        DataCell(Text(
                          i.porcentajeAsistencia == null ? '—' : '${i.porcentajeAsistencia!.toStringAsFixed(1)}%',
                        )),
                        DataCell(_ChipConsentimiento(i)),
                        DataCell(Icon(
                          i.autorizaFotos ? Icons.photo_camera_rounded : Icons.no_photography_rounded,
                          size: 18,
                          color: i.autorizaFotos ? NinasProColors.success700 : NinasProColors.neutral500,
                        )),
                        DataCell(DirectorioChip(etiquetaEstado(i.estado), tono: tonoEstado(i.estado))),
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

/// Consentimiento de datos; destacado si sigue pendiente tras 2 sesiones (US-11)
class _ChipConsentimiento extends StatelessWidget {
  final InscripcionNomina inscripcion;

  const _ChipConsentimiento(this.inscripcion);

  @override
  Widget build(BuildContext context) {
    final c = inscripcion.consentimiento;
    if (inscripcion.regularizacionUrgente) {
      return Tooltip(
        message: 'Sin consentimiento tras ${inscripcion.sesionesTranscurridas} sesiones',
        child: DirectorioChip(c.label, tono: TonoChip.advertencia, icono: Icons.warning_amber_rounded),
      );
    }
    return DirectorioChip(
      c.label,
      tono: switch (c) {
        ConsentimientoDatos.otorgado => TonoChip.exito,
        ConsentimientoDatos.pendiente => TonoChip.info,
        ConsentimientoDatos.noOtorgado => TonoChip.error,
      },
    );
  }
}
