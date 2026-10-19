import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';

/// Pantalla móvil para la tutora en el aula de clases.
///
/// Cubre:
/// - US-13: Pase de lista rápido táctil de alumnas optimizado para móvil (área táctil >= 48px).
/// - US-28: Registro de ejercicios resueltos y participación activa para alumnas presentes.
/// - US-18 y US-19: Verificación de consentimiento de imagen antes de subir evidencia fotográfica.
/// - US-33: Pase de lista de docentes / tutoras acompañantes.
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
  List<Tutora> _tutoras = [];
  bool _fotoSubida = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final tut = await widget.repository.getTutoras();

    setState(() {
      _registros = List.from(reg);
      _participaciones = List.from(part);
      _tutoras = List.from(tut);
      _cargando = false;
    });
  }

  void _ciclarEstado(int index) {
    final actual = _registros[index].estado;
    final nuevo = switch (actual) {
      EstadoAsistencia.presente => EstadoAsistencia.ausente,
      EstadoAsistencia.ausente => EstadoAsistencia.justificada,
      EstadoAsistencia.justificada => EstadoAsistencia.presente,
      EstadoAsistencia.pendiente => EstadoAsistencia.presente,
    };

    setState(() {
      _registros[index] = _registros[index].copyWith(
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
          '✅ Asistencia guardada: $_totalPresentes presentes, $_totalAusentes ausentes '
          '(${stopwatch.elapsedMilliseconds} ms). Clase marcada como realizada.',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
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
          isScrollable: true,
          labelColor: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
          unselectedLabelColor:
              isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          indicatorColor: NinasProColors.brandPink,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_rounded, size: 20), text: 'Asistencia'),
            Tab(icon: Icon(Icons.code_rounded, size: 20), text: 'Ejercicios'),
            Tab(icon: Icon(Icons.camera_alt_rounded, size: 20), text: 'Fotos'),
            Tab(icon: Icon(Icons.groups_rounded, size: 20), text: 'Tutoras'),
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
                _buildTabTutoras(isDark),
              ],
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
                        backgroundColor:
                            isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                        child: Text(
                          reg.alumnaNombre.isNotEmpty ? reg.alumnaNombre[0] : 'A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? NinasProColors.primary300
                                : NinasProColors.primary900,
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  reg.alumnaRut,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? NinasProColors.neutral300
                                        : NinasProColors.neutral500,
                                  ),
                                ),
                                if (!reg.autorizaImagen) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
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
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botón táctil grande (área táctil >= 48px) para alternar estado
                      InkWell(
                        onTap: () => _ciclarEstado(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 100, minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: tono.decoration,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(reg.estado.icon, size: 16, color: tono.foreground),
                              const SizedBox(width: 6),
                              Text(
                                reg.estado.label,
                                style: tono.textStyle(fontSize: 12.5),
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

        // Barra inferior fija con el botón de acción principal (marca rosa)
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
    // Escenario 1 y 2 de US-28: Solo las presentes pueden registrar ejercicios
    final alumnasPresentes = _registros
        .where((r) => r.estado == EstadoAsistencia.presente)
        .toList();

    if (alumnasPresentes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay alumnas marcadas como Presentes en esta sesión. '
            'Marca asistencia primero en la pestaña "Asistencia".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NinasProColors.accent700.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: NinasProColors.accent700),
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
        const SizedBox(height: 16),
        ...alumnasPresentes.map((reg) {
          final partIndex =
              _participaciones.indexWhere((p) => p.alumnaId == reg.alumnaId);
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        reg.alumnaNombre,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (part.podioKahoot != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NinasProColors.warning100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🏆 Kahoot #${part.podioKahoot}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: NinasProColors.warning900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ejercicios resueltos:',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              if (part.ejerciciosResueltos > 0) {
                                setState(() {
                                  _actualizarParticipacion(
                                    part.copyWith(
                                      ejerciciosResueltos:
                                          part.ejerciciosResueltos - 1,
                                    ),
                                  );
                                });
                              }
                            },
                          ),
                          Text(
                            '${part.ejerciciosResueltos}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () {
                              setState(() {
                                _actualizarParticipacion(
                                  part.copyWith(
                                    ejerciciosResueltos:
                                        part.ejerciciosResueltos + 1,
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Participación activa en aula:',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      Switch(
                        value: part.participacionActiva,
                        activeThumbColor: NinasProColors.brandPink,
                        onChanged: (val) {
                          setState(() {
                            _actualizarParticipacion(
                              part.copyWith(participacionActiva: val),
                            );
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
    // Alumnas presentes que NO tienen autorización de imagen
    final alumnasSinFoto = _registros
        .where((r) => r.estado == EstadoAsistencia.presente && !r.autorizaImagen)
        .toList();

    final todasConFoto = alumnasSinFoto.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
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
                      todasConFoto
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: todasConFoto
                          ? NinasProColors.success700
                          : NinasProColors.warning700,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        todasConFoto
                          ? 'Foto 100% Apta para Redes / Sponsors'
                          : 'Atención: Restricción de Imagen',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (todasConFoto)
                  Text(
                    'Todas las alumnas presentes cuentan con autorización de imagen '
                    'firmada por sus apoderados (US-19). La foto puede publicarse libremente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? NinasProColors.neutral300
                          : NinasProColors.neutral700,
                    ),
                  )
                else ...[
                  Text(
                    'Las siguientes alumnas presentes NO tienen consentimiento de imagen:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NinasProColors.neutral300
                          : NinasProColors.neutral700,
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

        // Simulación de subida móvil con compresión (US-18)
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300,
              style: BorderStyle.solid,
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

  // Pestaña 4: Asistencia de tutoras / voluntarias (US-33)
  Widget _buildTabTutoras(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pase de Lista de Tutoras y Docentes (US-33)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Registra qué voluntarias están presentes hoy facilitando la sesión.',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          ),
        ),
        const SizedBox(height: 14),
        ..._tutoras.map((tut) {
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
              leading: CircleAvatar(
                backgroundColor:
                    isDark ? NinasProColors.dark700 : NinasProColors.accent100,
                child: Text(
                  tut.nombre[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? NinasProColors.accent300
                        : NinasProColors.accent900,
                  ),
                ),
              ),
              title: Text(
                tut.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                '${tut.rol} · Adhesión firmada: ${tut.adhesionFirmada ? "Sí" : "No"}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                ),
              ),
              trailing: Switch(
                value: tut.presenteClaseActual,
                activeThumbColor: NinasProColors.brandPink,
                onChanged: (val) async {
                  await widget.repository.actualizarAsistenciaTutora(
                    tutoraId: tut.id,
                    presente: val,
                  );
                  setState(() {
                    final idx = _tutoras.indexWhere((t) => t.id == tut.id);
                    if (idx != -1) {
                      _tutoras[idx] = _tutoras[idx].copyWith(presenteClaseActual: val);
                    }
                  });
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
