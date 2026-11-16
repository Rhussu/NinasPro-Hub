import 'package:flutter/material.dart';
import '../../models/hub_models.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../ajustes/ajustes_screen.dart';

String _fecha(DateTime f) => '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Ajustes de la Tutora: su perfil, sus sedes y cursos, y su ficha del voluntariado.
/// La estructura común (apariencia, cerrar sesión) la aporta [AjustesScreen].
/// El Equipo de Gestión reutiliza esta pantalla con otra etiqueta de rol.
class AjustesTutoraScreen extends StatefulWidget {
  final SesionUsuario sesion;

  /// Su ficha: adhesión, institución e ingreso (US-31, US-32)
  final VoluntariadoRepository? voluntariado;

  /// Los cursos en que está asignada
  final ClaseRepository? clase;

  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;

  /// Etiqueta y emoji del rol que se muestran en el perfil
  final String rolEtiqueta;
  final String rolEmoji;

  /// Secciones propias del rol que reutiliza la pantalla (ej. Administración de Gestión)
  final List<Widget> seccionesExtra;

  const AjustesTutoraScreen({
    super.key,
    required this.sesion,
    this.voluntariado,
    this.clase,
    this.themeNotifier,
    this.onCerrarSesion,
    this.rolEtiqueta = 'Tutora',
    this.rolEmoji = '👩‍🏫',
    this.seccionesExtra = const [],
  });

  @override
  State<AjustesTutoraScreen> createState() => _AjustesTutoraScreenState();
}

class _AjustesTutoraScreenState extends State<AjustesTutoraScreen> {
  bool _cargando = true;
  FichaVoluntaria? _ficha;
  List<Curso> _cursos = const [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    FichaVoluntaria? ficha;
    var cursos = const <Curso>[];
    try {
      ficha = await widget.voluntariado?.miFicha(widget.sesion.perfilId);
      cursos = await widget.clase?.instancias(tutoraId: widget.sesion.perfilId) ?? const [];
    } catch (_) {
      // Sin conexión se muestra lo que trae la sesión
    }
    if (!mounted) return;
    setState(() {
      _ficha = ficha;
      _cursos = cursos;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sesion = widget.sesion;
    return AjustesScreen(
      cargando: _cargando,
      themeNotifier: widget.themeNotifier,
      onCerrarSesion: widget.onCerrarSesion,
      perfil: AjustesPerfil(
        nombre: sesion.nombreCompleto,
        detalle: sesion.sedePrincipal?.nombre ?? sesion.correo,
        rolEtiqueta: widget.rolEtiqueta,
        rolEmoji: widget.rolEmoji,
      ),
      secciones: [_buildPerfil(), ...widget.seccionesExtra],
    );
  }

  Widget _buildPerfil() {
    final sesion = widget.sesion;
    final ficha = _ficha;
    return AjustesSeccion(
      titulo: 'Mi perfil',
      children: [
        AjustesTile(icono: Icons.alternate_email_rounded, titulo: 'Correo', subtitulo: sesion.correo),
        AjustesTile(
          icono: Icons.location_on_rounded,
          titulo: sesion.sedes.length > 1 ? 'Sedes' : 'Sede',
          subtitulo: sesion.sedes.isEmpty ? 'Sin sede asignada' : sesion.sedes.map((s) => s.nombre).join(', '),
        ),
        AjustesTile(
          icono: Icons.school_rounded,
          titulo: _cursos.length > 1 ? 'Cursos' : 'Curso',
          subtitulo: _cursos.isEmpty ? 'Aún sin cursos asignados' : _cursos.map((c) => c.nombre).toSet().join(', '),
        ),
        if (ficha != null) ...[
          AjustesTile(
            icono: Icons.verified_user_rounded,
            titulo: 'Declaración de adhesión',
            subtitulo: ficha.adhesionFirmada
                ? 'Firmada${ficha.fechaFirmaAdhesion == null ? '' : ' el ${_fecha(ficha.fechaFirmaAdhesion!)}'}'
                : 'Pendiente de firma: la registra la Directiva',
          ),
          if (ficha.institucion != null)
            AjustesTile(icono: Icons.work_rounded, titulo: 'Institución u ocupación', subtitulo: ficha.institucion!),
          AjustesTile(
            icono: Icons.event_available_rounded,
            titulo: 'En el voluntariado desde',
            subtitulo: _fecha(ficha.fechaIngreso),
          ),
        ],
      ],
    );
  }
}
