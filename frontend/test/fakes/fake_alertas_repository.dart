import 'package:ninas_pro_hub/repositories/alertas_repository.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart' show Resultado;

/// [AlertasRepository] en memoria con las reglas de `registrar_contacto_alerta`:
/// la observación es obligatoria y una alerta atendida no se vuelve a registrar.
class FakeAlertasRepository implements AlertasRepository {
  final List<AlertaDesercionDetalle> lista;

  /// Quién registra el contacto
  final String nombreGestion;

  /// Si es true, falla la conexión al leer
  bool sinConexion = false;

  FakeAlertasRepository({List<AlertaDesercionDetalle>? lista, this.nombreGestion = 'Camila Sepúlveda Rivas'})
    : lista = lista ?? [alertaDemo()];

  AlertaDesercionDetalle porId(String id) => lista.firstWhere((a) => a.id == id);

  @override
  Future<List<AlertaDesercionDetalle>> alertas() async {
    if (sinConexion) throw Exception('sin conexión');
    return [...lista.where((a) => !a.atendida), ...lista.where((a) => a.atendida)];
  }

  @override
  Future<Resultado<void>> registrarContacto(String id, String observacion) async {
    final i = lista.indexWhere((a) => a.id == id);
    if (i < 0) return const Resultado.error('La alerta no existe.');
    final a = lista[i];
    if (a.atendida) return const Resultado.error('Esta alerta ya tiene un contacto registrado.');
    if (observacion.trim().isEmpty) return const Resultado.error('Cuenta brevemente qué conversaste con la apoderada.');
    lista[i] = AlertaDesercionDetalle(
      id: a.id,
      inscripcionId: a.inscripcionId,
      alumnaId: a.alumnaId,
      alumnaNombre: a.alumnaNombre,
      alumnaRut: a.alumnaRut,
      cursoCodigo: a.cursoCodigo,
      cursoNombre: a.cursoNombre,
      sedeId: a.sedeId,
      sedeNombre: a.sedeNombre,
      numeroSesion: a.numeroSesion,
      claseFecha: a.claseFecha,
      inasistenciasConsecutivas: a.inasistenciasConsecutivas,
      atendida: true,
      fechaContacto: DateTime.now(),
      observacion: observacion.trim(),
      atendidaPor: nombreGestion,
      apoderadoNombre: a.apoderadoNombre,
      apoderadoTelefono: a.apoderadoTelefono,
      apoderadoCorreo: a.apoderadoCorreo,
      apoderadoParentesco: a.apoderadoParentesco,
      creadaEn: a.creadaEn,
    );
    return const Resultado.ok();
  }

  static AlertaDesercionDetalle alertaDemo({
    String id = 'alerta-1',
    String alumnaNombre = 'Florencia Muñoz Tapia',
    String sedeId = 'sede-beauchef',
    String sedeNombre = 'Sede Beauchef',
    int inasistencias = 3,
    bool atendida = false,
    String? observacion,
  }) => AlertaDesercionDetalle(
    id: id,
    inscripcionId: 'insc-$id',
    alumnaId: 'alumna-$id',
    alumnaNombre: alumnaNombre,
    alumnaRut: '21.904.331-7',
    cursoCodigo: 'PCB',
    cursoNombre: 'Programación Competitiva Básica (Python)',
    sedeId: sedeId,
    sedeNombre: sedeNombre,
    numeroSesion: 3,
    claseFecha: DateTime(2026, 11, 14),
    inasistenciasConsecutivas: inasistencias,
    atendida: atendida,
    fechaContacto: atendida ? DateTime(2026, 11, 15) : null,
    observacion: observacion,
    atendidaPor: atendida ? 'Valeria Troncoso Morales' : null,
    apoderadoNombre: 'Claudio Muñoz Pavez',
    apoderadoTelefono: '+56 9 7654 3210',
    apoderadoCorreo: 'claudio.munoz@correo.cl',
    apoderadoParentesco: 'Padre',
    creadaEn: DateTime(2026, 11, 14, 13),
  );
}
