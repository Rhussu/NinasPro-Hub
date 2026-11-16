import 'dart:typed_data';

import 'package:ninas_pro_hub/repositories/evidencias_repository.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart' show Resultado;

/// [EvidenciasRepository] en memoria con la regla de US-19: apta solo si todas
/// las presentes autorizan o se declara la censura.
class FakeEvidenciasRepository implements EvidenciasRepository {
  /// Fotos por clase
  final fotosPorClase = <String, List<EvidenciaFoto>>{};

  /// Clases sin foto tras 48 horas
  final List<EvidenciaPendiente> listaPendientes;

  /// Clases con presentes sin autorización de imagen
  final Set<String> clasesSinAutorizacion;

  String? rechazo;
  var _secuencia = 0;

  FakeEvidenciasRepository({List<EvidenciaPendiente>? pendientes, this.clasesSinAutorizacion = const {}})
    : listaPendientes = pendientes ?? [];

  @override
  Future<List<EvidenciaFoto>> fotos(String claseId) async => List.of(fotosPorClase[claseId] ?? const []);

  @override
  Future<Resultado<EvidenciaFoto>> subir({
    required String claseId,
    required Uint8List jpeg,
    required bool apta,
    required bool rostrosCensurados,
  }) async {
    if (rechazo != null) return Resultado.error(rechazo);
    final sinAutorizacion = clasesSinAutorizacion.contains(claseId);
    if (apta && sinAutorizacion && !rostrosCensurados) {
      return const Resultado.error(
        'Para marcarla apta, confirma que las alumnas sin autorización no son reconocibles o sus rostros fueron cubiertos.',
      );
    }
    final foto = EvidenciaFoto(
      id: 'foto-${++_secuencia}',
      claseId: claseId,
      ruta: '$claseId/$_secuencia.jpg',
      tamanoBytes: jpeg.length,
      apta: apta,
      rostrosCensurados: rostrosCensurados,
      consentimientoCompleto: !sinAutorizacion,
      subidaPor: 'Daniela Valenzuela Castro',
      subidaEn: DateTime.now(),
    );
    (fotosPorClase[claseId] ??= []).add(foto);
    listaPendientes.removeWhere((p) => p.claseId == claseId);
    return Resultado.ok(foto);
  }

  @override
  Future<List<EvidenciaPendiente>> pendientes() async => List.of(listaPendientes);
}
