import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';

/// Pantalla móvil para la Tutora en el aula de clases de NiñasPro Hub.
///
/// Cubre:
/// - US-13: Pase de lista táctil rápido alternando únicamente Presente ↔ Ausente.
///   (Los justificativos son gestionados exclusivamente por el Equipo de Gestión).
/// - US-28: Registro de ejercicios resueltos y participación activa para alumnas presentes.
/// - US-29: Registro del podio Kahoot de la clase (1°, 2° y 3° lugar).
/// - US-18 y US-19: Verificación de consentimientos de imagen antes de subir evidencia fotográfica.
class PaseListaScreen extends StatefulWidget {
  final HubRepository repository;

  const PaseListaScreen({super.key, required this.repository});

  @override
  State<PaseListaScreen> createState() => _PaseListaScreenState();
}

class _PaseListaScreenState extends State<PaseListaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _cargando = true;
  final String _sesionId = 'sesion-4';
  List<RegistroAsistencia> _registros = [];
  List<ParticipacionClase> _participaciones = [];
  bool _fotoSubida = false;

  // Podio Kahoot de la sesión
  String? _primerLugarId;
  String? _segundoLugarId;
  String? _tercerLugarId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final reg = await widget.repository.getAsistenciaSesion(sesionId: _sesionId);
    final part = await widget.repository.getParticipacionSesion(sesionId: _sesionId);

    setState(() {
      _registros = List.from(reg);
      _participaciones = List.from(part);
      _cargando = false;
    });
  }

  // Regla US-13: Tutora solo alterna Presente ↔ Ausente. Justificada está bloqueada.
  void _ciclarEstado(int index) {
    final reg = _registros[index];

    if (reg.estado == EstadoAsistencia.justificada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NinasProColors.warning900,
          content: Text('🔒 Justificada por Equipo de Gestión. Las tutoras solo marcan Presente o Ausente.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final nuevo = reg.estado == EstadoAsistencia.presente
        ? EstadoAsistencia.ausente
        : EstadoAsistencia.presente;

    setState(() {
      _registros[index] = reg.copyWith(
        estado: nuevo,
        horaMarcado: DateTime.now(),
      );
    });
  }

  int get _totalPresentes =>
      _registros.where((r) => r.estado == EstadoAsistencia.presente).length;

  int get _totalAusentes =>
      _registros.where((r) => r.estado == EstadoAsistencia.ausente).length;

  int get _totalJustificadas =>
      _registros.where((r) => r.estado == EstadoAsistencia.justificada).length;

  List<RegistroAsistencia> get _alumnasPresentes =>
      _registros.where((r) => r.estado == EstadoAsistencia.presente).toList();

  Future<void> _guardarAsistencia() async {
    final stopwatch = Stopwatch()..start();
    await widget.repository.guardarAsistencia(
      sesionId: _sesionId,
      registros: _registros,
    );
    stopwatch.stop();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NinasProColors.success700,
        content: Text(
          '✅ Asistencia guardada: $_totalPresentes presentes, $_totalAusentes ausentes, '
          '$_totalJustificadas justificadas (${stopwatch.elapsedMilliseconds} ms).',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  // Modal para registrar podio Kahoot de la clase (US-29)
  void _mostrarModalRegistroKahoot() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presentes = _alumnasPresentes;

    if (presentes.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se necesitan al menos 3 alumnas presentes para registrar el podio Kahoot.'),
        ),
      );
      return;
    }

    String primerId = _primerLugarId ?? presentes[0].alumnaId;
    String segundoId = _segundoLugarId ?? presentes[1].alumnaId;
    String tercerId = _tercerLugarId ?? presentes[2].alumnaId;

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
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NinasProColors.warning100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: NinasProColors.warning900, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Registrar Podio Kahoot (US-29)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Asigna las 3 alumnas ganadoras del desafío de hoy. Se actualizará su historial.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1° Lugar
                  _buildDropdownKahoot(
                    label: '🥇 1° Lugar (Medalla de Oro):',
                    selectedValue: primerId,
                    presentes: presentes,
                    isDark: isDark,
                    onChanged: (val) {
                      if (val != null) setModalState(() => primerId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2° Lugar
                  _buildDropdownKahoot(
                    label: '🥈 2° Lugar (Medalla de Plata):',
                    selectedValue: segundoId,
                    presentes: presentes,
                    isDark: isDark,
                    onChanged: (val) {
                      if (val != null) setModalState(() => segundoId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3° Lugar
                  _buildDropdownKahoot(
                    label: '🥉 3° Lugar (Medalla de Bronce):',
                    selectedValue: tercerId,
                    presentes: presentes,
                    isDark: isDark,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tercerId = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: NinasProTheme.brandButton,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await widget.repository.guardarPodioKahoot(
                          sesionId: _sesionId,
                          primerLugarAlumnaId: primerId,
                          segundoLugarAlumnaId: segundoId,
                          tercerLugarAlumnaId: tercerId,
                        );
                        setState(() {
                          _primerLugarId = primerId;
                          _segundoLugarId = segundoId;
                          _tercerLugarId = tercerId;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: NinasProColors.success700,
                            content: Text('🏆 Podio Kahoot registrado con éxito.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Guardar Podio de la Sesión'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownKahoot({
    required String label,
    required String selectedValue,
    required List<RegistroAsistencia> presentes,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
              items: presentes.map((a) {
                return DropdownMenuItem(
                  value: a.alumnaId,
                  child: Text(a.alumnaNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: NinasProColors.primary700.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PCB-2026',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: NinasProColors.brandPink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Clase 04 · Python',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            Text(
              'Sábado 25 de Abril · Beauchef',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
          unselectedLabelColor: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          indicatorColor: NinasProColors.brandPink,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_rounded, size: 20), text: 'Asistencia P/A'),
            Tab(icon: Icon(Icons.code_rounded, size: 20), text: 'Ejercicios'),
            Tab(icon: Icon(Icons.camera_alt_rounded, size: 20), text: 'Fotos'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabAsistencia(isDark),
                _buildTabEjercicios(isDark),
                _buildTabFotos(isDark),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: NinasProColors.brandPink,
        foregroundColor: NinasProColors.neutral900,
        tooltip: 'Registrar Kahoot de la clase',
        onPressed: _mostrarModalRegistroKahoot,
        child: const Icon(Icons.emoji_events_rounded),
      ),
    );
  }

  // Pestaña 1: Pase de lista táctil rápido (US-13)
  Widget _buildTabAsistencia(bool isDark) {
    return Column(
      children: [
        // Barra resumen sticky con contadores
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCounterChip(
                  label: 'Presentes',
                  count: _totalPresentes,
                  estado: EstadoAsistencia.presente,
                ),
                const SizedBox(width: 8),
                _buildCounterChip(
                  label: 'Ausentes',
                  count: _totalAusentes,
                  estado: EstadoAsistencia.ausente,
                ),
                const SizedBox(width: 8),
                _buildCounterChip(
                  label: 'Justificadas',
                  count: _totalJustificadas,
                  estado: EstadoAsistencia.justificada,
                ),
              ],
            ),
          ),
        ),

        // Lista táctil de alumnas
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: _registros.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reg = _registros[index];
              final esJustificada = reg.estado == EstadoAsistencia.justificada;
              final tono = context.statusColors.asistencia(reg.estado);

              return Card(
                elevation: 0,
                color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: reg.estado == EstadoAsistencia.ausente
                        ? NinasProColors.error700.withValues(alpha: 0.5)
                        : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
                    width: reg.estado == EstadoAsistencia.ausente ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Avatar o iniciales
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                        child: Text(
                          reg.alumnaNombre.isNotEmpty ? reg.alumnaNombre[0] : 'A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Datos de la alumna
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reg.alumnaNombre,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  reg.alumnaRut,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                                  ),
                                ),
                                if (!reg.autorizaImagen)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: NinasProColors.warning100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Sin foto',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: NinasProColors.warning900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botón táctil grande (área táctil >= 48px) para alternar estado P/A
                      InkWell(
                        onTap: () => _ciclarEstado(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 105, minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: tono.decoration,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                esJustificada ? Icons.lock_outline_rounded : reg.estado.icon,
                                size: 16,
                                color: tono.foreground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                esJustificada ? 'Justificada' : reg.estado.label,
                                style: tono.textStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Barra inferior fija con el botón de guardar asistencia
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark900 : NinasProColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: NinasProTheme.brandButton,
                onPressed: _guardarAsistencia,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Guardar Asistencia de la Clase'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterChip({
    required String label,
    required int count,
    required EstadoAsistencia estado,
  }) {
    final tono = context.statusColors.asistencia(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: tono.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icon, size: 14, color: tono.foreground),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: tono.textStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // Pestaña 2: Registro de Ejercicios y Participación Activa (US-28)
  Widget _buildTabEjercicios(bool isDark) {
    final alumnasPresentes = _alumnasPresentes;

    if (alumnasPresentes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay alumnas marcadas como Presentes en esta sesión. '
            'Marca asistencia primero en la pestaña "Asistencia P/A".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NinasProColors.accent700.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: NinasProColors.accent700),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mostrando únicamente a las alumnas Presentes (US-28). '
                  'Las alumnas ausentes tienen bloqueado el registro de ejercicios.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...alumnasPresentes.map((reg) {
          final partIndex = _participaciones.indexWhere((p) => p.alumnaId == reg.alumnaId);
          final part = partIndex != -1
              ? _participaciones[partIndex]
              : ParticipacionClase(
                  id: 'part-${reg.alumnaId}',
                  sesionId: _sesionId,
                  alumnaId: reg.alumnaId,
                  alumnaNombre: reg.alumnaNombre,
                  ejerciciosResueltos: 3,
                  participacionActiva: true,
                );

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reg.alumnaNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('Ejercicios resueltos en aula:', style: TextStyle(fontSize: 12.5)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              if (part.ejerciciosResueltos > 0) {
                                setState(() {
                                  _actualizarParticipacion(
                                    part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos - 1),
                                  );
                                });
                              }
                            },
                          ),
                          Text(
                            '${part.ejerciciosResueltos}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () {
                              setState(() {
                                _actualizarParticipacion(
                                  part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos + 1),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('Participación activa en aula:', style: TextStyle(fontSize: 12.5)),
                      Switch(
                        value: part.participacionActiva,
                        activeThumbColor: NinasProColors.brandPink,
                        onChanged: (val) {
                          setState(() {
                            _actualizarParticipacion(part.copyWith(participacionActiva: val));
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _actualizarParticipacion(ParticipacionClase part) {
    final idx = _participaciones.indexWhere((p) => p.alumnaId == part.alumnaId);
    if (idx != -1) {
      _participaciones[idx] = part;
    } else {
      _participaciones.add(part);
    }
  }

  // Pestaña 3: Evidencia Fotográfica y Consentimientos de Imagen (US-18, US-19)
  Widget _buildTabFotos(bool isDark) {
    final alumnasSinFoto = _registros
        .where((r) => r.estado == EstadoAsistencia.presente && !r.autorizaImagen)
        .toList();

    final todasConFoto = alumnasSinFoto.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Card(
          elevation: 0,
          color: isDark ? NinasProColors.dark800 : NinasProColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      todasConFoto ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: todasConFoto ? NinasProColors.success700 : NinasProColors.warning700,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        todasConFoto
                            ? 'Foto 100% Apta para Redes / Sponsors'
                            : 'Atención: Restricción de Imagen',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (todasConFoto)
                  Text(
                    'Todas las alumnas presentes cuentan con autorización de imagen firmada por sus apoderados (US-19).',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                    ),
                  )
                else ...[
                  Text(
                    'Las siguientes alumnas presentes NO tienen consentimiento de imagen:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...alumnasSinFoto.map((a) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          '• ${a.alumnaNombre} (${a.alumnaRut})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: NinasProColors.error700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )),
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ La fotografía de la clase debe tomarse de espaldas o difuminar los rostros.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: NinasProColors.warning900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          height: 180,
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _fotoSubida ? Icons.photo_library_rounded : Icons.cloud_upload_outlined,
                size: 48,
                color: NinasProColors.brandPink,
              ),
              const SizedBox(height: 10),
              Text(
                _fotoSubida
                    ? 'Evidencia fotográfica lista y comprimida en cliente'
                    : 'Subir foto de la sesión desde el celular (US-18)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: NinasProTheme.brandButton,
                onPressed: () {
                  setState(() => _fotoSubida = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: NinasProColors.success700,
                      content: Text('📸 Foto comprimida (< 1.5 MB) y vinculada a la sesión.'),
                    ),
                  );
                },
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: Text(_fotoSubida ? 'Reemplazar Foto' : 'Tomar / Seleccionar Foto'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
