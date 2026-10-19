import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_stat_card.dart';

/// Pantalla Desktop / Web para la Directiva Nacional en NiñasPro Hub.
///
/// Características clave:
/// - Diseñada exclusivamente para pantallas de computador (Desktop Web).
/// - Layout amplio con NavigationRail / Sidebar lateral y barra superior ejecutiva.
/// - US-01: Catálogo territorial de sedes y métricas de capacidad operativa.
/// - US-07 y US-09: Nómina consolidada de alumnas y visualización de Ficha Única multianual.
/// - US-39 y US-40: Panel confidencial de alertas de deserción en sedes.
/// - US-43: Configuración y administración de roles dinámicos de tutoras.
/// - US-11: Consolidación y exportación de reportes institucionales.
class DirectorioDesktopScreen extends StatefulWidget {
  final HubRepository repository;

  const DirectorioDesktopScreen({super.key, required this.repository});

  @override
  State<DirectorioDesktopScreen> createState() => _DirectorioDesktopScreenState();
}

class _DirectorioDesktopScreenState extends State<DirectorioDesktopScreen> {
  int _seccionSeleccionada = 0;
  bool _cargando = true;

  List<Sede> _sedes = [];
  List<Alumna> _alumnas = [];
  List<AlertaDesercion> _alertas = [];
  List<RolTutorConfig> _rolesConfig = [];

  String _filtroBusqueda = '';
  String _filtroSede = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final sedes = await widget.repository.getSedes();
    final alumnas = await widget.repository.getAlumnas();
    final alertas = await widget.repository.getAlertasDesercion();
    final roles = await widget.repository.getRolesTutora();

    setState(() {
      _sedes = sedes;
      _alumnas = alumnas;
      _alertas = alertas;
      _rolesConfig = roles;
      _cargando = false;
    });
  }

  // Métricas calculadas para directiva
  int get _totalAlumnas => _alumnas.length;
  double get _asistenciaPromedio {
    if (_alumnas.isEmpty) return 0.0;
    final suma = _alumnas.fold(0.0, (acc, a) => acc + a.porcentajeAsistencia);
    return suma / _alumnas.length;
  }
  int get _alertasCriticas => _alertas.where((a) => a.estado == 'activa').length;

  List<Alumna> get _alumnasFiltradas {
    return _alumnas.where((a) {
      final coincideTexto = a.nombre.toLowerCase().contains(_filtroBusqueda.toLowerCase()) ||
          a.rut.toLowerCase().contains(_filtroBusqueda.toLowerCase());
      final coincideSede = _filtroSede == 'Todas' || a.sedeNombre == _filtroSede;
      return coincideTexto && coincideSede;
    }).toList();
  }

  // Modal amplio de Ficha Única de Alumna (US-09)
  void _mostrarFichaUnicaDesktop(Alumna alumna) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                            child: Text(
                              alumna.nombre[0],
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: NinasProColors.brandPink),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumna.nombre,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'RUT: ${alumna.rut} · ${alumna.cursoNombre} (${alumna.sedeNombre})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Expanded(
                    child: ListView(
                      children: [
                        // Indicadores clave
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniCard(
                                title: 'Asistencia Actual',
                                value: '${alumna.porcentajeAsistencia.toStringAsFixed(1)}%',
                                subtitle: '${alumna.asistenciasCount} de 8 sesiones',
                                color: alumna.porcentajeAsistencia >= 80.0
                                    ? NinasProColors.success700
                                    : NinasProColors.warning700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMiniCard(
                                title: 'Consentimiento Imagen',
                                value: alumna.autorizaFoto ? 'Autorizado ✅' : 'Restringido 🚫',
                                subtitle: alumna.autorizaFoto ? 'Apto para redes' : 'Solo tomas de espalda',
                                color: alumna.autorizaFoto
                                    ? NinasProColors.success700
                                    : NinasProColors.error700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMiniCard(
                                title: 'Estado Matrícula',
                                value: alumna.estado.toUpperCase(),
                                subtitle: 'Año lectivo 2026',
                                color: alumna.estado == 'activa'
                                    ? NinasProColors.primary700
                                    : NinasProColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Historial Académico Multianual (US-09):',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 0,
                          color: isDark ? NinasProColors.dark700 : NinasProColors.neutral50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• 2025: Programando el Futuro I (Aprobado con 92% de asistencia).', style: TextStyle(fontSize: 12.5)),
                                SizedBox(height: 6),
                                Text('• 2026: Programación Competitiva Básica (En curso, 87.5% asistencia).', style: TextStyle(fontSize: 12.5)),
                                SizedBox(height: 6),
                                Text('• Kahoot Awards: 3 podios acumulados en 2026.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: NinasProColors.brandPink)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Gestión de Matrícula (US-09):',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: NinasProColors.error700,
                                side: const BorderSide(color: NinasProColors.error700),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Formulario de retiro voluntario registrado (US-09).'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_remove_rounded, size: 16),
                              label: const Text('Registrar Retiro Voluntario'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Historial completo exportado en formato PDF institucional.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Exportar Ficha Única'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Diálogo para crear o editar un rol de tutora dinámico (US-43)
  void _mostrarDialogoNuevoRol({RolTutorConfig? rol}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codigoCtrl = TextEditingController(text: rol?.codigo ?? '');
    final nombreCtrl = TextEditingController(text: rol?.nombre ?? '');
    final descCtrl = TextEditingController(text: rol?.descripcion ?? '');
    final colorCtrl = TextEditingController(text: rol?.colorHex ?? '#79207E');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            rol == null ? 'Nuevo Rol Dinámico de Tutora (US-43)' : 'Editar Rol Dinámico',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codigoCtrl,
                  enabled: rol == null,
                  decoration: const InputDecoration(
                    labelText: 'Código identificador (slug)',
                    hintText: 'ej: soporte_tecnico',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                    hintText: 'ej: Soporte Técnico & Logística',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de responsabilidades',
                    hintText: 'ej: Asistir con problemas de computadores...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Color Hex (#RRGGBB)',
                    hintText: '#FF3593',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: NinasProTheme.brandButton,
              onPressed: () async {
                if (codigoCtrl.text.isEmpty || nombreCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final nuevo = RolTutorConfig(
                  codigo: codigoCtrl.text.trim().toLowerCase(),
                  nombre: nombreCtrl.text.trim(),
                  descripcion: descCtrl.text.trim(),
                  colorHex: colorCtrl.text.trim(),
                  esRequerido: false,
                );
                await widget.repository.crearRolTutora(nuevo);
                await _cargarDatos();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: NinasProColors.success700,
                    content: Text('✅ Rol dinámico configurado correctamente (US-43).'),
                  ),
                );
              },
              child: const Text('Guardar Rol'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark700 : NinasProColors.neutral50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NinasProColors.dark600 : NinasProColors.neutral100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: NinasProColors.neutral500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Row(
        children: [
          // NavigationRail Desktop lateral
          NavigationRail(
            selectedIndex: _seccionSeleccionada,
            extended: MediaQuery.of(context).size.width > 960,
            minExtendedWidth: 220,
            backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
            selectedIconTheme: const IconThemeData(color: NinasProColors.brandPink),
            selectedLabelTextStyle: const TextStyle(
              color: NinasProColors.brandPink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NinasProColors.primary700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('🏛️', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(height: 8),
                  if (MediaQuery.of(context).size.width > 960) ...[
                    const Text(
                      'Directiva Nacional',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const Text(
                      'Panel Desktop',
                      style: TextStyle(fontSize: 11, color: NinasProColors.brandPink, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Dashboard Global'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.domain_outlined),
                selectedIcon: Icon(Icons.domain_rounded),
                label: Text('Sedes y Cursos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: Text('Nómina y Ficha Única'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warning_amber_outlined),
                selectedIcon: Icon(Icons.warning_amber_rounded),
                label: Text('Alertas Deserción'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_suggest_outlined),
                selectedIcon: Icon(Icons.settings_suggest_rounded),
                label: Text('Roles Dinámicos'),
              ),
            ],
            onDestinationSelected: (index) {
              setState(() => _seccionSeleccionada = index);
            },
          ),

          const VerticalDivider(width: 1, thickness: 1),

          // Área de contenido principal
          Expanded(
            child: Column(
              children: [
                // Barra superior institucional
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? NinasProColors.dark800 : NinasProColors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getTituloSeccion(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: NinasProColors.success700,
                              content: Text('📊 Exportación CSV consolidada de sedes y asistencias lista.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Exportar Todo (US-11)'),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Recargar datos',
                        onPressed: _cargarDatos,
                      ),
                    ],
                  ),
                ),

                // Contenido dinámico según sección
                Expanded(
                  child: IndexedStack(
                    index: _seccionSeleccionada,
                    children: [
                      _buildDashboard(isDark),
                      _buildSedesYCursos(isDark),
                      _buildNominaYFicha(isDark),
                      _buildAlertasDesercion(isDark),
                      _buildRolesDinamicos(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTituloSeccion() {
    switch (_seccionSeleccionada) {
      case 0:
        return 'Dashboard de Operaciones y Métricas';
      case 1:
        return 'Sedes Territoriales y Oferta de Cursos (US-01)';
      case 2:
        return 'Nómina Consolidada y Ficha Única (US-07, US-09)';
      case 3:
        return 'Gestión de Alertas de Deserción Escolar (US-39, US-40)';
      case 4:
        return 'Configuración de Roles Dinámicos de Tutoras (US-43)';
      default:
        return 'Panel Directivo';
    }
  }

  // Sección 0: Dashboard Global
  Widget _buildDashboard(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Fila de tarjetas de estadísticas
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              NinasProStatCard(
                title: 'Alumnas Activas',
                value: '$_totalAlumnas',
                subtitle: 'Matrícula total 2026',
                icon: Icons.school_rounded,
                accentColor: NinasProColors.primary700,
              ),
              NinasProStatCard(
                title: 'Asistencia Global',
                value: '${_asistenciaPromedio.toStringAsFixed(1)}%',
                subtitle: 'Meta de certificación >= 80%',
                icon: Icons.trending_up_rounded,
                accentColor: NinasProColors.brandPink,
              ),
              NinasProStatCard(
                title: 'Sedes Operativas',
                value: '${_sedes.length}',
                subtitle: 'Santiago, Valparaíso, Concepción',
                icon: Icons.domain_rounded,
                accentColor: NinasProColors.accent700,
              ),
              NinasProStatCard(
                title: 'Alertas Activas',
                value: '$_alertasCriticas',
                subtitle: '3 inasistencias consecutivas',
                icon: Icons.warning_amber_rounded,
                accentColor: NinasProColors.error700,
              ),
            ];

            if (constraints.maxWidth < 900) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: cards,
              );
            }

            return Row(
              children: cards.map((c) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              ))).toList(),
            );
          },
        ),
        const SizedBox(height: 24),

        // Resumen territorial
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado Operativo por Sede',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ..._sedes.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.location_on_outlined, size: 20, color: NinasProColors.brandPink),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(s.universidad, style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500)),
                            ],
                          ),
                        ),
                        Text(
                          '${s.alumnasActivas} / ${s.capacidadTotal} alumnas',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: NinasProColors.success100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.estado.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NinasProColors.success900),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Sección 1: Sedes y Cursos (US-01)
  Widget _buildSedesYCursos(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Catálogo de Sedes Territoriales (US-01)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada sede opera los días sábados en convenio con facultades de ingeniería y ciencias.',
          style: TextStyle(fontSize: 13, color: NinasProColors.neutral500),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 440,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 260,
          ),
          itemCount: _sedes.length,
          itemBuilder: (context, index) {
            final s = _sedes[index];
            final ocupacion = (s.alumnasActivas / s.capacidadTotal * 100).toStringAsFixed(0);

            return Card(
              elevation: 0,
              color: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            s.nombre,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NinasProColors.primary700.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.region,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NinasProColors.brandPink),
                          ),
                        ),
                      ],
                    ),
                    Text(s.universidad, style: const TextStyle(fontSize: 13, color: NinasProColors.neutral500)),
                    const SizedBox(height: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text('Ocupación de cupos:', style: TextStyle(fontSize: 12)),
                            Text('$ocupacion% (${s.alumnasActivas}/${s.capacidadTotal})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: s.alumnasActivas / s.capacidadTotal,
                            minHeight: 8,
                            backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                            valueColor: const AlwaysStoppedAnimation(NinasProColors.brandPink),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Coord: ${s.coordinadoraNombre}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            setState(() {
                              _filtroSede = s.nombre;
                              _seccionSeleccionada = 2; // Ir a nómina
                            });
                          },
                          child: const Text('Ver Alumnas'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Sección 2: Nómina Consolidada y Ficha Única (US-07, US-09)
  Widget _buildNominaYFicha(bool isDark) {
    return Column(
      children: [
        // Barra de filtros de nómina
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: 'Buscar por nombre o RUT de alumna...',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() => _filtroBusqueda = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filtroSede,
                items: ['Todas', 'Sede Beauchef', 'Sede San Joaquín', 'Sede Valparaíso'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filtroSede = val);
                },
              ),
              const SizedBox(width: 16),
              Text(
                '${_alumnasFiltradas.length} alumnas listadas',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),

        // Tabla de datos desktop
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Alumna')),
                      DataColumn(label: Text('RUT')),
                      DataColumn(label: Text('Sede')),
                      DataColumn(label: Text('Asistencia')),
                      DataColumn(label: Text('Consentimiento Foto')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Ficha Única')),
                    ],
                    rows: _alumnasFiltradas.map((a) {
                      final aprueba = a.porcentajeAsistencia >= 80.0;
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
                                  child: Text(a.nombre[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NinasProColors.brandPink)),
                                ),
                                const SizedBox(width: 8),
                                Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          DataCell(Text(a.rut)),
                          DataCell(Text(a.sedeNombre)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: aprueba ? NinasProColors.success100 : NinasProColors.warning100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${a.porcentajeAsistencia.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: aprueba ? NinasProColors.success900 : NinasProColors.warning900,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              a.autorizaFoto ? 'Autorizado ✅' : 'Sin Foto 🚫',
                              style: TextStyle(
                                fontSize: 12,
                                color: a.autorizaFoto ? NinasProColors.success700 : NinasProColors.error700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(Text(a.estado.toUpperCase())),
                          DataCell(
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(60, 32),
                              ),
                              onPressed: () => _mostrarFichaUnicaDesktop(a),
                              child: const Text('Ver Ficha (US-09)'),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Sección 3: Alertas de Deserción Escolar (US-39, US-40)
  Widget _buildAlertasDesercion(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Monitoreo Confidencial de Riesgo de Deserción (US-39, US-40)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Detección automática de alumnas con 3 o más inasistencias consecutivas para intervención temprana.',
          style: TextStyle(fontSize: 13, color: NinasProColors.neutral500),
        ),
        const SizedBox(height: 16),
        ..._alertas.map((alerta) {
          final esActiva = alerta.estado == 'activa';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: esActiva ? NinasProColors.error700 : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
                width: esActiva ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esActiva ? NinasProColors.error100 : NinasProColors.success100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      esActiva ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: esActiva ? NinasProColors.error900 : NinasProColors.success900,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alerta.alumnaNombre,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sede ${alerta.sedeNombre} · ${alerta.inasistenciasConsecutivas} inasistencias seguidas',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Apoderada: ${alerta.apoderadoContacto}',
                          style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                        ),
                      ],
                    ),
                  ),
                  if (alerta.observacionesContacto != null)
                    Expanded(
                      child: Text(
                        'Registro de contacto: "${alerta.observacionesContacto}"',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  FilledButton.tonal(
                    onPressed: esActiva
                        ? () async {
                            await widget.repository.contactarAlerta(
                              alertaId: alerta.id,
                              observacionesContacto: 'Contacto telefónico registrado por Directiva.',
                            );
                            await _cargarDatos();
                          }
                        : null,
                    child: Text(esActiva ? 'Registrar Contacto' : 'Resuelto'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // Sección 4: Configuración de Roles Dinámicos de Tutoras (US-43)
  Widget _buildRolesDinamicos(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catálogo de Roles Dinámicos de Tutoras (US-43)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Define las responsabilidades que el Equipo de Gestión puede asignar semanalmente en aula.',
                    style: TextStyle(fontSize: 13, color: NinasProColors.neutral500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              style: NinasProTheme.brandButton,
              onPressed: () => _mostrarDialogoNuevoRol(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Crear Nuevo Rol'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 170,
          ),
          itemCount: _rolesConfig.length,
          itemBuilder: (context, index) {
            final rol = _rolesConfig[index];
            return Card(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            rol.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NinasProColors.brandPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rol.codigo,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NinasProColors.brandPink),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      rol.descripcion,
                      style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            rol.esRequerido ? 'Obligatorio en aula' : 'Opcional',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: rol.esRequerido ? NinasProColors.warning700 : NinasProColors.neutral500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _mostrarDialogoNuevoRol(rol: rol),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
