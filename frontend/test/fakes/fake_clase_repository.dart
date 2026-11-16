import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/data/offline/cola_sincronizacion.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/clase_repository.dart';
import 'package:sembast/sembast_memory.dart';

/// Registro guardado en la "nube" del fake
class _Fila {
  EstadoAsistencia estado;
  String autora;
  DateTime editadoEn;

  _Fila(this.estado, this.autora, this.editadoEn);
}

/// Alumna o tutora de la clase en el fake
@immutable
class PersonaClase {
  final String id;
  final String nombre;
  final String rut;
  final bool autorizaImagen;
  final bool esGestion;

  const PersonaClase(this.id, this.nombre, {this.rut = '', this.autorizaImagen = true, this.esGestion = false});
}

var _bases = 0;

/// [ClaseRepository] en memoria con las reglas de las RPC de la migración 15
/// (justificada solo de Gestión, reintentos sin duplicar, el último guardado
/// gana, participación y podio solo de presentes) y la cola real de
/// sincronización sobre sembast en memoria.
///
/// El curso tiene 10 sesiones semanales: la 4 es hoy, las 1 a 3 ya se
/// realizaron con su pase de lista y la 5 en adelante están programadas.
class FakeClaseRepository implements ClaseRepository {
  /// Cuenta que usa la app (autora de los guardados)
  String perfilId;
  final Set<String> gestion;
  final DateTime hoy;

  late final Curso curso;
  late final List<SesionClase> listaSesiones;
  final List<PersonaClase> alumnas;
  final List<PersonaClase> tutoras;

  final _asistencia = <String, Map<String, _Fila>>{};
  final _tutoras = <String, Map<String, _Fila>>{};
  final _participacion = <String, Map<String, (int, bool)>>{};
  final _podio = <String, List<String>>{};

  /// Justificativo de cada alumna por clase: estado y motivo (como `resumen_justificativo`)
  final _justificativos = <String, Map<String, (EstadoJustificativo, MotivoJustificativo)>>{};

  /// Cada RPC que llegó a la "nube" (para comprobar reintentos)
  final envios = <String>[];

  bool _conectado = true;
  final _conexion = StreamController<bool>.broadcast();

  /// Se crea al primer uso, dentro de la zona de la prueba (las de widgets simulan el tiempo)
  late final ColaSincronizacion cola = ColaSincronizacion(
    base: databaseFactoryMemory.openDatabase('fake_clase_${_bases++}'),
    enviar: _enviar,
    perfilActual: () => perfilId,
    conexion: _conexion.stream,
    intervaloReintento: const Duration(minutes: 10),
  );

  /// Si no es null, la nube rechaza los guardados con este mensaje
  String? rechazo;

  FakeClaseRepository({
    this.perfilId = 'perfil-daniela',
    this.gestion = const {'perfil-camila'},
    DateTime? hoy,
    List<PersonaClase>? alumnas,
    List<PersonaClase>? tutoras,
    bool conPaseListaAnterior = true,
  }) : hoy = hoy ?? DateTime.now(),
       alumnas =
           alumnas ??
           const [
             PersonaClase('insc-1', 'Valentina Soto Morales', rut: '23.456.789-0'),
             PersonaClase('insc-2', 'Catalina Rojas Díaz', rut: '23.567.890-1'),
             PersonaClase('insc-3', 'Josefa Muñoz Vera', rut: '23.678.901-2', autorizaImagen: false),
             PersonaClase('insc-4', 'Antonia Pérez Silva', rut: '23.789.012-3'),
           ],
       tutoras =
           tutoras ??
           const [
             PersonaClase('perfil-camila', 'Camila Sepúlveda Rivas', esGestion: true),
             PersonaClase('perfil-daniela', 'Daniela Valenzuela Castro'),
             PersonaClase('perfil-javiera', 'Javiera Muñoz Pizarro'),
           ] {
    final dia = DateTime(this.hoy.year, this.hoy.month, this.hoy.day);
    listaSesiones = [
      for (var n = 1; n <= 10; n++)
        SesionClase(
          id: 'clase-$n',
          cursoId: 'inst-pcb',
          numeroSesion: n,
          fecha: dia.add(Duration(days: 7 * (n - 4))),
          tema: n == 4 ? 'Funciones y Modularización del Código' : 'Tema de la clase $n',
          estado: n < 4 ? 'realizada' : 'programada',
        ),
    ];
    curso = Curso(
      id: 'inst-pcb',
      codigo: 'PCB-2026-S2-BEAUCHEF',
      nombre: 'Programación Competitiva Básica (Python)',
      sedeId: 'sede-beauchef',
      sedeNombre: 'Sede Beauchef',
      anio: dia.year,
      semestre: dia.month >= 7 ? 2 : 1,
      totalSesiones: 10,
      classroomUrl: 'https://classroom.google.com/c/demo',
      juezVirtualUrl: 'https://vjudge.net/group/demo',
      fechaInicio: listaSesiones.first.fecha,
      fechaTermino: listaSesiones.last.fecha,
    );
    if (conPaseListaAnterior) {
      final antes = dia.subtract(const Duration(days: 30));
      for (var n = 1; n <= 3; n++) {
        // Valentina faltó en la semana 3; Camila, en la 2
        _asistencia['clase-$n'] = {
          for (final a in this.alumnas)
            a.id: _Fila(
              n == 3 && a.id == 'insc-1' ? EstadoAsistencia.ausente : EstadoAsistencia.presente,
              'Daniela Valenzuela Castro',
              antes,
            ),
        };
        _tutoras['clase-$n'] = {
          for (final t in this.tutoras)
            t.id: _Fila(
              n == 2 && t.id == 'perfil-camila' ? EstadoAsistencia.ausente : EstadoAsistencia.presente,
              'Camila Sepúlveda Rivas',
              antes,
            ),
        };
      }
    }
  }

  bool get conectado => _conectado;

  /// Simula perder o recuperar internet (al volver, la cola sube lo pendiente)
  void simularConexion(bool conectado) {
    _conectado = conectado;
    _conexion.add(conectado);
  }

  /// Deja de escuchar la red y cancela los reintentos (al terminar cada prueba)
  Future<void> cerrar() {
    unawaited(_conexion.close());
    return cola.cerrar();
  }

  String _nombre(String perfil) => tutoras.where((t) => t.id == perfil).firstOrNull?.nombre ?? perfil;

  void _exigirConexion() {
    if (!_conectado) throw Exception('Sin conexión');
  }

  EstadoAsistencia? estadoAlumna(String claseId, String inscripcionId) => _asistencia[claseId]?[inscripcionId]?.estado;
  EstadoAsistencia? estadoTutora(String claseId, String tutoraId) => _tutoras[claseId]?[tutoraId]?.estado;
  (int, bool)? participacion(String claseId, String inscripcionId) => _participacion[claseId]?[inscripcionId];
  List<String>? podio(String claseId) => _podio[claseId];

  /// Fija un estado como si lo hubiera guardado otra persona (ej. Gestión justificó)
  void fijarAsistencia(
    String claseId,
    String inscripcionId,
    EstadoAsistencia estado, {
    String autora = 'Camila Sepúlveda Rivas',
    DateTime? en,
  }) {
    (_asistencia[claseId] ??= {})[inscripcionId] = _Fila(estado, autora, en ?? DateTime.now());
  }

  /// Vincula un justificativo; uno aprobado deja justificada la asistencia ya registrada (migración 18)
  void fijarJustificativo(
    String claseId,
    String inscripcionId,
    EstadoJustificativo estado, {
    MotivoJustificativo motivo = MotivoJustificativo.salud,
  }) {
    (_justificativos[claseId] ??= {})[inscripcionId] = (estado, motivo);
    final fila = _asistencia[claseId]?[inscripcionId];
    if (estado == EstadoJustificativo.aceptado && fila != null) fila.estado = EstadoAsistencia.justificada;
  }

  /// Quita el justificativo; si estaba aprobado, la asistencia justificada vuelve a ausente
  void quitarJustificativo(String claseId, String inscripcionId) {
    final quitado = _justificativos[claseId]?.remove(inscripcionId);
    final fila = _asistencia[claseId]?[inscripcionId];
    if (quitado?.$1 == EstadoJustificativo.aceptado && fila?.estado == EstadoAsistencia.justificada) {
      fila!.estado = EstadoAsistencia.ausente;
    }
  }

  bool _aceptado(String claseId, String inscripcionId) =>
      _justificativos[claseId]?[inscripcionId]?.$1 == EstadoJustificativo.aceptado;

  @override
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion => cola.estadoSincronizacion;

  @override
  ValueListenable<int> get cambiosPendientes => cola.cambiosPendientes;

  @override
  ValueListenable<String?> get ultimoRechazo => cola.ultimoRechazo;

  @override
  Future<void> sincronizar() => cola.sincronizar();

  @override
  Future<List<Curso>> instancias({String? tutoraId}) async {
    _exigirConexion();
    if (tutoraId != null && !tutoras.any((t) => t.id == tutoraId)) return const [];
    return [curso];
  }

  @override
  Future<List<SesionClase>> sesiones(String instanciaId) async {
    _exigirConexion();
    return [
      for (final s in listaSesiones)
        s.estado == 'programada' && (_asistencia[s.id]?.isNotEmpty ?? false) ? s.copyWith(estado: 'realizada') : s,
    ];
  }

  @override
  Future<ListaClase> lista(String claseId) async {
    _exigirConexion();
    final filas = _asistencia[claseId] ?? const {};
    final part = _participacion[claseId] ?? const {};
    final podio = _podio[claseId];
    final mapa = [
      for (final a in alumnas)
        <String, dynamic>{
          'inscripcion_id': a.id,
          'alumna_id': 'alumna-${a.id}',
          'nombres': a.nombre,
          'apellidos': '',
          'rut': a.rut,
          'autoriza_imagen': a.autorizaImagen,
          'estado': filas[a.id]?.estado.name,
          'registrado_por_nombre': filas[a.id]?.autora,
          'actualizado_en': filas[a.id]?.editadoEn.toUtc().toIso8601String(),
          'ejercicios': part[a.id]?.$1,
          'participo_activa': part[a.id]?.$2,
          'podio_kahoot': podio == null || !podio.contains(a.id) ? null : podio.indexOf(a.id) + 1,
          'justificativo_estado': _justificativos[claseId]?[a.id]?.$1.name,
          'justificativo_motivo': _justificativos[claseId]?[a.id]?.$2.name,
        },
    ];
    return MapeoClase.conPendientes(
      MapeoClase.lista(claseId, mapa),
      asistencia: await cola.pendiente(OperacionesClase.clave(OperacionesClase.asistencia, claseId)),
      participacion: await cola.pendiente(OperacionesClase.clave(OperacionesClase.participacion, claseId)),
      podio: await cola.pendiente(OperacionesClase.clave(OperacionesClase.podio, claseId)),
    );
  }

  @override
  Future<List<RegistroAsistenciaTutora>> asistenciaTutoras(String claseId) async {
    _exigirConexion();
    final filas = _tutoras[claseId] ?? const {};
    return MapeoClase.tutorasConPendientes([
      for (final t in tutoras)
        RegistroAsistenciaTutora(
          sesionId: claseId,
          tutoraId: t.id,
          tutoraNombre: t.nombre,
          esEquipoGestion: t.esGestion,
          estado: filas[t.id]?.estado ?? EstadoAsistencia.pendiente,
          editadoPor: filas[t.id]?.autora,
          editadoEn: filas[t.id]?.editadoEn,
        ),
    ], await cola.pendiente(OperacionesClase.clave(OperacionesClase.asistenciaTutores, claseId)));
  }

  @override
  Future<Map<String, EstadoAsistencia>> miAsistencia({required String instanciaId, required String tutoraId}) async {
    _exigirConexion();
    return {
      for (final e in _tutoras.entries)
        if (e.value[tutoraId] != null) e.key: e.value[tutoraId]!.estado,
    };
  }

  Future<ResultadoGuardado> _guardar(String tipo, String claseId, Map<String, dynamic> datos, {int prioridad = 0}) =>
      cola.guardar(
        OperacionPendiente(
          clave: OperacionesClase.clave(tipo, claseId),
          tipo: tipo,
          datos: datos,
          guardadoEn: DateTime.now().toUtc(),
          perfilId: perfilId,
          prioridad: prioridad,
        ),
      );

  @override
  Future<ResultadoGuardado> guardarAsistencia(String claseId, List<RegistroAsistencia> registros) =>
      _guardar(OperacionesClase.asistencia, claseId, MapeoClase.datosAsistencia(claseId, registros));

  @override
  Future<ResultadoGuardado> guardarParticipacion(String claseId, List<ParticipacionClase> participaciones) => _guardar(
    OperacionesClase.participacion,
    claseId,
    MapeoClase.datosParticipacion(claseId, participaciones),
    prioridad: 1,
  );

  @override
  Future<ResultadoGuardado> guardarPodio(String claseId, List<String> inscripciones) =>
      _guardar(OperacionesClase.podio, claseId, MapeoClase.datosPodio(claseId, inscripciones), prioridad: 2);

  @override
  Future<ResultadoGuardado> guardarAsistenciaTutoras(String claseId, List<RegistroAsistenciaTutora> registros) =>
      _guardar(OperacionesClase.asistenciaTutores, claseId, MapeoClase.datosTutoras(claseId, registros));

  // --- La "nube": mismas reglas que las RPC ---

  SesionClase _clase(String id) {
    final s = listaSesiones.firstWhere((s) => s.id == id);
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    if (s.suspendida) {
      throw const RechazoServidorException('La clase está suspendida: no se registra asistencia ni participación.');
    }
    if (s.fecha.isAfter(dia)) throw const RechazoServidorException('La clase aún no se realiza.');
    return s;
  }

  Future<String?> _enviar(OperacionPendiente op) async {
    if (!_conectado) throw Exception('Sin conexión');
    if (rechazo != null) throw RechazoServidorException(rechazo!);
    envios.add(op.tipo);
    final claseId = op.datos['clase_id'] as String;
    _clase(claseId);
    final autora = _nombre(op.perfilId);
    final esGestion = gestion.contains(op.perfilId);

    switch (op.tipo) {
      case OperacionesClase.asistencia:
        final filas = _asistencia[claseId] ??= {};
        var justificadas = 0, posteriores = 0;
        for (final r in op.datos['registros'] as List) {
          final id = r['inscripcion_id'] as String;
          final pedido = MapeoClase.estado(r['estado']);
          final actual = filas[id];
          // Con un justificativo aprobado queda justificada, la pida quien la pida
          final nuevo = _aceptado(claseId, id) ? EstadoAsistencia.justificada : pedido;
          if (nuevo != pedido) justificadas++;
          if (actual != null && actual.estado == nuevo) continue;
          if (actual != null && actual.editadoEn.isAfter(op.guardadoEn)) {
            posteriores++;
          } else if (!esGestion &&
              !_aceptado(claseId, id) &&
              (nuevo == EstadoAsistencia.justificada || actual?.estado == EstadoAsistencia.justificada)) {
            justificadas++;
          } else {
            filas[id] = _Fila(nuevo, autora, DateTime.now());
            if (nuevo != EstadoAsistencia.presente) {
              _participacion[claseId]?.remove(id);
              _podio[claseId]?.remove(id);
            }
          }
        }
        return MapeoClase.avisoAsistencia({
          'justificadas_conservadas': justificadas,
          'conservados_por_edicion_posterior': posteriores,
        });
      case OperacionesClase.participacion:
        var omitidas = 0;
        final filas = _participacion[claseId] ??= {};
        for (final r in op.datos['registros'] as List) {
          final id = r['inscripcion_id'] as String;
          if (_asistencia[claseId]?[id]?.estado != EstadoAsistencia.presente) {
            omitidas++;
            continue;
          }
          filas[id] = ((r['ejercicios'] as num).toInt(), r['participo_activa'] == true);
        }
        return MapeoClase.avisoParticipacion({'omitidas': omitidas});
      case OperacionesClase.podio:
        final ids = [
          for (final clave in ['primero', 'segundo', 'tercero'])
            if (op.datos[clave] != null) op.datos[clave] as String,
        ];
        if (ids.toSet().length < ids.length) {
          throw const RechazoServidorException('Elige alumnas distintas para el podio.');
        }
        final presentes = (_asistencia[claseId] ?? const {}).values.where((f) => f.estado == EstadoAsistencia.presente);
        if (ids.any((id) => _asistencia[claseId]?[id]?.estado != EstadoAsistencia.presente)) {
          throw const RechazoServidorException('El podio solo admite alumnas presentes en la clase.');
        }
        // Un lugar por alumna presente, hasta tres
        if (ids.isEmpty || ids.length != presentes.length.clamp(0, 3)) {
          throw RechazoServidorException('Con ${presentes.length} alumnas presentes, el podio lleva otros lugares.');
        }
        _podio[claseId] = ids;
        return null;
      case OperacionesClase.asistenciaTutores:
        final filas = _tutoras[claseId] ??= {};
        for (final r in op.datos['registros'] as List) {
          final id = r['tutor_id'] as String;
          final nuevo = MapeoClase.estado(r['estado']);
          final actual = filas[id];
          if (actual != null && (actual.estado == nuevo || actual.editadoEn.isAfter(op.guardadoEn))) continue;
          filas[id] = _Fila(nuevo, autora, DateTime.now());
        }
        return null;
    }
    throw RechazoServidorException('Operación desconocida: ${op.tipo}');
  }
}
