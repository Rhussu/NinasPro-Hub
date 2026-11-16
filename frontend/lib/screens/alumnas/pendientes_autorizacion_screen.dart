import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../repositories/alumnas_repository.dart';
import '../../widgets/ninaspro_vista_centrada.dart';
import '../directorio/directorio_widgets.dart';
import 'ficha_alumna_dialog.dart';

/// Preinscritas de las sedes de la usuaria que aún no tienen el consentimiento
/// de datos. Las que siguen así tras 2 sesiones van primero y destacadas
/// (US-11 escenario 3). Al tocar una se abre su ficha para registrarlo.
class PendientesAutorizacionScreen extends StatefulWidget {
  final AlumnasRepository repository;

  const PendientesAutorizacionScreen({super.key, required this.repository});

  @override
  State<PendientesAutorizacionScreen> createState() => _PendientesAutorizacionScreenState();
}

/// Preinscritas ordenadas: primero las urgentes, luego por nombre
List<InscripcionNomina> pendientesDeRegularizacion(List<InscripcionNomina> nomina) =>
    nomina.where((i) => i.estado == 'preinscrita').toList()..sort((a, b) {
      if (a.regularizacionUrgente != b.regularizacionUrgente) return a.regularizacionUrgente ? -1 : 1;
      return a.nombreCompleto.compareTo(b.nombreCompleto);
    });

class _PendientesAutorizacionScreenState extends State<PendientesAutorizacionScreen> {
  List<InscripcionNomina>? _pendientes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final nomina = await widget.repository.nomina();
    if (!mounted) return;
    setState(() => _pendientes = pendientesDeRegularizacion(nomina));
  }

  Future<void> _abrir(InscripcionNomina i) async {
    await mostrarFichaAlumna(context, repository: widget.repository, alumnaId: i.alumnaId);
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _pendientes;
    return Scaffold(
      appBar: AppBar(title: const Text('Autorizaciones pendientes')),
      body: NinasProVistaCentrada(
        child: pendientes == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Estas alumnas están preinscritas: no aparecen en el pase de lista hasta que se registre '
                      'el consentimiento de tratamiento de datos de su apoderado/a.',
                      style: TextStyle(fontSize: 12.5, color: NinasProColors.neutral500),
                    ),
                    const SizedBox(height: 12),
                    if (pendientes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text('✅ Todas las alumnas tienen su consentimiento registrado.')),
                      ),
                    for (final i in pendientes)
                      Card(
                        color: i.regularizacionUrgente
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? NinasProColors.warning900
                                : NinasProColors.warning100)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            i.regularizacionUrgente ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                            color: i.regularizacionUrgente ? NinasProColors.warning700 : NinasProColors.neutral500,
                          ),
                          title: Text(i.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            [
                              '${i.cursoCodigo} · ${i.sedeNombre}',
                              if (i.regularizacionUrgente)
                                'Sin consentimiento tras ${i.sesionesTranscurridas} sesiones'
                              else
                                'Inscrita el ${formatearFecha(i.fechaInscripcion)}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _abrir(i),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Resumen para el panel de sede de Gestión: cuántas preinscritas esperan su
/// consentimiento y cuántas ya superaron las 2 sesiones.
class TarjetaAutorizacionesPendientes extends StatefulWidget {
  final AlumnasRepository repository;

  const TarjetaAutorizacionesPendientes({super.key, required this.repository});

  @override
  State<TarjetaAutorizacionesPendientes> createState() => _TarjetaAutorizacionesPendientesState();
}

class _TarjetaAutorizacionesPendientesState extends State<TarjetaAutorizacionesPendientes> {
  List<InscripcionNomina>? _pendientes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final nomina = await widget.repository.nomina();
      if (mounted) setState(() => _pendientes = pendientesDeRegularizacion(nomina));
    } catch (_) {
      // Sin conexión la tarjeta no se muestra; el resto del panel sigue disponible
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _pendientes;
    if (pendientes == null || pendientes.isEmpty) return const SizedBox.shrink();
    final urgentes = pendientes.where((i) => i.regularizacionUrgente).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        color: urgentes > 0 ? (isDark ? NinasProColors.warning900 : NinasProColors.warning100) : null,
        child: ListTile(
          leading: Icon(
            Icons.assignment_late_rounded,
            color: urgentes > 0 ? NinasProColors.warning700 : NinasProColors.primary500,
          ),
          title: Text(
            '${pendientes.length} ${pendientes.length == 1 ? 'alumna espera' : 'alumnas esperan'} su consentimiento',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            urgentes > 0
                ? '$urgentes sin regularizar tras 2 sesiones: no pueden pasar lista'
                : 'Registra la autorización del apoderado/a para activar su matrícula',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PendientesAutorizacionScreen(repository: widget.repository)),
            );
            if (mounted) _cargar();
          },
        ),
      ),
    );
  }
}
