import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'justificativos_repository.dart' show Resultado, fechaCorta;

/// Foto de evidencia registrada en una clase (US-18, US-19)
@immutable
class EvidenciaFoto {
  final String id;
  final String claseId;

  /// Ruta en el bucket privado evidencias
  final String ruta;
  final int? tamanoBytes;

  /// Apta para difundir: todas las presentes con autorización o con la censura declarada
  final bool apta;
  final bool rostrosCensurados;

  /// Todas las presentes tenían autorización de imagen al subirla
  final bool consentimientoCompleto;
  final String? subidaPor;
  final DateTime subidaEn;

  /// URL firmada de corta duración para mostrarla
  final String? url;

  const EvidenciaFoto({
    required this.id,
    required this.claseId,
    required this.ruta,
    this.tamanoBytes,
    required this.apta,
    required this.rostrosCensurados,
    required this.consentimientoCompleto,
    this.subidaPor,
    required this.subidaEn,
    this.url,
  });

  /// 812 KB
  String get pesoEtiqueta => tamanoBytes == null ? '' : pesoLegible(tamanoBytes!);
}

/// 812 KB, 1,4 MB
String pesoLegible(int bytes) => bytes >= 1000000
    ? '${(bytes / 1000000).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(bytes / 1000).round()} KB';

/// Clase realizada hace más de 48 horas sin foto de evidencia (US-20)
@immutable
class EvidenciaPendiente {
  final String claseId;
  final String cursoNombre;
  final String sedeNombre;
  final int seccion;
  final int numeroSesion;
  final DateTime fecha;
  final String? tema;
  final int horasSinFoto;

  /// Tutoras asignadas al curso, para recordarles la foto
  final String? tutoras;

  const EvidenciaPendiente({
    required this.claseId,
    required this.cursoNombre,
    required this.sedeNombre,
    this.seccion = 1,
    required this.numeroSesion,
    required this.fecha,
    this.tema,
    required this.horasSinFoto,
    this.tutoras,
  });

  String get claseEtiqueta => 'Clase #$numeroSesion · ${fechaCorta(fecha)}';

  /// Hace 3 días
  String get demora {
    final dias = horasSinFoto ~/ 24;
    return dias >= 2 ? 'Hace $dias días' : 'Hace $horasSinFoto horas';
  }
}

/// Evidencia fotográfica de las clases (US-18..US-20).
///
/// La foto se comprime en el celular antes de llamar a [subir]. La base
/// valida que la clase tenga pase de lista y que solo se marque apta con
/// todas las autorizaciones o con la declaración de censura (US-19).
abstract class EvidenciasRepository {
  /// Fotos de la clase, con su URL firmada
  Future<List<EvidenciaFoto>> fotos(String claseId);

  /// Sube la foto ya comprimida (JPEG) y la vincula a la clase
  Future<Resultado<EvidenciaFoto>> subir({
    required String claseId,
    required Uint8List jpeg,
    required bool apta,
    required bool rostrosCensurados,
  });

  /// Clases de las sedes de la usuaria realizadas hace más de 48 horas sin foto
  Future<List<EvidenciaPendiente>> pendientes();
}

class MapeoEvidencias {
  static const columnas =
      'id, clase_id, archivo_url, tamano_bytes, apta_para_evidencia, rostros_censurados, '
      'declaracion_consentimiento_completo, subida_en, perfiles(nombres, apellidos)';

  static EvidenciaFoto foto(Map<String, dynamic> f, {String? url}) {
    final autora = f['perfiles'] as Map<String, dynamic>?;
    final nombre = autora == null ? '' : '${autora['nombres'] ?? ''} ${autora['apellidos'] ?? ''}'.trim();
    return EvidenciaFoto(
      id: f['id'] as String,
      claseId: f['clase_id'] as String,
      ruta: f['archivo_url'] as String,
      tamanoBytes: (f['tamano_bytes'] as num?)?.toInt(),
      apta: f['apta_para_evidencia'] == true,
      rostrosCensurados: f['rostros_censurados'] == true,
      consentimientoCompleto: f['declaracion_consentimiento_completo'] == true,
      subidaPor: nombre.isEmpty ? null : nombre,
      subidaEn: DateTime.parse(f['subida_en'] as String).toLocal(),
      url: url,
    );
  }

  static EvidenciaPendiente pendiente(Map<String, dynamic> f) => EvidenciaPendiente(
    claseId: f['clase_id'] as String,
    cursoNombre: f['curso_nombre'] as String? ?? '',
    sedeNombre: f['sede_nombre'] as String? ?? '',
    seccion: (f['seccion'] as num?)?.toInt() ?? 1,
    numeroSesion: (f['numero_sesion'] as num).toInt(),
    fecha: DateTime.parse(f['fecha'] as String),
    tema: f['clase_tema'] as String?,
    horasSinFoto: (f['horas_sin_foto'] as num?)?.toInt() ?? 0,
    tutoras: f['tutoras'] as String?,
  );
}

class SupabaseEvidenciasRepository implements EvidenciasRepository {
  static const _bucket = 'evidencias';

  /// Las URLs firmadas de las fotos duran 10 minutos
  static const _duracionUrl = 600;

  final SupabaseClient _client;
  final DateTime Function() _ahora;

  SupabaseEvidenciasRepository(this._client, {DateTime Function()? ahora}) : _ahora = ahora ?? DateTime.now;

  @override
  Future<List<EvidenciaFoto>> fotos(String claseId) async {
    final filas = await _client
        .from('evidencias_fotograficas')
        .select(MapeoEvidencias.columnas)
        .eq('clase_id', claseId)
        .order('subida_en', ascending: true);
    if (filas.isEmpty) return const [];
    final urls = <String, String>{};
    try {
      final firmadas = await _client.storage.from(_bucket).createSignedUrlsResult([
        for (final f in filas) f['archivo_url'] as String,
      ], _duracionUrl);
      for (final u in firmadas.whereType<SignedUrlSuccess>()) {
        urls[u.path] = u.signedUrl;
      }
    } on StorageException {
      // Sin URL se muestra la ficha de la foto sin la imagen
    }
    return [for (final f in filas) MapeoEvidencias.foto(f, url: urls[f['archivo_url']])];
  }

  @override
  Future<Resultado<EvidenciaFoto>> subir({
    required String claseId,
    required Uint8List jpeg,
    required bool apta,
    required bool rostrosCensurados,
  }) async {
    final ruta = '$claseId/${_ahora().millisecondsSinceEpoch}.jpg';
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(ruta, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    } on StorageException catch (e) {
      return Resultado.error(
        e.statusCode == '403'
            ? 'No tienes permiso para subir fotos a esta clase.'
            : e.statusCode == '413'
            ? 'La foto pesa demasiado para subirla.'
            : 'No pudimos subir la foto. Revisa tu conexión e inténtalo nuevamente.',
      );
    }
    try {
      final fila = await _client
          .from('evidencias_fotograficas')
          .insert({
            'clase_id': claseId,
            'archivo_url': ruta,
            'apta_para_evidencia': apta,
            'rostros_censurados': rostrosCensurados,
          })
          .select(MapeoEvidencias.columnas)
          .single();
      return Resultado.ok(MapeoEvidencias.foto(fila));
    } on PostgrestException catch (e) {
      // La foto no quedó registrada: se borra para no dejarla huérfana
      await _client.storage.from(_bucket).remove([ruta]).catchError((_) => <FileObject>[]);
      return Resultado.error(switch (e.code) {
        '22023' || 'P0001' => e.message,
        '42501' => 'No tienes permiso para subir fotos a esta clase.',
        _ => 'No pudimos registrar la foto. Inténtalo nuevamente.',
      });
    }
  }

  @override
  Future<List<EvidenciaPendiente>> pendientes() async {
    final filas = await _client.from('evidencias_pendientes').select().order('fecha', ascending: true).order('curso_nombre', ascending: true);
    return [for (final f in filas) MapeoEvidencias.pendiente(f)];
  }
}
