import 'package:flutter/material.dart';

import '../../repositories/clase_repository.dart';
import '../../repositories/justificativos_repository.dart';
import '../../repositories/roles_repository.dart';
import '../gestion/gestion_tutoras_views.dart' show RolesSemanalesView;
import '../gestion/justificativos_gestion.dart';
import '../tutora/accesos_clase.dart';
import '../tutora/clase_sesion_controller.dart';
import '../tutora/inicio_tutora_widgets.dart';

/// Lo de Gestión que la Directiva abre desde sus Ajustes, en todas las sedes
/// (la base se lo permite: `gestiona_sede` incluye a la Directiva). Son las
/// mismas vistas de Gestión; parten en "Todas las sedes" y se filtran dentro.

/// La bandeja de justificativos de todas las sedes, con filtro por sede (US-16, US-37)
class JustificativosTodasLasSedesView extends StatefulWidget {
  final JustificativosRepository repository;

  /// Para ingresar el aviso de una apoderada eligiendo el curso; sin ella solo se resuelven
  final ClaseRepository? clase;

  const JustificativosTodasLasSedesView({super.key, required this.repository, this.clase});

  @override
  State<JustificativosTodasLasSedesView> createState() => _JustificativosTodasLasSedesViewState();
}

class _JustificativosTodasLasSedesViewState extends State<JustificativosTodasLasSedesView> {
  late final BandejaJustificativosController _bandeja;
  ClaseSesionController? _clase;
  bool _claseCargada = false;

  @override
  void initState() {
    super.initState();
    if (widget.clase case final repo?) _clase = ClaseSesionController(repository: repo);
    _bandeja = BandejaJustificativosController(widget.repository, alCambiarAsistencia: _clase?.cargarCursoActual)
      ..cargar();
  }

  @override
  void dispose() {
    _bandeja.dispose();
    _clase?.dispose();
    super.dispose();
  }

  // Elige el curso (los de todas las sedes) y abre el mismo formulario de Gestión
  Future<void> _ingresar() async {
    final clase = _clase!;
    final messenger = ScaffoldMessenger.of(context);
    if (!_claseCargada) {
      await clase.cargar();
      _claseCargada = clase.error == null;
    }
    if (!mounted) return;
    if (clase.cursos.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(clase.error ?? 'No hay cursos para justificar.')));
      return;
    }
    if (clase.cursos.length > 1) {
      final id = await elegirCursoClase(context, clase.cursos, clase.curso?.id);
      if (id == null || !mounted) return;
      await clase.elegirCurso(id);
      if (!mounted) return;
    }
    await mostrarModalRegistrarJustificativo(context, _bandeja, clase);
  }

  @override
  Widget build(BuildContext context) {
    return BandejaJustificativosView(controller: _bandeja, onIngresar: _clase == null ? null : _ingresar);
  }
}

/// Los roles de la clase de cualquier curso: se elige el curso (con su sede) y
/// se asignan y marcan igual que Gestión (US-43, US-44)
class RolesTodasLasSedesView extends StatefulWidget {
  final ClaseRepository clase;
  final RolesRepository roles;

  /// Usuaria autenticada (la Directiva)
  final String perfilId;

  const RolesTodasLasSedesView({super.key, required this.clase, required this.roles, required this.perfilId});

  @override
  State<RolesTodasLasSedesView> createState() => _RolesTodasLasSedesViewState();
}

class _RolesTodasLasSedesViewState extends State<RolesTodasLasSedesView> {
  late final ClaseSesionController _clase;

  @override
  void initState() {
    super.initState();
    _clase = ClaseSesionController(repository: widget.clase)..cargar();
  }

  @override
  void dispose() {
    _clase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _clase,
      builder: (context, _) {
        final curso = _clase.curso;
        if (_clase.cargando && curso == null) return const Center(child: CircularProgressIndicator());
        if (_clase.error != null && curso == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AvisoErrorClase(mensaje: _clase.error!),
          );
        }
        if (curso == null) {
          return const Center(child: Text('Aún no hay cursos vigentes.'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SelectorCursoClase(cursos: _clase.cursos, cursoId: curso.id, onCambiar: _clase.elegirCurso),
            ),
            Expanded(
              // Al cambiar de curso, la vista vuelve a cargar sus clases y roles
              child: _clase.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RolesSemanalesView(
                      key: ValueKey(curso.id),
                      controller: _clase,
                      roles: widget.roles,
                      perfilId: widget.perfilId,
                      editable: true,
                    ),
            ),
          ],
        );
      },
    );
  }
}
