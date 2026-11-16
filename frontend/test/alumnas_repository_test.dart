import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const json = {'content-type': 'application/json'};

  final filaNomina = {
    'inscripcion_id': 'insc-1',
    'alumna_id': 'alumna-1',
    'rut': '22.341.890-2',
    'nombres': 'Valentina',
    'apellidos': 'Soto Morales',
    'instancia_curso_id': 'inst-1',
    'sede_id': 'sede-a',
    'sede_nombre': 'Sede Beauchef',
    'curso_codigo': 'PCB',
    'curso_nombre': 'Programación Competitiva Básica',
    'periodo_academico': '2026-2',
    'seccion': 2,
    'fecha_inicio': '2026-08-01',
    'estado': 'preinscrita',
    'fecha_inscripcion': '2026-08-01',
    'fecha_retiro': null,
    'motivo_retiro': null,
    'tratamiento_datos': 'pendiente',
    'autoriza_fotos': false,
    'clases_computables': 4,
    'clases_asistidas': 3,
    'sesiones_transcurridas': 3,
    'regularizacion_urgente': true,
  };

  group('MapeoAlumnas', () {
    test('la fila de la nómina trae asistencia, sección y la alerta de regularización', () {
      final i = MapeoAlumnas.inscripcion(filaNomina);
      expect(i.nombreCompleto, 'Valentina Soto Morales');
      expect(i.cursoEtiqueta, 'PCB · 2026-2 · Sección B');
      expect(i.porcentajeAsistencia, 75);
      expect(i.consentimiento, ConsentimientoDatos.pendiente);
      expect(i.regularizacionUrgente, isTrue);
      expect(i.vigente, isTrue);
      expect(MapeoAlumnas.inscripcion({...filaNomina, 'clases_computables': 0}).porcentajeAsistencia, isNull);
    });

    test('la ficha trae el apoderado, los canales y las revocaciones con su fecha', () {
      final ficha = MapeoAlumnas.ficha({
        'id': 'alumna-1',
        'rut': '22.341.890-2',
        'nombres': 'Valentina',
        'apellidos': 'Soto Morales',
        'fecha_nacimiento': '2010-01-10',
        'correo': null,
        'establecimiento_educacional': 'Liceo 1',
        'curso_escolar': '1° medio',
        'apoderados': {
          'rut': null,
          'nombres': 'Marcela',
          'apellidos': 'Morales',
          'telefono': '+56 9 8765 4321',
          'correo': 'marcela@correo.cl',
          'parentesco': 'Madre',
        },
        'autorizaciones_apoderado': {
          'autoriza_tratamiento_datos': 'otorgada',
          'documento_respaldo_url': 'alumna-1/1731700000000_firma.pdf',
          'fecha_firma': '2026-03-28T00:00:00+00:00',
          'updated_at': '2026-11-15T03:31:20.365261+00:00',
          'perfiles': {'nombres': 'Camila', 'apellidos': 'Sepúlveda'},
          'autorizaciones_imagen_canales': [
            {'canal': 'redes_sociales', 'autorizado': true, 'fecha_revocacion': null, 'motivo_revocacion': null},
            {'canal': 'prensa', 'autorizado': false, 'fecha_revocacion': '2026-10-01', 'motivo_revocacion': 'Solicitud'},
            {'canal': 'interno', 'autorizado': true, 'fecha_revocacion': null, 'motivo_revocacion': null},
          ],
        },
      }, [MapeoAlumnas.inscripcion(filaNomina)]);

      expect(ficha.apoderado!.nombreCompleto, 'Marcela Morales');
      final a = ficha.autorizaciones;
      expect(a.tratamientoDatos, ConsentimientoDatos.otorgado);
      expect(a.autorizado(CanalImagen.redesSociales), isTrue);
      expect(a.autorizado(CanalImagen.webInstitucional), isFalse, reason: 'sin respuesta = no autorizado');
      expect(a.revocaciones[CanalImagen.prensa]!.fecha, DateTime(2026, 10, 1));
      expect(a.revocaciones[CanalImagen.prensa]!.motivo, 'Solicitud');
      expect(a.canales.length, 2, reason: 'el canal interno no se muestra en la app');
      expect(a.nombreDocumento, 'firma.pdf');
      expect(a.fechaFirma, DateTime(2026, 3, 28));
      expect(a.registradoPor, 'Camila Sepúlveda');
      expect(ficha.inscripciones, hasLength(1));
    });

    test('sin autorizaciones registradas el consentimiento queda pendiente', () {
      expect(MapeoAlumnas.autorizaciones(null).tratamientoDatos, ConsentimientoDatos.pendiente);
      expect(ConsentimientoDatos.desdeDb('revocada'), ConsentimientoDatos.noOtorgado);
    });

    test('el nombre del respaldo se limpia para usarlo como ruta', () {
      expect(MapeoAlumnas.nombreSeguro('Autorización Firmada (1).PDF'), 'autorizacion_firmada_1_.pdf');
    });

    test('el respaldo solo admite PDF, PNG o JPG de hasta 5 MB', () {
      expect(ArchivoAdjunto(nombre: 'firma.PDF', bytes: Uint8List(10)).error, isNull);
      expect(ArchivoAdjunto(nombre: 'firma.PDF', bytes: Uint8List(10)).tipo, 'application/pdf');
      expect(ArchivoAdjunto(nombre: 'foto.jpeg', bytes: Uint8List(10)).tipo, 'image/jpeg');
      expect(ArchivoAdjunto(nombre: 'firma.docx', bytes: Uint8List(10)).error, contains('PDF, PNG o JPG'));
      expect(ArchivoAdjunto(nombre: 'firma.pdf', bytes: Uint8List(ArchivoAdjunto.tamanoMaximo + 1)).error, contains('5 MB'));
    });
  });

  group('SupabaseAlumnasRepository', () {
    late List<http.Request> pedidos;

    SupabaseAlumnasRepository crear(http.Response Function(http.Request r) responder) {
      pedidos = [];
      final cliente = MockClient((r) async {
        pedidos.add(r);
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      });
      return SupabaseAlumnasRepository(
        SupabaseClient('http://localhost:54321', 'anon', httpClient: cliente),
        ahora: () => DateTime.fromMillisecondsSinceEpoch(1731700000000),
      );
    }

    http.Response ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: json);
    http.Response error(int status, String code, String message) =>
        http.Response(jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}), status,
            headers: json);

    Map<String, Object?> filaRpc(int fila, String estado, {List<String> conflictos = const [], String? motivo}) => {
      'fila': fila,
      'datos': {'fila': fila, 'rut': '22.341.890-2', 'nombres': 'Ana'},
      'rut': '22.341.890-2',
      'nombre': 'Ana Pérez',
      'apoderado': 'Marta Pérez',
      'estado': estado,
      'motivo': motivo,
      'errores': const [],
      'conflictos': conflictos,
      'diferencias': const [],
      'filas_repetidas': const [],
      'resolucion': null,
    };

    test('la nómina se lee de la vista y se puede filtrar por sede', () async {
      final repo = crear((_) => ok([filaNomina]));
      final nomina = await repo.nomina(sedeId: 'sede-a');
      expect(nomina.single.inscripcionId, 'insc-1');
      expect(pedidos.single.url.path, '/rest/v1/nomina_alumnas');
      expect(pedidos.single.url.queryParameters['sede_id'], 'eq.sede-a');
    });

    test('la ficha combina la alumna y sus inscripciones', () async {
      final repo = crear((r) => r.url.path.endsWith('/alumnas')
          ? ok({
              'id': 'alumna-1',
              'rut': '22.341.890-2',
              'nombres': 'Valentina',
              'apellidos': 'Soto',
              'fecha_nacimiento': '2010-01-10',
              'apoderados': null,
              'autorizaciones_apoderado': null,
            })
          : ok([filaNomina]));
      final ficha = await repo.ficha('alumna-1');
      expect(ficha!.inscripciones.single.cursoCodigo, 'PCB');
      expect(pedidos.first.url.queryParameters['select'], contains('apoderados!alumnas_apoderado_id_fkey'));
      expect(pedidos.last.url.queryParameters['alumna_id'], 'eq.alumna-1');
    });

    test('la revisión llama a la RPC sin guardar y envía las resoluciones y pendientes', () async {
      final repo = crear((_) => ok({
            'inscritas': 0,
            'pendientes': 0,
            'filas': [
              {
                ...filaRpc(2, 'conflicto', conflictos: ['ficha_distinta', 'otro'], motivo: 'El RUT ya tiene ficha'),
                'diferencias': [
                  {'campo': 'Nombres', 'ficha': 'Antonia', 'planilla': 'Antonella'},
                ],
              },
              {...filaRpc(3, 'descartada'), 'resolucion': 'descartar', 'filas_repetidas': [3, 4]},
            ],
          }));
      final r = await repo.revisarImportacion(
        instanciaId: 'inst-1',
        archivo: 'nomina.csv',
        filas: const [
          FilaNomina(numero: 2, datos: {'rut': '22.341.890-2'}, conflictoId: 'conf-1'),
          FilaNomina(numero: 3, datos: {'rut': '22.341.890-2'}, resolucion: ResolucionFila.descartar),
        ],
      );
      expect(pedidos.single.url.path, '/rest/v1/rpc/importar_alumnas');
      final cuerpo = jsonDecode(pedidos.single.body) as Map<String, dynamic>;
      expect(cuerpo['p_solo_validar'], isTrue);
      expect(cuerpo['p_filas'], [
        {'rut': '22.341.890-2', 'fila': 2, 'conflicto_id': 'conf-1'},
        {'rut': '22.341.890-2', 'fila': 3, 'resolucion': 'descartar'},
      ]);
      final filas = r.valor!.filas;
      expect(filas.first.estado, EstadoFilaNomina.conflicto);
      expect(filas.first.conflictos, [TipoConflicto.fichaDistinta], reason: 'los tipos desconocidos se ignoran');
      expect(filas.first.diferencias.single.planilla, 'Antonella');
      expect(filas.first.conflictoId, 'conf-1', reason: 'se conserva el pendiente que resuelve');
      expect(filas.last.resolucion, ResolucionFila.descartar);
      expect(filas.last.filasRepetidas, [3, 4]);
      expect(r.valor!.porResolver, 1);
      expect(r.valor!.contar(EstadoFilaNomina.descartada), 1);
    });

    test('confirmar la carga inscribe y devuelve cuántas quedaron pendientes', () async {
      final repo = crear((_) => ok({
            'inscritas': 1,
            'pendientes': 1,
            'filas': [filaRpc(2, 'nueva'), filaRpc(3, 'pendiente')],
          }));
      final r = await repo.confirmarImportacion(instanciaId: 'inst-1', archivo: 'n.csv', filas: const []);
      final cuerpo = jsonDecode(pedidos.single.body) as Map;
      expect(cuerpo['p_solo_validar'], isFalse);
      expect(cuerpo['p_archivo'], 'n.csv');
      expect(r.valor!.inscritas, 1);
      expect(r.valor!.pendientes, 1);
      expect(r.valor!.revision.filas.last.estado, EstadoFilaNomina.pendiente);
    });

    final datosAna = DatosAlumna(
      rut: ' 22.341.890-2 ',
      nombres: 'Ana',
      apellidos: 'Pérez',
      fechaNacimiento: DateTime(2011, 4, 5),
      nombresApoderado: 'Marta',
      apellidosApoderado: 'Pérez',
      telefonoApoderado: '+56 9 1234 5678',
      correoApoderado: 'marta@correo.cl',
    );

    test('la inscripción individual no inscribe si hay un conflicto y lo devuelve', () async {
      final repo = crear((_) => ok({
            'inscritas': 0,
            'filas': [filaRpc(1, 'conflicto', conflictos: ['correo_en_uso'], motivo: 'El correo ya lo usa otra persona')],
          }));
      final r = await repo.inscribir(instanciaId: 'inst-1', datos: datosAna);
      expect(r.valor!.conflictos, [TipoConflicto.correoEnUso]);
      expect(pedidos, hasLength(1), reason: 'solo se revisa');
      final fila = ((jsonDecode(pedidos.single.body) as Map)['p_filas'] as List).single as Map;
      expect(fila['rut'], '22.341.890-2');
      expect(fila['fecha_nacimiento'], '2011-04-05');
    });

    test('la inscripción individual inscribe con la resolución elegida', () async {
      final repo = crear((r) => ok({
            'inscritas': 1,
            'filas': [filaRpc(1, 'existente')],
          }));
      final r = await repo.inscribir(instanciaId: 'inst-1', datos: datosAna, resolucion: ResolucionFila.mantenerFicha);
      expect(r.valor!.estado, EstadoFilaNomina.existente);
      expect(pedidos, hasLength(2));
      expect((jsonDecode(pedidos.last.body) as Map)['p_solo_validar'], isFalse);
      expect((((jsonDecode(pedidos.last.body) as Map)['p_filas'] as List).single as Map)['resolucion'], 'mantener_ficha');
    });

    final conflicto = ConflictoImportacion(
      id: 'conf-1',
      instanciaId: 'inst-1',
      cursoEtiqueta: 'PCB · 2026-2 · Sede Beauchef',
      archivo: 'nomina.csv',
      numeroFila: 7,
      datos: const {'fila': 7, 'rut': '22.341.890-2'},
      motivo: 'RUT repetido',
      creadoEn: DateTime(2026, 11, 16),
    );

    test('los conflictos pendientes traen su curso, archivo y datos', () async {
      final repo = crear((_) => ok([
            {
              'id': 'conf-1',
              'instancia_curso_id': 'inst-1',
              'archivo': 'nomina.csv',
              'numero_fila': 7,
              'fila': {'fila': 7, 'rut': '22.341.890-2'},
              'motivo': 'RUT repetido',
              'created_at': '2026-11-16T12:00:00+00:00',
              'instancias_curso': {'periodo_academico': '2026-2', 'cursos': {'codigo': 'PCB'}, 'sedes': {'nombre': 'Sede Beauchef'}},
            },
          ]));
      final c = (await repo.conflictosPendientes()).single;
      expect(pedidos.single.url.path, '/rest/v1/conflictos_importacion');
      expect(c.cursoEtiqueta, 'PCB · 2026-2 · Sede Beauchef');
      expect(c.fila.conflictoId, 'conf-1');
      expect(c.fila.numero, 7);
    });

    test('los pendientes se revisan juntos por curso y se resuelven reemplazándolos', () async {
      final repo = crear((r) {
        final filas = ((jsonDecode(r.body) as Map)['p_filas'] as List);
        return ok({'inscritas': 1, 'filas': [for (final f in filas) filaRpc((f as Map)['fila'] as int, 'nueva')]});
      });
      final otro = ConflictoImportacion(
        id: 'conf-2',
        instanciaId: 'inst-2',
        cursoEtiqueta: 'WEB',
        numeroFila: 3,
        datos: const {'rut': '1-9'},
        motivo: 'x',
        creadoEn: DateTime(2026, 11, 16),
      );
      final revision = await repo.revisarConflictos([conflicto, otro]);
      expect(pedidos, hasLength(2), reason: 'una revisión por curso');
      expect(revision.valor!.map((f) => f.conflictoId), ['conf-1', 'conf-2']);

      final r = await repo.resolverConflicto(conflicto, conflicto.fila.conResolucion(ResolucionFila.sinCorreo));
      final cuerpo = jsonDecode(pedidos.last.body) as Map;
      expect(cuerpo['p_solo_validar'], isFalse);
      expect((cuerpo['p_filas'] as List).single, containsPair('conflicto_id', 'conf-1'));
      expect((cuerpo['p_filas'] as List).single, containsPair('resolucion', 'sin_correo'));
      expect(r.valor!.estado, EstadoFilaNomina.nueva);
    });

    test('descartar un pendiente llama a su RPC', () async {
      final repo = crear((_) => http.Response('', 204));
      final r = await repo.descartarConflicto('conf-1');
      expect(r.ok, isTrue);
      expect(pedidos.single.url.path, '/rest/v1/rpc/descartar_conflicto_importacion');
    });

    test('sin permiso la RPC responde con el mensaje de la base', () async {
      final repo = crear((_) => error(403, '42501', 'Solo la Directiva inscribe alumnas.'));
      final r = await repo.revisarImportacion(instanciaId: 'inst-1', archivo: 'n.csv', filas: const []);
      expect(r.error, 'Solo la Directiva inscribe alumnas.');
    });

    test('las autorizaciones suben el respaldo al bucket privado y luego llaman a la RPC', () async {
      final repo = crear((r) => r.url.path.startsWith('/storage') ? ok({'Key': 'autorizaciones/x'}) : ok({'id': 'aut-1'}));
      final r = await repo.registrarAutorizaciones(
        alumnaId: 'alumna-1',
        tratamientoDatos: ConsentimientoDatos.otorgado,
        canales: const {CanalImagen.redesSociales: true, CanalImagen.webInstitucional: true},
        respaldo: ArchivoAdjunto(nombre: 'Autorización firmada.pdf', bytes: Uint8List.fromList([1, 2, 3])),
        fechaFirma: DateTime(2026, 8, 1),
      );
      expect(r.ok, isTrue);
      expect(pedidos.first.url.path, '/storage/v1/object/autorizaciones/alumna-1/1731700000000_autorizacion_firmada.pdf');
      final cuerpo = jsonDecode(pedidos.last.body) as Map<String, dynamic>;
      expect(pedidos.last.url.path, '/rest/v1/rpc/registrar_autorizaciones');
      expect(cuerpo['p_tratamiento_datos'], 'otorgada');
      expect(cuerpo['p_documento'], 'alumna-1/1731700000000_autorizacion_firmada.pdf');
      expect(cuerpo['p_fecha_firma'], '2026-08-01');
      expect(cuerpo['p_canales'], {
        'redes_sociales': true,
        'memoria_anual': false,
        'prensa': false,
        'sitio_web': true,
        'reporte_patrocinantes': false,
      });
    });

    test('si la RPC rechaza las autorizaciones, el respaldo subido se borra', () async {
      final repo = crear((r) => r.url.path.startsWith('/storage')
          ? ok(r.method == 'DELETE' ? [] : {'Key': 'autorizaciones/x'})
          : error(400, '22023', 'La fecha de firma no puede ser futura.'));
      final r = await repo.registrarAutorizaciones(
        alumnaId: 'alumna-1',
        tratamientoDatos: ConsentimientoDatos.otorgado,
        canales: const {},
        respaldo: ArchivoAdjunto(nombre: 'firma.pdf', bytes: Uint8List(3)),
      );
      expect(r.error, 'La fecha de firma no puede ser futura.');
      expect(pedidos.last.method, 'DELETE');
      expect(pedidos.last.body, contains('alumna-1/1731700000000_firma.pdf'));
    });

    test('un respaldo no admitido no se sube', () async {
      final repo = crear((_) => ok({}));
      final r = await repo.registrarAutorizaciones(
        alumnaId: 'alumna-1',
        tratamientoDatos: ConsentimientoDatos.otorgado,
        canales: const {},
        respaldo: ArchivoAdjunto(nombre: 'firma.docx', bytes: Uint8List(3)),
      );
      expect(r.error, contains('PDF, PNG o JPG'));
      expect(pedidos, isEmpty);
    });

    test('un 403 del bucket se informa como falta de permiso', () async {
      final repo = crear((_) => http.Response(jsonEncode({'statusCode': '403', 'error': 'Unauthorized', 'message': 'new row violates row-level security policy'}), 403, headers: json));
      final r = await repo.registrarAutorizaciones(
        alumnaId: 'alumna-1',
        tratamientoDatos: ConsentimientoDatos.otorgado,
        canales: const {},
        respaldo: ArchivoAdjunto(nombre: 'firma.pdf', bytes: Uint8List(3)),
      );
      expect(r.error, 'No tienes permiso para adjuntar respaldos de esta alumna.');
    });

    test('la revocación y el retiro envían fecha, motivo y canales de la base', () async {
      final repo = crear((_) => ok({}));
      await repo.revocarImagen(
        alumnaId: 'alumna-1',
        canales: const [CanalImagen.patrocinadores, CanalImagen.prensa],
        fecha: DateTime(2026, 10, 1),
        motivo: ' Solicitud del apoderado ',
      );
      expect(pedidos.last.url.path, '/rest/v1/rpc/revocar_autorizacion_imagen');
      expect(jsonDecode(pedidos.last.body), {
        'p_alumna_id': 'alumna-1',
        'p_canales': ['reporte_patrocinantes', 'prensa'],
        'p_fecha': '2026-10-01',
        'p_motivo': 'Solicitud del apoderado',
      });

      await repo.retirar(inscripcionId: 'insc-1', fecha: DateTime(2026, 10, 2), motivo: 'Cambio de colegio');
      expect(pedidos.last.url.path, '/rest/v1/rpc/retirar_inscripcion');
      expect(jsonDecode(pedidos.last.body), containsPair('p_fecha', '2026-10-02'));
    });

    test('un error inesperado se informa con un mensaje genérico', () async {
      final repo = crear((_) => error(500, 'XX000', 'internal'));
      final r = await repo.retirar(inscripcionId: 'insc-1', fecha: DateTime(2026, 10, 2), motivo: 'x');
      expect(r.error, startsWith('No pudimos guardar'));
    });

    test('el respaldo se abre con una URL firmada de corta duración', () async {
      final repo = crear((_) => ok({'signedURL': '/object/sign/autorizaciones/alumna-1/firma.pdf?token=t'}));
      final r = await repo.urlRespaldo('alumna-1/firma.pdf');
      expect(pedidos.single.url.path, '/storage/v1/object/sign/autorizaciones/alumna-1/firma.pdf');
      expect(jsonDecode(pedidos.single.body), {'expiresIn': 60});
      expect(r.valor, contains('token=t'));
    });
  });
}
