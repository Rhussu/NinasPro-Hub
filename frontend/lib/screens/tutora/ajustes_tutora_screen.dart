import 'package:flutter/material.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../ajustes/ajustes_screen.dart';

/// Ajustes de la Tutora: perfil de la tutora y su sede.
/// La estructura común (apariencia, cerrar sesión) la aporta [AjustesScreen].
/// El Equipo de Gestión reutiliza esta pantalla con otra etiqueta de rol.
class AjustesTutoraScreen extends StatefulWidget {
  final HubRepository repository;
  final String tutoraId;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;

  /// Etiqueta y emoji del rol que se muestran en el perfil
  final String rolEtiqueta;
  final String rolEmoji;

  const AjustesTutoraScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-3', // Misma tutora por defecto que TutoraMobileScreen
    this.themeNotifier,
    this.onCerrarSesion,
    this.rolEtiqueta = 'Tutora',
    this.rolEmoji = '👩‍🏫',
  });

  @override
  State<AjustesTutoraScreen> createState() => _AjustesTutoraScreenState();
}

class _AjustesTutoraScreenState extends State<AjustesTutoraScreen> {
  bool _cargando = true;
  Tutora? _tutora;
  Curso? _curso;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final tutoras = await widget.repository.getTutoras();
    final tutora = tutoras.where((t) => t.id == widget.tutoraId).firstOrNull;
    final cursos = tutora == null
        ? const <Curso>[]
        : await widget.repository.getCursos(sedeId: tutora.sedeId);
    if (!mounted) return;
    setState(() {
      _tutora = tutora;
      _curso = cursos.firstOrNull;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutora = _tutora;

    return AjustesScreen(
      cargando: _cargando,
      themeNotifier: widget.themeNotifier,
      onCerrarSesion: widget.onCerrarSesion,
      perfil: tutora == null
          ? null
          : AjustesPerfil(
              nombre: tutora.nombre,
              detalle: tutora.sedeNombre,
              rolEtiqueta: widget.rolEtiqueta,
              rolEmoji: widget.rolEmoji,
            ),
      secciones: tutora == null ? const [] : _buildSecciones(tutora),
    );
  }

  List<Widget> _buildSecciones(Tutora tutora) {
    return [
      AjustesSeccion(
        titulo: 'Mi perfil',
        children: [
          AjustesTile(icono: Icons.location_on_rounded, titulo: 'Sede', subtitulo: tutora.sedeNombre),
          if (_curso != null)
            AjustesTile(icono: Icons.school_rounded, titulo: 'Curso', subtitulo: _curso!.nombre),
          AjustesTile(
            icono: Icons.verified_user_rounded,
            titulo: 'Adhesión voluntaria',
            subtitulo: tutora.adhesionFirmada ? 'Firmada' : 'Pendiente de firma',
          ),
        ],
      ),
    ];
  }
}
