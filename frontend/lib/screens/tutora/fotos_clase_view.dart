import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/evidencias_repository.dart';
import '../../services/compresion_imagen.dart';
import '../../services/selector_archivos.dart';
import 'clase_sesion_controller.dart';
import 'clase_sesion_views.dart' show EstadoSinPaseLista;

/// Texto de la declaración que exige marcar apta una foto con alumnas sin autorización (US-19 escenario 2)
const declaracionCensura =
    'Confirmo que las alumnas sin autorización no son reconocibles o sus rostros fueron cubiertos/censurados.';

/// Decisión de la tutora sobre la foto antes de subirla
typedef AptitudFoto = ({bool apta, bool rostrosCensurados});

/// Evidencia fotográfica de la clase en curso (US-18, US-19).
///
/// La foto se toma con la cámara o se elige de la galería, se comprime en el
/// celular a menos de 1,5 MB y se vincula a la clase. Si hay presentes sin
/// autorización de imagen, se listan y, para marcarla apta, se exige la
/// declaración de censura; sin ella se guarda como respaldo interno.
class FotosClaseView extends StatefulWidget {
  final ClaseSesionController controller;

  /// Sin repositorio (sin conexión con la base) las fotos no se suben
  final EvidenciasRepository? evidencias;

  const FotosClaseView({super.key, required this.controller, this.evidencias});

  @override
  State<FotosClaseView> createState() => _FotosClaseViewState();
}

class _FotosClaseViewState extends State<FotosClaseView> {
  List<EvidenciaFoto> _fotos = const [];
  bool _cargando = true;
  String? _error;

  /// Paso en curso al agregar una foto (comprimiendo o subiendo)
  String? _procesando;

  ClaseSesionController get _clase => widget.controller;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = widget.evidencias;
    if (repo == null || _clase.sesionId.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final fotos = await repo.fotos(_clase.sesionId);
      if (!mounted) return;
      setState(() {
        _fotos = fotos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar las fotos de la clase. Revisa tu conexión.';
      });
    }
  }

  void _avisar(String texto, Color color) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(backgroundColor: color, content: Text(texto)));
  }

  Future<void> _agregarFoto() async {
    final repo = widget.evidencias!;
    final archivo = await elegirFoto();
    if (archivo == null || !mounted) return;

    setState(() => _procesando = 'Comprimiendo la foto…');
    final jpeg = await comprimirFoto(archivo.bytes);
    if (!mounted) return;
    if (jpeg == null) {
      setState(() => _procesando = null);
      return _avisar('No pudimos leer la foto. Elige una imagen JPG o PNG.', NinasProColors.error700);
    }

    setState(() => _procesando = null);
    final sinAutorizacion = _clase.alumnasPresentes.where((r) => !r.autorizaImagen).toList();
    final aptitud = await showDialog<AptitudFoto>(
      context: context,
      builder: (_) => DialogoAptitudFoto(jpeg: jpeg, sinAutorizacion: sinAutorizacion),
    );
    if (aptitud == null || !mounted) return;

    setState(() => _procesando = 'Subiendo la foto…');
    final r = await repo.subir(
      claseId: _clase.sesionId,
      jpeg: jpeg,
      apta: aptitud.apta,
      rostrosCensurados: aptitud.rostrosCensurados,
    );
    if (!mounted) return;
    setState(() => _procesando = null);
    if (!r.ok) return _avisar('⚠️ ${r.error}', NinasProColors.error700);
    _avisar(
      '📸 Foto comprimida (${r.valor!.pesoEtiqueta}) y vinculada a la clase'
      '${aptitud.apta ? '.' : ' como respaldo interno.'}',
      NinasProColors.success700,
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _clase,
      builder: (context, _) {
        if (_clase.cargando) return const Center(child: CircularProgressIndicator());
        if (widget.evidencias == null) {
          return const EstadoSinPaseLista(
            icono: Icons.cloud_off_rounded,
            titulo: 'Sin conexión',
            mensaje: 'Las fotos de la clase necesitan la conexión con la base de datos.',
          );
        }
        if (!_clase.tienePaseLista) {
          return const EstadoSinPaseLista(
            icono: Icons.photo_camera_outlined,
            titulo: 'Primero el pase de lista',
            mensaje: 'Pasa lista y guárdala: la foto se vincula a la clase realizada y se revisa contra las presentes.',
          );
        }

        final sinAutorizacion = _clase.alumnasPresentes.where((r) => !r.autorizaImagen).toList();
        return RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              TarjetaAutorizacionesImagen(sinAutorizacion: sinAutorizacion),
              const SizedBox(height: 16),
              _buildAgregar(),
              const SizedBox(height: 16),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: NinasProColors.error700, fontWeight: FontWeight.w600),
                )
              else if (_fotos.isNotEmpty) ...[
                Text(
                  _fotos.length == 1 ? '1 foto de esta clase' : '${_fotos.length} fotos de esta clase',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (final f in _fotos) ...[TarjetaFotoEvidencia(foto: f), const SizedBox(height: 10)],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgregar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final procesando = _procesando;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300),
      ),
      child: Column(
        children: [
          Icon(
            _fotos.isEmpty ? Icons.cloud_upload_outlined : Icons.photo_library_rounded,
            size: 44,
            color: NinasProColors.brandPink,
          ),
          const SizedBox(height: 8),
          Text(
            _fotos.isEmpty ? 'Sube la foto de la clase desde tu celular' : 'Puedes agregar otra foto de la clase',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Se comprime en tu celular a menos de 1,5 MB antes de subirla.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
          ),
          const SizedBox(height: 12),
          if (procesando != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(procesando, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )
          else
            FilledButton.icon(
              style: NinasProTheme.brandButton,
              onPressed: _agregarFoto,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Agregar Foto de Evidencia'),
            ),
        ],
      ),
    );
  }
}

/// Estado de las autorizaciones de imagen de las presentes (US-19 escenario 1)
class TarjetaAutorizacionesImagen extends StatelessWidget {
  final List<RegistroAsistencia> sinAutorizacion;

  const TarjetaAutorizacionesImagen({super.key, required this.sinAutorizacion});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todas = sinAutorizacion.isEmpty;
    final texto = isDark ? NinasProColors.neutral300 : NinasProColors.neutral700;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  todas ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: todas ? NinasProColors.success700 : NinasProColors.warning700,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    todas
                        ? 'Todas las presentes tienen autorización de imagen'
                        : 'Atención: alumnas sin autorización de imagen',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (todas)
              Text(
                'La foto puede marcarse apta para difusión (redes, sitio web y patrocinadores).',
                style: TextStyle(fontSize: 13, color: texto),
              )
            else ...[
              Text(
                'Estas alumnas presentes no tienen autorización de imagen de su apoderado:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: texto),
              ),
              const SizedBox(height: 6),
              for (final a in sinAutorizacion)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    '• ${a.alumnaNombre}',
                    style: const TextStyle(fontSize: 13, color: NinasProColors.error700, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                '⚠️ Toma la foto de espaldas o cubre sus rostros. Sin esa confirmación, la foto queda solo como respaldo interno.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: NinasProColors.warning900),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Antes de subir: vista previa y aptitud de la foto (US-19 escenarios 2 y 3)
class DialogoAptitudFoto extends StatefulWidget {
  final Uint8List jpeg;
  final List<RegistroAsistencia> sinAutorizacion;

  const DialogoAptitudFoto({super.key, required this.jpeg, required this.sinAutorizacion});

  @override
  State<DialogoAptitudFoto> createState() => _DialogoAptitudFotoState();
}

class _DialogoAptitudFotoState extends State<DialogoAptitudFoto> {
  late bool _apta = widget.sinAutorizacion.isEmpty;
  bool _declaracion = false;

  bool get _requiereDeclaracion => widget.sinAutorizacion.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final peso = pesoLegible(widget.jpeg.length);
    final puedeMarcarApta = !_requiereDeclaracion || _declaracion;

    return AlertDialog(
      title: const Text('Foto de evidencia'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(widget.jpeg, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
              Text('Comprimida: $peso', style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500)),
              if (_requiereDeclaracion) ...[
                const SizedBox(height: 12),
                Text(
                  'Sin autorización de imagen: ${widget.sinAutorizacion.map((r) => r.alumnaNombre).join(', ')}.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NinasProColors.error700),
                ),
                CheckboxListTile(
                  key: const Key('declaracion-censura'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _declaracion,
                  onChanged: (v) => setState(() {
                    _declaracion = v ?? false;
                    if (!_declaracion) _apta = false;
                  }),
                  title: const Text(declaracionCensura, style: TextStyle(fontSize: 13)),
                ),
              ],
              SwitchListTile(
                key: const Key('foto-apta'),
                contentPadding: EdgeInsets.zero,
                value: _apta,
                onChanged: puedeMarcarApta ? (v) => setState(() => _apta = v) : null,
                title: const Text('Apta para difusión', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _apta
                      ? 'Se podrá usar en redes, sitio web y reportes, según los canales que autorizó cada apoderado.'
                      : 'Se guarda como respaldo interno de la clase, sin difundirla.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          style: NinasProTheme.brandButton,
          onPressed: () => Navigator.pop<AptitudFoto>(context, (apta: _apta, rostrosCensurados: _declaracion)),
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('Subir foto'),
        ),
      ],
    );
  }
}

/// Foto registrada con su aptitud, peso y autora (US-18 escenario 3)
class TarjetaFotoEvidencia extends StatelessWidget {
  final EvidenciaFoto foto;

  const TarjetaFotoEvidencia({super.key, required this.foto});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = foto.subidaEn;
    final hora =
        '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')} '
        '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    final url = foto.url;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: url == null
                ? const ColoredBox(color: NinasProColors.neutral100, child: Icon(Icons.image_outlined))
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: foto.apta ? NinasProColors.success100 : NinasProColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      foto.apta ? (foto.rostrosCensurados ? 'APTA · ROSTROS CUBIERTOS' : 'APTA') : 'RESPALDO INTERNO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: foto.apta ? NinasProColors.success900 : NinasProColors.neutral700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      foto.subidaPor,
                      hora,
                      foto.pesoEtiqueta,
                    ].whereType<String>().where((t) => t.isNotEmpty).join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
