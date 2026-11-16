import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/ninaspro_colors.dart';
import '../../repositories/alertas_repository.dart';
import '../../repositories/justificativos_repository.dart' show fechaCorta;

/// Recordatorio de que las alertas son para acompañar, no para clasificar (US-40 E3)
class NotaMetodologicaAlertas extends StatelessWidget {
  const NotaMetodologicaAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark700 : NinasProColors.info100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            size: 18,
            color: isDark ? NinasProColors.info300 : NinasProColors.info700,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Estas alertas son una herramienta de acompañamiento y cuidado, no una clasificación. '
              'Se generan con 3 inasistencias seguidas sin justificar. Contacta a la familia con cercanía '
              'y sin juzgar: la alumna nunca ve estas alertas en su portal.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una alerta: alumna, racha, contacto de la apoderada y el
/// registro del contacto (o lo que se conversó, si ya se atendió)
class TarjetaAlertaDesercion extends StatelessWidget {
  final AlertaDesercionDetalle alerta;

  /// Abre el registro del contacto; null en una alerta ya atendida
  final VoidCallback? onRegistrarContacto;

  const TarjetaAlertaDesercion({super.key, required this.alerta, this.onRegistrarContacto});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final a = alerta;
    final secundario = TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: a.atendida ? (isDark ? NinasProColors.dark700 : NinasProColors.neutral100) : NinasProColors.warning500,
          width: a.atendida ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.alumnaNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: a.atendida ? NinasProColors.success100 : NinasProColors.warning100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.atendida ? 'CONTACTADA' : 'POR CONTACTAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: a.atendida ? NinasProColors.success900 : NinasProColors.warning900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${a.cursoCodigo} · ${a.sedeNombre}', style: secundario),
            const SizedBox(height: 6),
            Text(
              '${a.inasistenciasConsecutivas} inasistencias seguidas sin justificar (última: ${a.ultimaClase}).',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            if (a.apoderadoNombre != null) ...[const SizedBox(height: 8), _ContactoApoderada(alerta: a)],
            if (a.atendida) ...[
              const SizedBox(height: 8),
              Text(
                'Contacto del ${a.fechaContacto == null ? '—' : fechaCorta(a.fechaContacto!)}'
                '${a.atendidaPor == null ? '' : ' · ${a.atendidaPor}'}',
                style: secundario,
              ),
              if (a.observacion != null) ...[
                const SizedBox(height: 2),
                Text('“${a.observacion}”', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
              ],
            ] else if (onRegistrarContacto != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onRegistrarContacto,
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: const Text('Registrar contacto'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactoApoderada extends StatelessWidget {
  final AlertaDesercionDetalle alerta;

  const _ContactoApoderada({required this.alerta});

  Future<void> _copiar(BuildContext context, String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Copiado al portapapeles.')));
  }

  @override
  Widget build(BuildContext context) {
    final a = alerta;
    final parentesco = a.apoderadoParentesco == null || a.apoderadoParentesco!.isEmpty
        ? ''
        : ' (${a.apoderadoParentesco})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apoderada/o: ${a.apoderadoNombre}$parentesco', style: const TextStyle(fontSize: 12.5)),
        Wrap(
          spacing: 4,
          children: [
            if (a.apoderadoTelefono != null && a.apoderadoTelefono!.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.phone_rounded, size: 16),
                label: Text(a.apoderadoTelefono!),
                tooltip: 'Copiar teléfono',
                onPressed: () => _copiar(context, a.apoderadoTelefono!),
              ),
            if (a.apoderadoCorreo != null && a.apoderadoCorreo!.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.mail_outline_rounded, size: 16),
                label: Text(a.apoderadoCorreo!),
                tooltip: 'Copiar correo',
                onPressed: () => _copiar(context, a.apoderadoCorreo!),
              ),
          ],
        ),
      ],
    );
  }
}

/// Registro del contacto preventivo con la apoderada (US-40 E2). Devuelve true si se guardó.
Future<bool> mostrarModalContactoAlerta(
  BuildContext context,
  AlertasRepository repository,
  AlertaDesercionDetalle alerta,
) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ModalContacto(repository: repository, alerta: alerta),
  );
  return guardado ?? false;
}

class _ModalContacto extends StatefulWidget {
  final AlertasRepository repository;
  final AlertaDesercionDetalle alerta;

  const _ModalContacto({required this.repository, required this.alerta});

  @override
  State<_ModalContacto> createState() => _ModalContactoState();
}

class _ModalContactoState extends State<_ModalContacto> {
  static const _maximo = 1000;

  final _observacion = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _observacion.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = 'Cuenta brevemente qué conversaste con la apoderada.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final resultado = await widget.repository.registrarContacto(widget.alerta.id, texto);
    if (!mounted) return;
    if (resultado.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _guardando = false;
      _error = resultado.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Contacto con la familia de ${widget.alerta.alumnaNombre}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anota lo conversado (por ejemplo, transporte o salud). Queda registrado con tu nombre y la fecha.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacion,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: _maximo,
            decoration: InputDecoration(
              labelText: 'Observaciones del contacto',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Guardar contacto'),
          ),
        ],
      ),
    );
  }
}

/// Panel de alertas de deserción de la sede: por contactar y contactadas (US-40).
/// Pantalla propia para abrirla desde el inicio de Gestión o desde Ajustes.
class AlertasDesercionView extends StatefulWidget {
  final AlertasRepository repository;

  /// Se llama después de registrar un contacto (para refrescar el inicio)
  final VoidCallback? alCambiar;

  const AlertasDesercionView({super.key, required this.repository, this.alCambiar});

  @override
  State<AlertasDesercionView> createState() => _AlertasDesercionViewState();
}

enum _FiltroAlertas { porContactar, contactadas, todas }

class _AlertasDesercionViewState extends State<AlertasDesercionView> {
  bool _cargando = true;
  String? _error;
  List<AlertaDesercionDetalle> _alertas = const [];
  _FiltroAlertas _filtro = _FiltroAlertas.porContactar;
  String? _sedeId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final alertas = await widget.repository.alertas();
      if (!mounted) return;
      setState(() {
        _alertas = alertas;
        _error = null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las alertas. Revisa la conexión e inténtalo nuevamente.';
        _cargando = false;
      });
    }
  }

  Future<void> _registrarContacto(AlertaDesercionDetalle alerta) async {
    if (!await mostrarModalContactoAlerta(context, widget.repository, alerta) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: NinasProColors.success700, content: Text('📞 Contacto registrado.')),
    );
    widget.alCambiar?.call();
    await _cargar();
  }

  List<AlertaDesercionDetalle> get _visibles => [
    for (final a in _alertas)
      if ((_sedeId == null || a.sedeId == _sedeId) &&
          switch (_filtro) {
            _FiltroAlertas.porContactar => !a.atendida,
            _FiltroAlertas.contactadas => a.atendida,
            _FiltroAlertas.todas => true,
          })
        a,
  ];

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final sedes = {for (final a in _alertas) a.sedeId: a.sedeNombre};
    final visibles = _visibles;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const NotaMetodologicaAlertas(),
          const SizedBox(height: 12),
          SegmentedButton<_FiltroAlertas>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _FiltroAlertas.porContactar, label: Text('Por contactar')),
              ButtonSegment(value: _FiltroAlertas.contactadas, label: Text('Contactadas')),
              ButtonSegment(value: _FiltroAlertas.todas, label: Text('Todas')),
            ],
            selected: {_filtro},
            onSelectionChanged: (s) => setState(() => _filtro = s.first),
          ),
          // La Directiva (o Gestión de varias sedes) filtra por sede
          if (sedes.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Todas las sedes'),
                  selected: _sedeId == null,
                  onSelected: (_) => setState(() => _sedeId = null),
                ),
                for (final e in sedes.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _sedeId == e.key,
                    onSelected: (_) => setState(() => _sedeId = e.key),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!)
          else if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _filtro == _FiltroAlertas.contactadas
                    ? 'Aún no hay contactos registrados.'
                    : 'Ninguna alumna acumula inasistencias seguidas. ¡Sigan así!',
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final a in visibles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaAlertaDesercion(
                  alerta: a,
                  onRegistrarContacto: a.atendida ? null : () => _registrarContacto(a),
                ),
              ),
        ],
      ),
    );
  }
}
