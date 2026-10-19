import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_mascot.dart';

/// Portal Móvil de la Alumna en NiñasPro Hub.
///
/// Cubre:
/// - US-25: Dashboard de asistencia % y progreso académico vs. 75% mínimo.
/// - US-26: Cronograma de clases de los sábados y recursos educativos (Colab, guías).
/// - US-29: Podio Kahoot privado y reconocimientos de aula.
/// - US-35: Envío de justificativo de inasistencia con minimización de datos de salud.
class PortalAlumnaScreen extends StatefulWidget {
  final HubRepository repository;
  final String alumnaId;

  const PortalAlumnaScreen({
    super.key,
    required this.repository,
    this.alumnaId = 'alumna-1', // Valentina Soto Morales por defecto
  });

  @override
  State<PortalAlumnaScreen> createState() => _PortalAlumnaScreenState();
}

class _PortalAlumnaScreenState extends State<PortalAlumnaScreen> {
  bool _cargando = true;
  late PortalAlumnaData _data;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final data = await widget.repository.getPortalAlumnaData(alumnaId: widget.alumnaId);
    setState(() {
      _data = data;
      _cargando = false;
    });
  }

  void _abrirModalJustificativo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivoCtrl = TextEditingController();
    String motivoSeleccionado = 'Salud';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Justificar Inasistencia (US-35)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu solicitud será revisada por el equipo de coordinación de tu sede.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Advertencia de privacidad médica (US-36)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NinasProColors.info100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: NinasProColors.info900),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Protección de datos: No es necesario detallar diagnósticos médicos sensibles, solo el tipo de reposo.',
                              style: TextStyle(fontSize: 11.5, color: NinasProColors.info900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Motivo tipificado:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Salud', 'Familiar', 'Escolar', 'Transporte', 'Otro'].map((m) {
                        final sel = motivoSeleccionado == m;
                        return ChoiceChip(
                          label: Text(m),
                          selected: sel,
                          selectedColor: NinasProColors.primary700,
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : (isDark ? Colors.white : Colors.black),
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => motivoSeleccionado = m);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Detalle de la justificación:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: motivoCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Explica brevemente la razón de tu ausencia...',
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: () async {
                          if (motivoCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          await widget.repository.enviarJustificativo(
                            alumnaId: widget.alumnaId,
                            sesionId: 'sesion-3',
                            motivoTipificado: motivoSeleccionado,
                            detalle: motivoCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('✅ Justificativo enviado con éxito.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Enviar Justificativo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final alumna = _data.alumna;
    final asistenciaPorc = alumna.porcentajeAsistencia;
    final aprueba = asistenciaPorc >= 75.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal de la Alumna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NinasProColors.brandPink,
        foregroundColor: NinasProColors.neutral900,
        onPressed: () => _abrirModalJustificativo(context),
        icon: const Icon(Icons.edit_document, size: 18),
        label: const Text(
          'Justificar Falta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          // Banner de bienvenida con gatita astronauta
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [NinasProColors.primary900, NinasProColors.accent900]
                    : [NinasProColors.primary100, NinasProColors.accent100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, ${alumna.nombre}! 💜',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? NinasProColors.white : NinasProColors.primary900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alumna.cursoNombre,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? NinasProColors.primary300 : NinasProColors.primary700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alumna.sedeNombre,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
                const NinasProMascot(size: 72, showStars: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de progreso de asistencia (US-25)
          Card(
            elevation: 0,
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Mi Asistencia Acumulada',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: aprueba ? NinasProColors.success100 : NinasProColors.warning100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aprueba ? 'Cumple meta (>=75%)' : 'Bajo meta mínima',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: aprueba ? NinasProColors.success900 : NinasProColors.warning900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        '${asistenciaPorc.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: NinasProColors.brandPink,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (asistenciaPorc / 100).clamp(0.0, 1.0),
                                minHeight: 12,
                                backgroundColor: isDark
                                    ? NinasProColors.dark700
                                    : NinasProColors.neutral100,
                                valueColor: AlwaysStoppedAnimation(
                                  aprueba ? NinasProColors.success500 : NinasProColors.warning500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${alumna.asistenciasCount} de 8 clases asistidas (Meta mínima: 75% para certificar)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logros, Kahoot y Ejercicios (US-28, US-29)
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🏆 Kahoot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('2° Lugar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Podio de la sala ✨', style: TextStyle(fontSize: 11, color: NinasProColors.brandPink)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💻 Ejercicios', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${_data.totalEjerciciosResueltos} Resueltos',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('100% participación activa', style: TextStyle(fontSize: 11, color: NinasProColors.success700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cronograma de Sábados (US-25, US-26)
          const Text(
            'Cronograma de Clases (Sábados)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          ..._data.sesiones.map((sesion) {
            // Buscar estado de la alumna en esta sesión
            final reg = _data.asistencias.where((a) => a.sesionId == sesion.id).firstOrNull;
            final estado = reg?.estado ??
                (sesion.estado == 'realizada' ? EstadoAsistencia.ausente : EstadoAsistencia.pendiente);
            final tono = context.statusColors.asistencia(estado);

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${sesion.numeroSesion}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                    ),
                  ),
                ),
                title: Text(
                  sesion.tema,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${sesion.fecha.day}/${sesion.fecha.month}/${sesion.fecha.year}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: tono.decoration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estado.icon, size: 14, color: tono.foreground),
                      const SizedBox(width: 4),
                      Text(estado.label, style: tono.textStyle(fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
