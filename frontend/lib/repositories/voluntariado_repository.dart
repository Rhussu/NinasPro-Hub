import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'justificativos_repository.dart' show Resultado;

/// Rol de una persona del voluntariado (todas las de Gestión también son tutoras)
enum RolVoluntaria {
  tutora('tutora', 'Tutora'),
  equipoGestion('equipo_gestion', 'Equipo de Gestión');

  final String db;
  final String etiqueta;

  const RolVoluntaria(this.db, this.etiqueta);

  static RolVoluntaria desdeDb(Object? v) => v == 'equipo_gestion' ? equipoGestion : tutora;
}

/// Situación de la cuenta de una ficha
enum CuentaVoluntaria {
  /// Ya creó su cuenta y puede entrar
  activa('activa', 'Con cuenta'),

  /// Tiene cuenta, pero sin acceso (salió del voluntariado)
  inactiva('inactiva', 'Cuenta desactivada'),

  /// Su correo está autorizado y aún no crea la cuenta
  autorizada('autorizada', 'Correo autorizado'),

  /// Sin cuenta y con la autorización vencida (o retirada)
  sinAutorizacion('sin_autorizacion', 'Autorización vencida');

  final String db;
  final String etiqueta;

  const CuentaVoluntaria(this.db, this.etiqueta);

  static CuentaVoluntaria desdeDb(Object? v) =>
      values.where((c) => c.db == v).firstOrNull ?? CuentaVoluntaria.sinAutorizacion;
}

/// Curso (instancia) en que participó una voluntaria: su trayectoria (US-32)
@immutable
class CursoTrayectoria {
  final String instanciaId;
  final String cursoCodigo;
  final String cursoNombre;
  final String sedeId;
  final String sedeNombre;
  final String periodo;
  final int seccion;

  const CursoTrayectoria({
    required this.instanciaId,
    required this.cursoCodigo,
    required this.cursoNombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.periodo,
    this.seccion = 1,
  });

  /// PCB · Sede Beauchef · 2026-1 (Sección B)
  String get etiqueta =>
      '$cursoCodigo · $sedeNombre · $periodo${seccion > 1 ? ' (Sección ${String.fromCharCode(64 + seccion)})' : ''}';
}

/// Ficha del voluntariado, con o sin cuenta (US-30..US-32)
@immutable
class FichaVoluntaria {
  final String id;
  final String? perfilId;
  final String rut;
  final String nombres;
  final String apellidos;
  final String correo;
  final String? telefono;
  final String? institucion;
  final RolVoluntaria rol;
  final String? sedeId;
  final String sedeNombre;
  final DateTime fechaIngreso;
  final DateTime? fechaSalida;
  final bool adhesionFirmada;
  final DateTime? fechaFirmaAdhesion;
  final CuentaVoluntaria cuenta;
  final DateTime? autorizacionExpiraEn;
  final List<CursoTrayectoria> cursos;

  /// Su sede, las de su cuenta y las de sus cursos (filtro por sede, US-32 escenario 1)
  final Set<String> sedeIds;

  const FichaVoluntaria({
    required this.id,
    this.perfilId,
    required this.rut,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.telefono,
    this.institucion,
    this.rol = RolVoluntaria.tutora,
    this.sedeId,
    this.sedeNombre = '',
    required this.fechaIngreso,
    this.fechaSalida,
    this.adhesionFirmada = false,
    this.fechaFirmaAdhesion,
    this.cuenta = CuentaVoluntaria.autorizada,
    this.autorizacionExpiraEn,
    this.cursos = const [],
    this.sedeIds = const {},
  });

  String get nombre => '$nombres $apellidos'.trim();
  bool get retirada => fechaSalida != null;

  /// Puede asignarse a un curso: activa, con la adhesión firmada y con cuenta (US-31)
  bool get apta => !retirada && adhesionFirmada;
}

/// Fila revisada de una carga de voluntariado (US-30 escenario 1)
@immutable
class FilaVoluntariado {
  final int fila;
  final String rut;
  final String nombre;
  final String correo;

  /// 'nueva', 'existente' o 'invalida'
  final String estado;
  final String? motivo;
  final String? fichaId;

  const FilaVoluntariado({
    required this.fila,
    required this.rut,
    required this.nombre,
    required this.correo,
    required this.estado,
    this.motivo,
    this.fichaId,
  });

  bool get invalida => estado == 'invalida';
}

@immutable
class RevisionVoluntariado {
  final List<FilaVoluntariado> filas;
  final int creadas;
  final int actualizadas;
  final int rechazadas;

  const RevisionVoluntariado({required this.filas, this.creadas = 0, this.actualizadas = 0, this.rechazadas = 0});

  Iterable<FilaVoluntariado> get rechazadasFilas => filas.where((f) => f.invalida);
}

/// Datos de una voluntaria para el alta individual (US-30 escenario 3)
@immutable
class DatosVoluntaria {
  final String rut;
  final String nombres;
  final String apellidos;
  final String correo;
  final String telefono;
  final String institucion;
  final RolVoluntaria rol;
  final DateTime? fechaIngreso;

  const DatosVoluntaria({
    required this.rut,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.telefono = '',
    this.institucion = '',
    this.rol = RolVoluntaria.tutora,
    this.fechaIngreso,
  });
}

/// Voluntariado: fichas, carga masiva, adhesión, rol, salida y asignación a cursos.
///
/// Todo lo administra la Directiva; la base rechaza a cualquier otro rol.
abstract class VoluntariadoRepository {
  Future<List<FichaVoluntaria>> fichas();

  /// La ficha de la usuaria autenticada (Ajustes de la tutora); null si no tiene
  Future<FichaVoluntaria?> miFicha(String perfilId);

  /// Vista previa de una planilla: no escribe nada
  Future<Resultado<RevisionVoluntariado>> revisarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  });

  /// Carga las filas válidas y devuelve las rechazadas con su motivo
  Future<Resultado<RevisionVoluntariado>> confirmarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  });

  /// Alta individual: crea la ficha y autoriza su correo
  Future<Resultado<FilaVoluntariado>> alta({required String sedeId, required DatosVoluntaria datos});

  Future<Resultado<void>> registrarAdhesion(String id, {required bool firmada, DateTime? fecha});
  Future<Resultado<void>> cambiarRol(String id, RolVoluntaria rol);
  Future<Resultado<void>> registrarSalida(String id, DateTime fecha);
  Future<Resultado<void>> reincorporar(String id);

  /// Vuelve a autorizar por 30 días el correo de una ficha sin cuenta
  Future<Resultado<DateTime>> renovarAutorizacion(String id);

  Future<Resultado<void>> asignarCurso(String id, String instanciaId);
  Future<Resultado<void>> quitarCurso(String id, String instanciaId);
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MapeoVoluntariado {
  static DateTime? _fecha(Object? v) => v is String ? DateTime.parse(v) : null;

  /// Filas de la vista `voluntariado`
  static FichaVoluntaria ficha(Map<String, dynamic> f) => FichaVoluntaria(
    id: f['id'] as String,
    perfilId: f['perfil_id'] as String?,
    rut: f['rut'] as String? ?? '',
    nombres: f['nombres'] as String? ?? '',
    apellidos: f['apellidos'] as String? ?? '',
    correo: f['correo'] as String? ?? '',
    telefono: f['telefono'] as String?,
    institucion: f['institucion'] as String?,
    rol: RolVoluntaria.desdeDb(f['rol']),
    sedeId: f['sede_id'] as String?,
    sedeNombre: f['sede_nombre'] as String? ?? '',
    fechaIngreso: _fecha(f['fecha_ingreso']) ?? DateTime(2000),
    fechaSalida: _fecha(f['fecha_salida']),
    adhesionFirmada: f['adhesion_firmada'] == true,
    fechaFirmaAdhesion: _fecha(f['fecha_firma_adhesion']),
    cuenta: CuentaVoluntaria.desdeDb(f['cuenta']),
    autorizacionExpiraEn: (_fecha(f['autorizacion_expira_en']))?.toLocal(),
    cursos: [
      for (final c in (f['cursos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
        CursoTrayectoria(
          instanciaId: c['instancia_id'] as String,
          cursoCodigo: c['curso_codigo'] as String? ?? '',
          cursoNombre: c['curso_nombre'] as String? ?? '',
          sedeId: c['sede_id'] as String? ?? '',
          sedeNombre: c['sede_nombre'] as String? ?? '',
          periodo: c['periodo'] as String? ?? '',
          seccion: (c['seccion'] as num?)?.toInt() ?? 1,
        ),
    ],
    sedeIds: {for (final s in (f['sede_ids'] as List<dynamic>? ?? const [])) s as String},
  );

  static FilaVoluntariado fila(Map<String, dynamic> f) => FilaVoluntariado(
    fila: (f['fila'] as num?)?.toInt() ?? 0,
    rut: f['rut'] as String? ?? '',
    nombre: f['nombre'] as String? ?? '',
    correo: f['correo'] as String? ?? '',
    estado: f['estado'] as String? ?? 'invalida',
    motivo: f['motivo'] as String?,
    fichaId: f['ficha_id'] as String?,
  );

  static RevisionVoluntariado revision(Map<String, dynamic> r) => RevisionVoluntariado(
    filas: [for (final f in (r['filas'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) fila(f)],
    creadas: (r['creadas'] as num?)?.toInt() ?? 0,
    actualizadas: (r['actualizadas'] as num?)?.toInt() ?? 0,
    rechazadas: (r['rechazadas'] as num?)?.toInt() ?? 0,
  );

  /// Una fila para la RPC importar_voluntarias
  static Map<String, Object?> filaAlta(DatosVoluntaria d) => {
    'fila': 1,
    'rut': d.rut.trim(),
    'nombres': d.nombres.trim(),
    'apellidos': d.apellidos.trim(),
    'correo': d.correo.trim(),
    'telefono': d.telefono.trim(),
    'institucion': d.institucion.trim(),
    'rol': d.rol.db,
    'fecha_ingreso': d.fechaIngreso == null ? '' : _iso(d.fechaIngreso!),
  };
}

const _mensajeError = 'No pudimos guardar la ficha. Inténtalo nuevamente.';

String _mensaje(PostgrestException e) => switch (e.code) {
  '22023' || '23505' || '23514' || '42501' || 'P0001' => e.message,
  _ => _mensajeError,
};

class SupabaseVoluntariadoRepository implements VoluntariadoRepository {
  final SupabaseClient _client;

  SupabaseVoluntariadoRepository(this._client);

  @override
  Future<List<FichaVoluntaria>> fichas() async {
    final filas = await _client.from('voluntariado').select().order('nombres', ascending: true).order('apellidos', ascending: true);
    return [for (final f in filas) MapeoVoluntariado.ficha(f)];
  }

  @override
  Future<FichaVoluntaria?> miFicha(String perfilId) async {
    final fila = await _client.from('voluntariado').select().eq('perfil_id', perfilId).maybeSingle();
    return fila == null ? null : MapeoVoluntariado.ficha(fila);
  }

  Future<Resultado<RevisionVoluntariado>> _importar(
    String sedeId,
    List<Map<String, Object?>> filas,
    bool soloValidar,
  ) async {
    try {
      final r = await _client.rpc(
        'importar_voluntarias',
        params: {'p_sede_id': sedeId, 'p_filas': filas, 'p_solo_validar': soloValidar},
      );
      return Resultado.ok(MapeoVoluntariado.revision(r as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }

  @override
  Future<Resultado<RevisionVoluntariado>> revisarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  }) => _importar(sedeId, filas, true);

  @override
  Future<Resultado<RevisionVoluntariado>> confirmarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  }) => _importar(sedeId, filas, false);

  @override
  Future<Resultado<FilaVoluntariado>> alta({required String sedeId, required DatosVoluntaria datos}) async {
    final r = await _importar(sedeId, [MapeoVoluntariado.filaAlta(datos)], false);
    if (!r.ok) return Resultado.error(r.error);
    final fila = r.valor!.filas.firstOrNull;
    if (fila == null) return const Resultado.error(_mensajeError);
    return fila.invalida ? Resultado.error(fila.motivo ?? _mensajeError) : Resultado.ok(fila);
  }

  @override
  Future<Resultado<void>> registrarAdhesion(String id, {required bool firmada, DateTime? fecha}) => _rpc(
    'registrar_adhesion_voluntaria',
    {'p_id': id, 'p_firmada': firmada, 'p_fecha': fecha == null ? null : _iso(fecha)},
  );

  @override
  Future<Resultado<void>> cambiarRol(String id, RolVoluntaria rol) =>
      _rpc('cambiar_rol_voluntaria', {'p_id': id, 'p_rol': rol.db});

  @override
  Future<Resultado<void>> registrarSalida(String id, DateTime fecha) =>
      _rpc('registrar_salida_voluntaria', {'p_id': id, 'p_fecha': _iso(fecha)});

  @override
  Future<Resultado<void>> reincorporar(String id) => _rpc('reincorporar_voluntaria', {'p_id': id});

  @override
  Future<Resultado<DateTime>> renovarAutorizacion(String id) async {
    try {
      final r = await _client.rpc('renovar_autorizacion_voluntaria', params: {'p_id': id});
      return Resultado.ok(DateTime.parse(r as String).toLocal());
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }

  @override
  Future<Resultado<void>> asignarCurso(String id, String instanciaId) =>
      _rpc('asignar_voluntaria_curso', {'p_id': id, 'p_instancia_id': instanciaId});

  @override
  Future<Resultado<void>> quitarCurso(String id, String instanciaId) =>
      _rpc('quitar_voluntaria_curso', {'p_id': id, 'p_instancia_id': instanciaId});

  Future<Resultado<void>> _rpc(String funcion, Map<String, Object?> params) async {
    try {
      await _client.rpc(funcion, params: params);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }
}
