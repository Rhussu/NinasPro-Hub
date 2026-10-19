import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';

/// Pantalla móvil para el Equipo de Gestión de Sede en NiñasPro Hub.
///
/// Características clave:
/// - Todos los miembros del equipo de gestión son tutoras, pero tienen permisos extendidos de gestión de sede.
/// - Optimizado 100% para celulares con FAB interactivo y tarjetas táctiles (área >= 48px).
/// - US-37: Aprobación y resolución exclusiva de justificativos de inasistencia de alumnas.
/// - US-43: Asignación semanal de roles a tutoras (Facilitadora, Co-facilitadora, Soporte, Logística).
/// - US-33: Pase de lista y control de asistencia de tutoras en el aula.
/// - US-37/US-39: Alertas tempranas de deserción e inasistencias en la sede.
class GestionMobileScreen extends StatefulWidget {
  final HubRepository repository;

  const GestionMobileScreen({super.key, required this.repository});

  @override
  State<GestionMobileScreen> createState() => _GestionMobileScreenState();
}

class _GestionMobileScreenState extends State<GestionMobileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = true;

  List<Justificativo> _justificativos = [];
  List<Tutora> _tutoras = [];
  List<RolTutorConfig> _rolesConfig = [];
  List<AsignacionSemanalTutora> _asignaciones = [];
  List<AlertaDesercion> _alertas = [];

  final int _semanaActual = 4;

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
    final justs = await widget.repository.getJustificativos();
    final tuts = await widget.repository.getTutoras();
    final roles = await widget.repository.getRolesTutora();
    final asigs = await widget.repository.getAsignacionesSemanales(semanaNumero: _semanaActual);
    final alerts = await widget.repository.getAlertasDesercion();

    setState(() {
      _justificativos = justs;
      _tutoras = tuts;
      _rolesConfig = roles;
      _asignaciones = asigs;
      _alertas = alerts;
      _cargando = false;
    });
  }

  int get _justificativosPendientes =>
      _justificativos.where((j) => j.estado == 'pendiente').length;

  int get _alertasActivas =>
      _alertas.where((a) => a.estado == 'activa').length;

  // Diálogo para asignar rol semanal a una tutora (US-43)
  void _mostrarDialogoAsignarRol(Tutora tutora) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String rolSeleccionado = _rolesConfig.firstOrNull?.codigo ?? 'facilitadora';

    // Buscar si ya tiene asignación previa
    final asignacionActual = _asignaciones
        .where((a) => a.tutoraId == tutora.id && a.semanaNumero == _semanaActual)
        .firstOrNull;
    if (asignacionActual != null) {
      rolSeleccionado = asignacionActual.rolCodigo;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NinasProColors.primary700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: NinasProColors.brandPink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Asignar Rol Semanal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tutora.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    'Semana $_semanaActual · Sede Beauchef',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona la responsabilidad para esta sesión (US-43):',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ..._rolesConfig.map((rol) {
                    final sel = rolSeleccionado == rol.codigo;
                    return InkWell(
                      onTap: () => setDialogState(() => rolSeleccionado = rol.codigo),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              sel ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: sel ? NinasProColors.brandPink : NinasProColors.neutral500,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rol.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(rol.descripcion, style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: NinasProTheme.brandButton,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await widget.repository.asignarRolSemanal(
                      tutoraId: tutora.id,
                      semanaNumero: _semanaActual,
                      rolCodigo: rolSeleccionado,
                    );
                    await _cargarDatos();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: NinasProColors.success700,
                        content: Text('✅ Rol asignado a ${tutora.nombre} con éxito.'),
                      ),
                    );
                  },
                  child: const Text('Confirmar Asignación'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Modal para resolver justificativo de inasistencia (US-37)
  void _mostrarModalResolverJustificativo(Justificativo just) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final obsCtrl = TextEditingController(text: just.observacionesResolucion ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                      child: const Icon(Icons.rule_folder_rounded, color: NinasProColors.warning900, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revisar Justificativo (US-37)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? NinasProColors.white : NinasProColors.neutral900,
                            ),
                          ),
                          Text(
                            'Exclusivo Equipo de Gestión',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumna: ${just.alumnaNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clase / Fecha: ${just.sesionFecha.day}/${just.sesionFecha.month}/${just.sesionFecha.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${just.motivoTipificado}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${just.detalle}"',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Observaciones de la resolución (opcional):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Certificado recibido y verificado por gestión...',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NinasProColors.error700,
                          side: const BorderSide(color: NinasProColors.error700),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.repository.resolverJustificativo(
                            justificativoId: just.id,
                            aprobado: false,
                            observaciones: obsCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.error700,
                              content: Text('❌ Justificativo rechazado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: NinasProTheme.brandButton,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.repository.resolverJustificativo(
                            justificativoId: just.id,
                            aprobado: true,
                            observaciones: obsCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('✅ Justificativo aprobado. Asistencia recalculada a 70% min.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                    color: NinasProColors.accent700.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GESTIÓN SEDE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: NinasProColors.accent700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Coordinación de Aula',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            Text(
              'Beauchef · Sábado 25 de Abril',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: isDark ? NinasProColors.brandPink : NinasProColors.primary700,
          unselectedLabelColor: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          indicatorColor: NinasProColors.brandPink,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: _justificativosPendientes > 0,
                label: Text('$_justificativosPendientes'),
                child: const Icon(Icons.assignment_turned_in_outlined, size: 20),
              ),
              text: 'Justificativos',
            ),
            const Tab(
              icon: Icon(Icons.badge_outlined, size: 20),
              text: 'Roles Tutores',
            ),
            const Tab(
              icon: Icon(Icons.groups_outlined, size: 20),
              text: 'Tutoras Sede',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _alertasActivas > 0,
                label: Text('$_alertasActivas'),
                backgroundColor: NinasProColors.error700,
                child: const Icon(Icons.notifications_active_outlined, size: 20),
              ),
              text: 'Alertas',
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabJustificativos(isDark),
                _buildTabRolesTutores(isDark),
                _buildTabTutorasSede(isDark),
                _buildTabAlertas(isDark),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NinasProColors.brandPink,
        foregroundColor: NinasProColors.neutral900,
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Acciones Rápidas', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () {
          // BottomSheet con accesos directos
          _mostrarMenuAccionesRapidas(context, isDark);
        },
      ),
    );
  }

  void _mostrarMenuAccionesRapidas(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operaciones Rápidas de Gestión',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: NinasProColors.warning100,
                  child: Icon(Icons.pending_actions, color: NinasProColors.warning900),
                ),
                title: const Text('Resolver Justificativos Pendientes', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('$_justificativosPendientes solicitudes por evaluar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: NinasProColors.primary100,
                  child: Icon(Icons.how_to_reg, color: NinasProColors.primary900),
                ),
                title: const Text('Asignar Roles Semanales a Tutoras', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Facilitadora, Co-facilitadora, Soporte, Logística'),
                onTap: () {
                  Navigator.pop(ctx);
                  _tabController.animateTo(1);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: NinasProColors.error100,
                  child: Icon(Icons.warning_amber_rounded, color: NinasProColors.error900),
                ),
                title: const Text('Ver Alertas Tempranas de Deserción', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('$_alertasActivas alumnas en riesgo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _tabController.animateTo(3);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pestaña 1: Bandeja de Justificativos (US-37)
  Widget _buildTabJustificativos(bool isDark) {
    if (_justificativos.isEmpty) {
      return const Center(child: Text('No hay justificativos registrados.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      itemCount: _justificativos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final j = _justificativos[index];
        final esPendiente = j.estado == 'pendiente';
        final esAprobado = j.estado == 'aprobado';

        return Card(
          elevation: 0,
          color: isDark ? NinasProColors.dark800 : NinasProColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: esPendiente
                  ? NinasProColors.warning500
                  : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
              width: esPendiente ? 1.5 : 1.0,
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
                    Expanded(
                      child: Text(
                        j.alumnaNombre,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esPendiente
                            ? NinasProColors.warning100
                            : (esAprobado ? NinasProColors.success100 : NinasProColors.error100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        j.estado.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: esPendiente
                              ? NinasProColors.warning900
                              : (esAprobado ? NinasProColors.success900 : NinasProColors.error900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Clase del ${j.sesionFecha.day}/${j.sesionFecha.month}/${j.sesionFecha.year} · Motivo: ${j.motivoTipificado}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${j.detalle}"',
                  style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
                if (j.observacionesResolucion != null && j.observacionesResolucion!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Resolución Gestión: ${j.observacionesResolucion}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _mostrarModalResolverJustificativo(j),
                    icon: Icon(
                      esPendiente ? Icons.gavel_rounded : Icons.edit_note_rounded,
                      size: 16,
                    ),
                    label: Text(esPendiente ? 'Evaluar Justificativo' : 'Modificar Resolución'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pestaña 2: Asignación Semanal de Roles a Tutoras (US-43)
  Widget _buildTabRolesTutores(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NinasProColors.primary700.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.diversity_3_rounded, color: NinasProColors.brandPink, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'US-43: Asignación semanal de roles a tutoras de aula. '
                  'Garantiza que cada sesión cuente con facilitadoras y soporte.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Tutoras de la Sede y su Rol Semanal:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ..._tutoras.map((tutora) {
          final asignacion = _asignaciones
              .where((a) => a.tutoraId == tutora.id && a.semanaNumero == _semanaActual)
              .firstOrNull;
          final rolActual = _rolesConfig
              .where((r) => r.codigo == asignacion?.rolCodigo)
              .firstOrNull;

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
                backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                child: Text(
                  tutora.nombre[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      tutora.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  if (tutora.esEquipoGestion)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: NinasProColors.accent700.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Gestión',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: NinasProColors.accent700),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                rolActual != null
                    ? 'Rol Sem. $_semanaActual: ${rolActual.nombre}'
                    : 'Sin rol asignado para la semana $_semanaActual',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: rolActual != null ? FontWeight.w700 : FontWeight.w400,
                  color: rolActual != null
                      ? NinasProColors.brandPink
                      : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                tooltip: 'Asignar o Cambiar Rol',
                onPressed: () => _mostrarDialogoAsignarRol(tutora),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Pestaña 3: Tutoras Sede y Asistencia (US-33)
  Widget _buildTabTutorasSede(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        const Text(
          'Supervisión y Asistencia de Tutoras (US-33)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Marca la presencia de las tutoras y verifica su adhesión voluntaria firmada.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
          ),
        ),
        const SizedBox(height: 12),
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
                backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.accent100,
                child: Text(
                  tut.nombre[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? NinasProColors.accent300 : NinasProColors.accent900,
                  ),
                ),
              ),
              title: Text(
                tut.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Text(
                'Adhesión: ${tut.adhesionFirmada ? "Firmada ✅" : "Pendiente ⚠️"} · ${tut.rol}',
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

  // Pestaña 4: Alertas Tempranas de Deserción (US-37/US-39)
  Widget _buildTabAlertas(bool isDark) {
    if (_alertas.isEmpty) {
      return const Center(child: Text('No hay alertas activas en esta sede.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      itemCount: _alertas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final a = _alertas[index];
        final esActiva = a.estado == 'activa';

        return Card(
          elevation: 0,
          color: isDark ? NinasProColors.dark800 : NinasProColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: esActiva
                  ? NinasProColors.error700
                  : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
              width: esActiva ? 1.5 : 1.0,
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
                    Expanded(
                      child: Text(
                        a.alumnaNombre,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esActiva ? NinasProColors.error100 : NinasProColors.success100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        esActiva ? 'EN RIESGO' : 'CONTACTADA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: esActiva ? NinasProColors.error900 : NinasProColors.success900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${a.inasistenciasConsecutivas} inasistencias consecutivas registradas.',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apoderada: ${a.apoderadoContacto}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: esActiva
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.repository.contactarAlerta(
                              alertaId: a.id,
                              observacionesContacto: 'Contactada por equipo de gestión vía WhatsApp.',
                            );
                            await _cargarDatos();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: NinasProColors.success700,
                                content: Text('📞 Alerta marcada como contactada.'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: Text(esActiva ? 'Registrar Contacto' : 'Ya contactada'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
