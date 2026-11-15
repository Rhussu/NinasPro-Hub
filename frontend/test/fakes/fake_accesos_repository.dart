import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/accesos_repository.dart';

/// [AccesosRepository] en memoria que registra las solicitudes recibidas.
class FakeAccesosRepository implements AccesosRepository {
  final List<AutorizacionCorreo> lista;
  final List<SedeOpcion> sedesDisponibles;
  final List<AlumnaSinCuenta> alumnas;

  /// Si no es null, autorizar responde con este error (ej. el 403 de la base)
  String? errorAutorizar;

  final solicitudes = <SolicitudAutorizacion>[];
  final revocadas = <String>[];

  FakeAccesosRepository({
    List<AutorizacionCorreo>? lista,
    this.sedesDisponibles = const [
      SedeOpcion(id: 'sede-a', nombre: 'Sede Beauchef'),
      SedeOpcion(id: 'sede-b', nombre: 'Sede Valparaíso'),
    ],
    this.alumnas = const [
      AlumnaSinCuenta(
        id: 'alumna-1',
        rut: '21.904.331-7',
        nombres: 'Florencia',
        apellidos: 'Muñoz Tapia',
        correo: 'florencia@correo.cl',
        sedeId: 'sede-a',
        sedeNombre: 'Sede Beauchef',
      ),
    ],
  }) : lista = lista ?? [];

  @override
  Future<List<AutorizacionCorreo>> autorizaciones() async => List.of(lista);

  @override
  Future<List<SedeOpcion>> sedes() async => sedesDisponibles;

  @override
  Future<List<AlumnaSinCuenta>> alumnasSinCuenta() async => alumnas;

  @override
  Future<ResultadoAcceso> autorizar(SolicitudAutorizacion s) async {
    solicitudes.add(s);
    final error = errorAutorizar;
    if (error != null) return ResultadoAcceso.error(error);
    final nueva = AutorizacionCorreo(
      id: 'aut-${lista.length + 1}',
      correo: s.correo,
      rol: s.rol,
      nombre: s.rol == RolUsuario.alumna
          ? alumnas.firstWhere((a) => a.id == s.alumnaId).nombreCompleto
          : '${s.nombres} ${s.apellidos}',
      sedeId: s.sedeId,
      esLiderSede: s.esLiderSede,
      expiraEn: DateTime(2026, 12, 15),
    );
    lista.insert(0, nueva);
    return ResultadoAcceso.ok(nueva);
  }

  @override
  Future<ResultadoAcceso> revocar(String id) async {
    revocadas.add(id);
    lista.removeWhere((a) => a.id == id);
    return const ResultadoAcceso.ok();
  }
}
