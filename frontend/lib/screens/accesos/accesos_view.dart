import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/accesos_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/rut.dart';
import '../directorio/directorio_widgets.dart';

/// Vista "Accesos" (US-04): correos habilitados para crear su cuenta.
///
/// La Directiva autoriza cualquier rol en cualquier sede; el Equipo de Gestión,
/// solo alumnas inscritas en su sede. Quien recibe la autorización crea su
/// cuenta desde "Primera vez: crear mi cuenta" con ese mismo correo.
class AccesosView extends StatefulWidget {
  final AccesosRepository repository;
  final SesionUsuario sesion;

  const AccesosView({super.key, required this.repository, required this.sesion});

  @override
  State<AccesosView> createState() => _AccesosViewState();
}

class _AccesosViewState extends State<AccesosView> {
  bool _cargando = true;
  String? _error;
  List<AutorizacionCorreo> _autorizaciones = const [];

  bool get _esDirectiva => widget.sesion.rol == RolUsuario.directorio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await widget.repository.autorizaciones();
      if (!mounted) return;
      setState(() {
        _autorizaciones = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los accesos. Revisa tu conexión e inténtalo nuevamente.';
        _cargando = false;
      });
    }
  }

  Future<void> _autorizar() async {
    final nueva = await showDialog<AutorizacionCorreo>(
      context: context,
      builder: (_) => DialogoAutorizarCorreo(repository: widget.repository, esDirectiva: _esDirectiva),
    );
    if (nueva == null || !mounted) return;
    mostrarAviso(
      context,
      '✅ ${nueva.correo} ya puede crear su cuenta en "Primera vez: crear mi cuenta". '
      'La autorización vence el ${formatearFecha(nueva.expiraEn)}.',
    );
    _cargar();
  }

  Future<void> _revocar(AutorizacionCorreo a) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: Text('${a.correo} ya no podrá crear su cuenta con esta autorización.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revocar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final r = await widget.repository.revocar(a.id);
    if (!mounted) return;
    mostrarAviso(context, r.ok ? 'Se revocó el acceso de ${a.correo}.' : r.error!, error: !r.ok);
    if (r.ok) _cargar();
  }

  /// La Directiva revoca cualquiera; Gestión solo las de alumnas
  bool _puedeRevocar(AutorizacionCorreo a) =>
      a.estado() != EstadoAutorizacion.usada && (_esDirectiva || a.rol == RolUsuario.alumna);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DirectorioEncabezado(
            titulo: 'Accesos',
            subtitulo: _esDirectiva
                ? 'Correos habilitados para crear su cuenta en NiñasPro Hub'
                : 'Correos de alumnas de tu sede habilitados para crear su cuenta',
            acciones: [
              FilledButton.icon(
                onPressed: _cargando ? null : _autorizar,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Autorizar correo'),
              ),
            ],
          ),
          if (_cargando)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _Mensaje(
              texto: _error!,
              accion: OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            )
          else if (_autorizaciones.isEmpty)
            const _Mensaje(texto: 'Aún no hay correos autorizados.')
          else
            for (final a in _autorizaciones)
              _TarjetaAutorizacion(
                autorizacion: a,
                onRevocar: _puedeRevocar(a) ? () => _revocar(a) : null,
              ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final Widget? accion;

  const _Mensaje({required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(texto, textAlign: TextAlign.center),
          if (accion != null) ...[const SizedBox(height: 12), accion!],
        ],
      ),
    );
  }
}

class _TarjetaAutorizacion extends StatelessWidget {
  final AutorizacionCorreo autorizacion;
  final VoidCallback? onRevocar;

  const _TarjetaAutorizacion({required this.autorizacion, this.onRevocar});

  @override
  Widget build(BuildContext context) {
    final a = autorizacion;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (etiqueta, tono) = switch (a.estado()) {
      EstadoAutorizacion.pendiente => ('Pendiente', TonoChip.info),
      EstadoAutorizacion.usada => ('Cuenta creada', TonoChip.exito),
      EstadoAutorizacion.vencida => ('Vencida', TonoChip.advertencia),
    };
    final rol = a.esLiderSede ? 'Líder de sede' : a.rol.etiqueta;
    final detalle = [
      '${a.rol.emoji} $rol',
      if (a.sedeNombre != null) a.sedeNombre!,
      if (a.estado() == EstadoAutorizacion.pendiente) 'Vence el ${formatearFecha(a.expiraEn)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nombre.isEmpty ? a.correo : a.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (a.nombre.isNotEmpty) Text(a.correo, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                ],
              ),
            ),
            DirectorioChip(etiqueta, tono: tono),
            if (onRevocar != null)
              IconButton(
                tooltip: 'Revocar acceso de ${a.correo}',
                icon: const Icon(Icons.block_rounded, size: 20),
                onPressed: onRevocar,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Formulario para autorizar un correo. Devuelve la autorización creada.
class DialogoAutorizarCorreo extends StatefulWidget {
  final AccesosRepository repository;

  /// La Directiva elige el rol; Gestión solo autoriza alumnas
  final bool esDirectiva;

  const DialogoAutorizarCorreo({super.key, required this.repository, required this.esDirectiva});

  @override
  State<DialogoAutorizarCorreo> createState() => _DialogoAutorizarCorreoState();
}

class _DialogoAutorizarCorreoState extends State<DialogoAutorizarCorreo> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _rut = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();

  late RolUsuario _rol = widget.esDirectiva ? RolUsuario.tutora : RolUsuario.alumna;
  String? _sedeId;
  AlumnaSinCuenta? _alumna;
  bool _esLider = false;

  List<SedeOpcion> _sedes = const [];
  List<AlumnaSinCuenta>? _alumnas;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  bool get _esAlumna => _rol == RolUsuario.alumna;

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  @override
  void dispose() {
    for (final c in [_correo, _rut, _nombres, _apellidos]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    try {
      final sedes = widget.esDirectiva ? await widget.repository.sedes() : const <SedeOpcion>[];
      final alumnas = await widget.repository.alumnasSinCuenta();
      if (!mounted) return;
      setState(() {
        _sedes = sedes;
        _alumnas = alumnas;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las sedes y alumnas. Inténtalo nuevamente.';
        _cargando = false;
      });
    }
  }

  void _elegirAlumna(AlumnaSinCuenta? a) {
    setState(() {
      _alumna = a;
      // Se propone el correo de la ficha, si lo tiene
      if (a?.correo != null && _correo.text.trim().isEmpty) _correo.text = a!.correo!;
    });
  }

  Future<void> _guardar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final alumna = _alumna;
    final r = await widget.repository.autorizar(SolicitudAutorizacion(
      correo: _correo.text.trim().toLowerCase(),
      rol: _rol,
      sedeId: _esAlumna ? alumna?.sedeId : (_rol == RolUsuario.directorio ? null : _sedeId),
      alumnaId: _esAlumna ? alumna?.id : null,
      rut: _esAlumna ? null : formatearRut(_rut.text),
      nombres: _esAlumna ? null : _nombres.text.trim(),
      apellidos: _esAlumna ? null : _apellidos.text.trim(),
      esLiderSede: _rol == RolUsuario.equipoGestion && _esLider,
    ));
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, r.autorizacion);
    } else {
      setState(() {
        _enviando = false;
        _error = r.error;
      });
    }
  }

  String? _validarCorreo(String? v) {
    final error = validarCorreo(v ?? '');
    if (error != null) return error;
    if (!_esAlumna && !(v ?? '').trim().toLowerCase().endsWith('@ninaspro.cl')) {
      return 'El voluntariado usa su correo institucional @ninaspro.cl.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Autorizar correo'),
      content: SizedBox(
        width: 480,
        child: _cargando
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.esDirectiva)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DropdownButtonFormField<RolUsuario>(
                            initialValue: _rol,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                            items: [
                              for (final r in RolUsuario.values)
                                DropdownMenuItem(value: r, child: Text('${r.emoji} ${r.etiqueta}')),
                            ],
                            onChanged: (r) => setState(() {
                              _rol = r ?? _rol;
                              _esLider = false;
                            }),
                          ),
                        ),
                      if (_esAlumna) ..._camposAlumna() else ..._camposVoluntariado(),
                      CampoFormulario(
                        controller: _correo,
                        etiqueta: 'Correo',
                        ayuda: _esAlumna ? 'Correo personal de la alumna' : 'Correo institucional @ninaspro.cl',
                        teclado: TextInputType.emailAddress,
                        validator: _validarCorreo,
                      ),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: NinasProColors.error700, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _enviando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _cargando || _enviando ? null : _guardar,
          child: _enviando
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Autorizar'),
        ),
      ],
    );
  }

  List<Widget> _camposAlumna() {
    final alumnas = _alumnas ?? const [];
    if (alumnas.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('No hay alumnas inscritas sin cuenta. Inscríbelas en un curso para poder autorizarlas.'),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<AlumnaSinCuenta>(
          initialValue: _alumna,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Alumna', border: OutlineInputBorder()),
          items: [
            for (final a in alumnas)
              DropdownMenuItem(value: a, child: Text('${a.nombreCompleto} · ${a.sedeNombre}', overflow: TextOverflow.ellipsis)),
          ],
          validator: (a) => a == null ? 'Elige a la alumna' : null,
          onChanged: _elegirAlumna,
        ),
      ),
    ];
  }

  List<Widget> _camposVoluntariado() {
    return [
      CampoFormulario(controller: _nombres, etiqueta: 'Nombres', validator: obligatorio),
      CampoFormulario(controller: _apellidos, etiqueta: 'Apellidos', validator: obligatorio),
      CampoFormulario(
        controller: _rut,
        etiqueta: 'RUT',
        ayuda: 'Ej. 12.345.678-5',
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'Este campo es obligatorio'
            : (validarRut(v) ? null : 'El RUT no es válido'),
      ),
      if (_rol != RolUsuario.directorio)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            initialValue: _sedeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sede', border: OutlineInputBorder()),
            items: [for (final s in _sedes) DropdownMenuItem(value: s.id, child: Text(s.nombre))],
            validator: (s) => s == null ? 'Elige la sede' : null,
            onChanged: (s) => setState(() => _sedeId = s),
          ),
        ),
      if (_rol == RolUsuario.equipoGestion)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Líder de sede'),
          value: _esLider,
          onChanged: (v) => setState(() => _esLider = v),
        ),
    ];
  }
}

/// Pantalla completa de "Accesos" para la vista móvil del Equipo de Gestión.
class AccesosScreen extends StatelessWidget {
  final AccesosRepository repository;
  final SesionUsuario sesion;

  const AccesosScreen({super.key, required this.repository, required this.sesion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accesos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AccesosView(repository: repository, sesion: sesion),
        ),
      ),
    );
  }
}
