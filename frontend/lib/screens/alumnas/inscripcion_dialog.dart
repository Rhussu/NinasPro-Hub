import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/alumnas_repository.dart';
import '../../utils/rut.dart';
import '../../utils/rut_input_formatter.dart';
import '../directorio/directorio_widgets.dart';

/// Inscripción individual fuera de la carga masiva (US-09 escenario 2).
/// Si el RUT ya tiene ficha, la base la reutiliza y solo agrega la inscripción.
/// Si esa ficha tiene otros datos o el correo ya está en uso, avisa el
/// conflicto y deja elegir qué hacer antes de inscribir. Devuelve true si se inscribió.
Future<bool?> mostrarInscripcionAlumna(
  BuildContext context, {
  required AlumnasRepository repository,
  required List<Curso> instancias,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _DialogoInscripcion(repository: repository, instancias: instancias),
);

class _DialogoInscripcion extends StatefulWidget {
  final AlumnasRepository repository;
  final List<Curso> instancias;

  const _DialogoInscripcion({required this.repository, required this.instancias});

  @override
  State<_DialogoInscripcion> createState() => _DialogoInscripcionState();
}

class _DialogoInscripcionState extends State<_DialogoInscripcion> {
  final _formKey = GlobalKey<FormState>();
  final _rut = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _establecimiento = TextEditingController();
  final _cursoEscolar = TextEditingController();
  final _rutApoderado = TextEditingController();
  final _nombresApoderado = TextEditingController();
  final _apellidosApoderado = TextEditingController();
  final _telefono = TextEditingController();
  final _correoApoderado = TextEditingController();
  final _parentesco = TextEditingController();
  late String _instanciaId = widget.instancias.first.id;
  DateTime? _fechaNacimiento;
  bool _guardando = false;
  String? _error;

  /// Conflicto que la base informó en el último intento
  FilaNomina? _conflicto;

  List<TextEditingController> get _controladores => [
    _rut,
    _nombres,
    _apellidos,
    _correo,
    _establecimiento,
    _cursoEscolar,
    _rutApoderado,
    _nombresApoderado,
    _apellidosApoderado,
    _telefono,
    _correoApoderado,
    _parentesco,
  ];

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _rutObligatorio(String? v) =>
      obligatorio(v) ?? (validarRut(v!) ? null : 'RUT inválido (revisa el dígito verificador)');

  static String? _rutOpcional(String? v) =>
      v == null || v.trim().isEmpty || validarRut(v) ? null : 'RUT inválido (revisa el dígito verificador)';

  static final _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? _correoObligatorio(String? v) =>
      obligatorio(v) ?? (_formatoCorreo.hasMatch(v!.trim()) ? null : 'Correo inválido');

  static String? _correoOpcional(String? v) =>
      v == null || v.trim().isEmpty || _formatoCorreo.hasMatch(v.trim()) ? null : 'Correo inválido';

  Future<void> _elegirFechaNacimiento() async {
    final hoy = DateTime.now();
    final fecha = await elegirFecha(
      context,
      inicial: _fechaNacimiento ?? DateTime(hoy.year - 14, 1, 1),
      primera: DateTime(hoy.year - 30),
      ultima: hoy,
    );
    if (fecha != null) setState(() => _fechaNacimiento = fecha);
  }

  Future<void> _guardar([ResolucionFila? resolucion]) async {
    final formOk = _formKey.currentState!.validate();
    if (_fechaNacimiento == null) setState(() => _error = 'Indica la fecha de nacimiento.');
    if (!formOk || _fechaNacimiento == null) return;
    setState(() {
      _guardando = true;
      _error = null;
      _conflicto = null;
    });
    final r = await widget.repository.inscribir(
      resolucion: resolucion,
      instanciaId: _instanciaId,
      datos: DatosAlumna(
        rut: _rut.text,
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        fechaNacimiento: _fechaNacimiento!,
        correo: _correo.text,
        establecimiento: _establecimiento.text,
        cursoEscolar: _cursoEscolar.text,
        rutApoderado: _rutApoderado.text,
        nombresApoderado: _nombresApoderado.text,
        apellidosApoderado: _apellidosApoderado.text,
        telefonoApoderado: _telefono.text,
        correoApoderado: _correoApoderado.text,
        parentesco: _parentesco.text,
      ),
    );
    if (!mounted) return;
    final fila = r.valor;
    if (fila != null && fila.estado.seInscribe) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _guardando = false;
      if (fila != null && fila.estado == EstadoFilaNomina.conflicto && !fila.conflictos.contains(TipoConflicto.rutRepetido)) {
        _conflicto = fila;
      } else {
        _error = r.error ?? fila?.motivo;
      }
    });
  }

  /// Diferencias con la ficha existente o correo en uso, con las opciones para seguir
  Widget _buildConflicto(FilaNomina f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.warning900 : NinasProColors.warning100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.motivo ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final d in f.diferencias)
            Text('${d.campo}: «${d.ficha}» en la ficha, «${d.planilla}» en el formulario'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (f.conflictos.contains(TipoConflicto.fichaDistinta)) ...[
                OutlinedButton(
                  onPressed: () => _guardar(ResolucionFila.mantenerFicha),
                  child: const Text('Mantener la ficha e inscribir'),
                ),
                OutlinedButton(
                  onPressed: () => _guardar(ResolucionFila.actualizarFicha),
                  child: const Text('Actualizar la ficha e inscribir'),
                ),
              ],
              if (f.conflictos.contains(TipoConflicto.correoEnUso))
                OutlinedButton(
                  onPressed: () => _guardar(ResolucionFila.sinCorreo),
                  child: const Text('Inscribir sin correo'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seccion(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inscribir alumna'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _instanciaId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Curso', border: OutlineInputBorder()),
                    items: [
                      for (final c in widget.instancias)
                        DropdownMenuItem(value: c.id, child: Text('${c.codigo} · ${c.sedeNombre}')),
                    ],
                    onChanged: (v) => setState(() => _instanciaId = v ?? _instanciaId),
                  ),
                ),
                _seccion('Alumna'),
                CampoFormulario(
                  controller: _rut,
                  formateadores: const [RutInputFormatter()],
                  etiqueta: 'RUT',
                  ayuda: 'Si el RUT ya tiene ficha, se reutiliza y se agrega esta inscripción',
                  validator: _rutObligatorio,
                ),
                CampoFormulario(controller: _nombres, etiqueta: 'Nombres', validator: obligatorio),
                CampoFormulario(controller: _apellidos, etiqueta: 'Apellidos', validator: obligatorio),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    onPressed: _elegirFechaNacimiento,
                    icon: const Icon(Icons.cake_rounded, size: 18),
                    label: Text(
                      _fechaNacimiento == null
                          ? 'Fecha de nacimiento'
                          : 'Nació el ${formatearFecha(_fechaNacimiento)}',
                    ),
                  ),
                ),
                CampoFormulario(
                  controller: _correo,
                  etiqueta: 'Correo de la alumna (opcional)',
                  ayuda: 'Con su correo queda autorizada para crear su cuenta del portal',
                  teclado: TextInputType.emailAddress,
                  validator: _correoOpcional,
                ),
                CampoFormulario(controller: _establecimiento, etiqueta: 'Establecimiento educacional (opcional)'),
                CampoFormulario(controller: _cursoEscolar, etiqueta: 'Curso escolar (opcional)'),
                _seccion('Apoderado/a'),
                CampoFormulario(
                  controller: _rutApoderado,
                  formateadores: const [RutInputFormatter()],
                  etiqueta: 'RUT del apoderado/a (opcional)',
                  validator: _rutOpcional,
                ),
                CampoFormulario(controller: _nombresApoderado, etiqueta: 'Nombres', validator: obligatorio),
                CampoFormulario(controller: _apellidosApoderado, etiqueta: 'Apellidos', validator: obligatorio),
                CampoFormulario(
                  controller: _telefono,
                  etiqueta: 'Teléfono',
                  teclado: TextInputType.phone,
                  validator: obligatorio,
                ),
                CampoFormulario(
                  controller: _correoApoderado,
                  etiqueta: 'Correo',
                  teclado: TextInputType.emailAddress,
                  validator: _correoObligatorio,
                ),
                CampoFormulario(controller: _parentesco, etiqueta: 'Parentesco (opcional)'),
                if (_conflicto != null) _buildConflicto(_conflicto!),
                if (_error != null) Text(_error!, style: const TextStyle(color: NinasProColors.error700)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : () => _guardar(), child: const Text('Inscribir')),
      ],
    );
  }
}
