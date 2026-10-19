import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_stat_card.dart';

/// Panel Móvil de Gestión y Directorio para NiñasPro Hub.
///
/// Cubre:
/// - US-01: Catálogo de sedes territoriales y métricas operativas.
/// - US-07 y US-09: Nómina de alumnas, Ficha Única por RUT e historial multi-año en Bottom Sheet.
/// - US-39 y US-40: Detección y gestión confidencial de alertas de deserción escolar por 3 inasistencias.
/// - US-37: Bandeja de resolución de justificativos de inasistencia.
class DirectorioMobileScreen extends StatefulWidget {
  final HubRepository repository;

  const DirectorioMobileScreen({super.key, required this.repository});

  @override
  State<DirectorioMobileScreen> createState() => _DirectorioMobileScreenState();
}

class _DirectorioMobileScreenState extends State<DirectorioMobileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _cargando = true;
  List<Sede> _sedes = [];
  List<Alumna> _alumnas = [];
  List<AlertaDesercion> _alertas = [];
  List<Justificativo> _justificativos = [];
  String _filtroBusqueda = '';

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
    final sedes = await widget.repository.getSedes();
    final alumnas = await widget.repository.getAlumnas();
    final alertas = await widget.repository.getAlertasDesercion();
    final justs = await widget.repository.getJustificativos();

    setState(() {
      _sedes = sedes;
      _alumnas = alumnas;
      _alertas = alertas;
      _justificativos = justs;
      _cargando = false;
    });
  }

  // Bottom Sheet: Ficha Única de Alumna por RUT (US-09)
  void _verFichaUnica(Alumna alumna) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivoRetiroCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumna.nombreCompleto,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RUT: ${alumna.rut}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: alumna.retirado
                                ? NinasProColors.error100
                                : NinasProColors.success100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alumna.estadoMatricula,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: alumna.retirado
                                  ? NinasProColors.error900
                                  : NinasProColors.success900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Datos académicos
                    _buildInfoRow('Curso Actual', alumna.cursoNombre),
                    _buildInfoRow('Sede Territorial', alumna.sedeNombre),
                    _buildInfoRow('Asistencia Promedio', '${alumna.porcentajeAsistencia}%'),
                    _buildInfoRow(
                      'Uso de Imagen (US-10, US-12)',
                      alumna.autorizaImagen ? 'Autorizado por apoderado ✓' : 'NO Autorizado ✕',
                      color: alumna.autorizaImagen ? NinasProColors.success700 : NinasProColors.error700,
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Datos de apoderado
                    const Text('Datos del Apoderado (Contacto)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _buildInfoRow('Nombre', alumna.nombreApoderado),
                    _buildInfoRow('Teléfono', alumna.telefonoApoderado),
                    _buildInfoRow('Email', alumna.emailApoderado),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Historial Multi-año (US-09 Escenario 1)
                    const Text('Historial Educativo en NiñasPro',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (alumna.historialCursosPrevios.isEmpty)
                      Text(
                        'Primer ciclo formativo en la corporación (2026).',
                        style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      )
                    else
                      ...alumna.historialCursosPrevios.map((h) => Text('• $h', style: const TextStyle(fontSize: 12))),

                    const SizedBox(height: 20),

                    // Acción de Retiro Formal (US-09 Escenario 3)
                    if (!alumna.retirado)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NinasProColors.error700,
                            side: const BorderSide(color: NinasProColors.error700),
                          ),
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Registrar Retiro Formal (US-09)'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Indica el motivo formal de retiro. Su historial previo de asistencia quedará preservado.'),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: motivoRetiroCtrl,
                                      decoration: const InputDecoration(hintText: 'Ej. Cambio de ciudad o tope horario'),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      Navigator.pop(dCtx);
                                      Navigator.pop(ctx);
                                      await widget.repository.registrarRetiroAlumna(
                                        alumnaId: alumna.id,
                                        motivo: motivoRetiroCtrl.text.trim().isEmpty ? 'Motivo personal' : motivoRetiroCtrl.text.trim(),
                                      );
                                      await _cargarDatos();
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          backgroundColor: NinasProColors.warning900,
                                          content: Text('Matrícula marcada como retirada.'),
                                        ),
                                      );
                                    },
                                    child: const Text('Confirmar Retiro'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_remove_rounded, size: 18),
                          label: const Text('Registrar Retiro de Alumna'),
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

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Modal para atender alerta preventiva de deserción (US-40)
  void _atenderAlerta(AlertaDesercion alerta) {
    final obsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacto Preventivo (US-40)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alumna: ${alerta.alumnaNombre} (${alerta.inasistenciasConsecutivas} faltas seguidas).'),
            const SizedBox(height: 8),
            const Text(
              'Acompañamiento formativo: Coordina con el apoderado para resolver dificultades de transporte, conectividad o carga escolar.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Observación del contacto con la familia...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: NinasProTheme.brandButton,
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.repository.atenderAlertaDesercion(
                alertaId: alerta.id,
                observacion: obsCtrl.text.trim().isEmpty ? 'Contacto preventivo realizado exitosamente.' : obsCtrl.text.trim(),
              );
              await _cargarDatos();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: NinasProColors.success700,
                  content: Text('✅ Alerta resuelta y contacto registrado.'),
                ),
              );
            },
            child: const Text('Marcar Atendida'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Gestión y Sedes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
          unselectedLabelColor: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          indicatorColor: NinasProColors.brandPink,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 20), text: 'Resumen'),
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Nómina'),
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 20), text: 'Alertas'),
            Tab(icon: Icon(Icons.assignment_turned_in_rounded, size: 20), text: 'Justificativos'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabResumen(isDark),
                _buildTabNomina(isDark),
                _buildTabAlertas(isDark),
                _buildTabJustificativos(isDark),
              ],
            ),
    );
  }

  // Pestaña 1: Resumen y Catálogo de Sedes (US-01)
  Widget _buildTabResumen(bool isDark) {
    final totalAlumnas = _alumnas.length;
    final alertasPendientes = _alertas.where((a) => !a.atendida).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: NinasProStatCard(
                title: 'Alumnas Activas',
                value: '$totalAlumnas',
                subtitle: '4 sedes territoriales',
                icon: Icons.school_rounded,
                accentColor: NinasProColors.primary700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NinasProStatCard(
                title: 'Alertas Deserción',
                value: '$alertasPendientes',
                subtitle: 'Acción preventiva',
                icon: Icons.notifications_active_rounded,
                accentColor: NinasProColors.warning700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NinasProStatCard(
                title: 'Asistencia Red',
                value: '88.4%',
                subtitle: 'Meta >= 75% cumplida',
                icon: Icons.how_to_reg_rounded,
                accentColor: NinasProColors.success700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NinasProStatCard(
                title: 'Red Voluntariado',
                value: '39',
                subtitle: 'Tutoras activas',
                icon: Icons.volunteer_activism_rounded,
                accentColor: NinasProColors.brandPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Catálogo de Sedes y Cursos (US-01)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),

        ..._sedes.map((sede) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sede.nombre,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sede.modalidad,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sede.institucion,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      const SizedBox(width: 4),
                      Text('${sede.alumnasTotales} alumnas', style: const TextStyle(fontSize: 11.5)),
                      const SizedBox(width: 14),
                      Icon(Icons.book_outlined, size: 14, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      const SizedBox(width: 4),
                      Text('${sede.cursosActivos} cursos', style: const TextStyle(fontSize: 11.5)),
                      const SizedBox(width: 14),
                      Icon(Icons.badge_outlined, size: 14, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                      const SizedBox(width: 4),
                      Text('${sede.tutorasActivas} tutoras', style: const TextStyle(fontSize: 11.5)),
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

  // Pestaña 2: Nómina de Alumnas y Ficha Única (US-07, US-09)
  Widget _buildTabNomina(bool isDark) {
    final filtradas = _alumnas.where((a) {
      final q = _filtroBusqueda.toLowerCase();
      return a.nombreCompleto.toLowerCase().contains(q) || a.rut.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o RUT chileno...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _filtroBusqueda = ''),
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _filtroBusqueda = val),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: filtradas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final alumna = filtradas[index];
              return Card(
                elevation: 0,
                color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  onTap: () => _verFichaUnica(alumna),
                  title: Text(
                    alumna.nombreCompleto,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${alumna.rut} · ${alumna.sedeNombre} · ${alumna.porcentajeAsistencia}% asist.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Pestaña 3: Alertas Preventivas de Deserción Escolar (US-39, US-40)
  Widget _buildTabAlertas(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NinasProColors.warning100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: NinasProColors.warning900, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acompañamiento sin estigmatizar: Esta alerta es privada para el equipo de sede. '
                  'Las alumnas jamás verán distintivos de "riesgo" en su portal personal (US-40).',
                  style: TextStyle(fontSize: 12, color: NinasProColors.warning900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ..._alertas.map((alerta) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: alerta.atendida ? NinasProColors.success500 : NinasProColors.error500,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        alerta.alumnaNombre,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: alerta.atendida ? NinasProColors.success100 : NinasProColors.error100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alerta.atendida ? 'Atendida ✓' : '3 Inasistencias ⚠️',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: alerta.atendida ? NinasProColors.success900 : NinasProColors.error900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${alerta.alumnaRut} · ${alerta.cursoNombre} (${alerta.sedeNombre})',
                    style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                  if (alerta.observacionGestion != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? NinasProColors.dark700 : NinasProColors.neutral50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Registro de contacto: ${alerta.observacionGestion}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!alerta.atendida)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: () => _atenderAlerta(alerta),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: const Text('Contactar Apoderado y Resolver Alerta'),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // Pestaña 4: Bandeja de Justificativos (US-37)
  Widget _buildTabJustificativos(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Bandeja de Justificativos de Inasistencia (US-37)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        ..._justificativos.map((just) {
          final pendiente = just.estado == 'pendiente';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        just.alumnaNombre,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: just.estado == 'aprobado'
                              ? NinasProColors.success100
                              : (just.estado == 'rechazado' ? NinasProColors.error100 : NinasProColors.warning100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          just.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: just.estado == 'aprobado'
                                ? NinasProColors.success900
                                : (just.estado == 'rechazado' ? NinasProColors.error900 : NinasProColors.warning900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Motivo: ${just.motivoTipificado} · Clase: ${just.fechaSesion.day}/${just.fechaSesion.month}/${just.fechaSesion.year}',
                    style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                  const SizedBox(height: 8),
                  Text('Detalle: "${just.detalle}"', style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 12),

                  if (pendiente)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NinasProColors.error700,
                              side: const BorderSide(color: NinasProColors.error700),
                              minimumSize: const Size(64, 48),
                            ),
                            onPressed: () async {
                              await widget.repository.resolverJustificativo(
                                justificativoId: just.id,
                                nuevoEstado: 'rechazado',
                              );
                              await _cargarDatos();
                            },
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: NinasProColors.success700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(64, 48),
                            ),
                            onPressed: () async {
                              await widget.repository.resolverJustificativo(
                                justificativoId: just.id,
                                nuevoEstado: 'aprobado',
                              );
                              await _cargarDatos();
                            },
                            child: const Text('Aprobar'),
                          ),
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
}
