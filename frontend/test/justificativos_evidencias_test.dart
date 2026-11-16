import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart' show ArchivoAdjunto;
import 'package:ninas_pro_hub/repositories/clase_repository.dart';
import 'package:ninas_pro_hub/repositories/evidencias_repository.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart';
import 'package:ninas_pro_hub/screens/tutora/clase_sesion_controller.dart';
import 'package:ninas_pro_hub/services/compresion_imagen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_clase_repository.dart';

void main() {
  const json = {'content-type': 'application/json'};
  http.Response ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: json);
  http.Response error(int status, String code, String message) => http.Response(
    jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}),
    status,
    headers: json,
  );

  late List<http.Request> pedidos;
  SupabaseClient cliente(http.Response Function(http.Request r) responder) {
    pedidos = [];
    return SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient((r) async {
        pedidos.add(r);
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      }),
    );
  }

  final ahora = DateTime.fromMillisecondsSinceEpoch(1731700000000);

  final filaDetalle = {
    'id': 'just-1',
    'clase_id': 'clase-3',
    'inscripcion_id': 'insc-1',
    'alumna_id': 'alumna-1',
    'alumna_nombres': 'Valentina',
    'alumna_apellidos': 'Soto Morales',
    'alumna_rut': '22.341.890-2',
    'numero_sesion': 3,
    'clase_fecha': '2026-11-07',
    'clase_tema': 'Bucles',
    'instancia_curso_id': 'inst-1',
    'sede_id': 'sede-1',
    'sede_nombre': 'Sede Beauchef',
    'curso_nombre': 'Programación Competitiva Básica',
    'motivo': 'transporte',
    'explicacion': 'Paro de micros',
    'archivo_adjunto_url': 'insc-1/clase-3/1731700000000_constancia.pdf',
    'estado': 'rechazado',
    'observacion_resolucion': 'Falta la constancia',
    'fecha_resolucion': '2026-11-08T12:00:00+00:00',
    'resuelto_por_nombre': 'Camila Sepúlveda',
    'enviado_por_alumna': true,
    'created_at': '2026-11-07T15:00:00+00:00',
  };

  group('MapeoJustificativos', () {
    test('el detalle trae la alumna, la clase, el motivo y la resolución', () {
      final j = MapeoJustificativos.detalle(filaDetalle);
      expect(j.alumnaNombre, 'Valentina Soto Morales');
      expect(j.claseEtiqueta, 'Clase #3 · 07/11/2026');
      expect(j.motivo, MotivoJustificativo.transporte);
      expect(j.motivo.label, 'Transporte / Clima');
      expect(j.estado, EstadoJustificativo.rechazado);
      expect(j.estado.label, 'Rechazado');
      expect(j.observacion, 'Falta la constancia');
      expect(j.nombreRespaldo, 'constancia.pdf');
      expect(j.enviadoPorAlumna, isTrue);
    });

    test('la clase justificable se ofrece solo sin otro vigente ni ya justificada (US-35 escenario 4)', () {
      Map<String, dynamic> fila(String? asistencia, String? justificativo) => {
        'clase_id': 'clase-5',
        'inscripcion_id': 'insc-1',
        'numero_sesion': 5,
        'fecha': '2026-11-28',
        'tema': 'Listas',
        'curso_nombre': 'PCB',
        'asistencia': asistencia,
        'justificativo_estado': justificativo,
      };
      final libre = MapeoJustificativos.clase(fila(null, null));
      expect(libre.etiqueta, 'Clase #5 · 28/11/2026 · Listas');
      expect(libre.disponible, isTrue);
      expect(MapeoJustificativos.clase(fila('ausente', null)).disponible, isTrue);
      expect(MapeoJustificativos.clase(fila(null, 'pendiente')).disponible, isFalse);
      expect(MapeoJustificativos.clase(fila('justificada', null)).disponible, isFalse);
    });

    test('los motivos y estados desconocidos no se inventan', () {
      expect(MotivoJustificativo.desdeDb('diagnostico'), isNull);
      expect(EstadoJustificativo.desdeDb(null), isNull);
    });
  });

  group('SupabaseJustificativosRepository', () {
    test('la bandeja lee la vista de detalle, la más reciente primero', () async {
      final repo = SupabaseJustificativosRepository(cliente((_) => ok([filaDetalle])));
      final lista = await repo.justificativos();
      expect(lista.single.id, 'just-1');
      expect(pedidos.single.url.path, '/rest/v1/justificativos_detalle');
      expect(pedidos.single.url.queryParameters['order'], startsWith('created_at.desc'));
    });

    test('la alumna envía con su respaldo en la carpeta de la inscripción y la clase', () async {
      final repo = SupabaseJustificativosRepository(
        cliente((r) => r.url.path.startsWith('/storage') ? ok({'Key': 'justificativos/x'}) : ok({'id': 'just-2'})),
        ahora: () => ahora,
      );
      final r = await repo.enviar(
        clase: MapeoJustificativos.clase({
          'clase_id': 'clase-5',
          'inscripcion_id': 'insc-1',
          'numero_sesion': 5,
          'fecha': '2026-11-28',
          'curso_nombre': 'PCB',
        }),
        motivo: MotivoJustificativo.salud,
        explicacion: '  Control médico  ',
        respaldo: ArchivoAdjunto(nombre: 'Constancia de atención.pdf', bytes: Uint8List(3)),
      );
      expect(r.ok, isTrue);
      expect(
        pedidos.first.url.path,
        '/storage/v1/object/justificativos/insc-1/clase-5/1731700000000_constancia_de_atencion.pdf',
      );
      expect(pedidos.last.url.path, '/rest/v1/rpc/enviar_justificativo');
      expect(jsonDecode(pedidos.last.body), {
        'p_clase_id': 'clase-5',
        'p_motivo': 'salud',
        'p_explicacion': 'Control médico',
        'p_archivo': 'insc-1/clase-5/1731700000000_constancia_de_atencion.pdf',
      });
    });

    test('si la base rechaza el justificativo, el respaldo subido se borra', () async {
      final repo = SupabaseJustificativosRepository(
        cliente(
          (r) => r.url.path.startsWith('/storage')
              ? ok(r.method == 'DELETE' ? [] : {'Key': 'justificativos/x'})
              : error(409, '23505', 'Ya hay un justificativo pendiente para esa clase.'),
        ),
        ahora: () => ahora,
      );
      final r = await repo.registrar(
        claseId: 'clase-3',
        inscripcionId: 'insc-2',
        motivo: MotivoJustificativo.familiar,
        explicacion: 'Aviso',
        respaldo: ArchivoAdjunto(nombre: 'aviso.png', bytes: Uint8List(3)),
      );
      expect(r.error, 'Ya hay un justificativo pendiente para esa clase.');
      expect(pedidos.last.method, 'DELETE');
      expect(pedidos.last.body, contains('insc-2/clase-3/1731700000000_aviso.png'));
    });

    test('un respaldo no admitido no se sube (US-36 escenario 3)', () async {
      final repo = SupabaseJustificativosRepository(cliente((_) => ok({})));
      final r = await repo.registrar(
        claseId: 'clase-3',
        inscripcionId: 'insc-2',
        motivo: MotivoJustificativo.otro,
        explicacion: 'x',
        respaldo: ArchivoAdjunto(nombre: 'virus.exe', bytes: Uint8List(3)),
      );
      expect(r.error, contains('PDF, PNG o JPG'));
      expect(pedidos, isEmpty);
    });

    test('la tutora recibe el 403 de la base al intentar resolver (US-38 escenario 3)', () async {
      final repo = SupabaseJustificativosRepository(
        cliente((_) => error(403, '42501', 'Solo el Equipo de Gestión de la sede resuelve justificativos.')),
      );
      final r = await repo.resolver('just-1', aprobar: true);
      expect(r.error, 'Solo el Equipo de Gestión de la sede resuelve justificativos.');
      expect(jsonDecode(pedidos.single.body), {'p_id': 'just-1', 'p_aprobar': true, 'p_observacion': null});
    });

    test('al eliminar, borra el respaldo que devuelve la base', () async {
      final repo = SupabaseJustificativosRepository(
        cliente((r) => r.url.path.startsWith('/storage') ? ok([]) : ok('insc-1/clase-3/constancia.pdf')),
      );
      final r = await repo.eliminar('just-1');
      expect(r.ok, isTrue);
      expect(pedidos.first.url.path, '/rest/v1/rpc/eliminar_justificativo');
      expect(pedidos.last.method, 'DELETE');
      expect(pedidos.last.body, contains('insc-1/clase-3/constancia.pdf'));
    });

    test('un error inesperado se informa con un mensaje genérico', () async {
      final repo = SupabaseJustificativosRepository(cliente((_) => error(500, 'XX000', 'internal')));
      final r = await repo.resolver('just-1', aprobar: false, observacion: 'x');
      expect(r.error, startsWith('No pudimos guardar'));
    });

    test('el respaldo se abre con una URL firmada de un minuto (US-17 escenario 1)', () async {
      final repo = SupabaseJustificativosRepository(
        cliente((_) => ok({'signedURL': '/object/sign/justificativos/insc-1/clase-3/c.pdf?token=t'})),
      );
      final r = await repo.urlRespaldo('insc-1/clase-3/c.pdf');
      expect(pedidos.single.url.path, '/storage/v1/object/sign/justificativos/insc-1/clase-3/c.pdf');
      expect(jsonDecode(pedidos.single.body), {'expiresIn': 60});
      expect(r.valor, contains('token=t'));
    });

    test('las clases para justificar vienen de su RPC', () async {
      final repo = SupabaseJustificativosRepository(
        cliente(
          (_) => ok([
            {'clase_id': 'c', 'inscripcion_id': 'i', 'numero_sesion': 1, 'fecha': '2026-11-21', 'curso_nombre': 'PCB'},
          ]),
        ),
      );
      final clases = await repo.clasesParaJustificar();
      expect(clases.single.asistencia, EstadoAsistencia.pendiente);
      expect(pedidos.single.url.path, '/rest/v1/rpc/clases_para_justificar');
    });
  });

  group('SupabaseEvidenciasRepository', () {
    final filaFoto = {
      'id': 'foto-1',
      'clase_id': 'clase-4',
      'archivo_url': 'clase-4/1731700000000.jpg',
      'tamano_bytes': 812345,
      'apta_para_evidencia': true,
      'rostros_censurados': true,
      'declaracion_consentimiento_completo': false,
      'subida_en': '2026-11-21T14:00:00+00:00',
      'perfiles': {'nombres': 'Daniela', 'apellidos': 'Valenzuela'},
    };

    test('sube la foto comprimida y la registra con su aptitud (US-18, US-19)', () async {
      final repo = SupabaseEvidenciasRepository(
        cliente((r) => r.url.path.startsWith('/storage') ? ok({'Key': 'evidencias/x'}) : ok(filaFoto)),
        ahora: () => ahora,
      );
      final r = await repo.subir(claseId: 'clase-4', jpeg: Uint8List(10), apta: true, rostrosCensurados: true);
      expect(pedidos.first.url.path, '/storage/v1/object/evidencias/clase-4/1731700000000.jpg');
      expect(pedidos.first.body, contains('image/jpeg'));
      expect(pedidos.last.url.path, '/rest/v1/evidencias_fotograficas');
      expect(jsonDecode(pedidos.last.body), {
        'clase_id': 'clase-4',
        'archivo_url': 'clase-4/1731700000000.jpg',
        'apta_para_evidencia': true,
        'rostros_censurados': true,
      });
      expect(r.valor!.pesoEtiqueta, '812 KB');
      expect(r.valor!.subidaPor, 'Daniela Valenzuela');
    });

    test('si la base rechaza la foto, se borra del bucket y se informa el motivo', () async {
      final repo = SupabaseEvidenciasRepository(
        cliente(
          (r) => r.url.path.startsWith('/storage')
              ? ok(r.method == 'DELETE' ? [] : {'Key': 'evidencias/x'})
              : error(
                  400,
                  '22023',
                  'Para marcarla apta, confirma que las alumnas sin autorización no son reconocibles.',
                ),
        ),
        ahora: () => ahora,
      );
      final r = await repo.subir(claseId: 'clase-4', jpeg: Uint8List(10), apta: true, rostrosCensurados: false);
      expect(r.error, startsWith('Para marcarla apta'));
      expect(pedidos.last.method, 'DELETE');
    });

    test('un 403 del bucket se informa como falta de permiso', () async {
      final repo = SupabaseEvidenciasRepository(
        cliente(
          (_) => http.Response(
            jsonEncode({
              'statusCode': '403',
              'error': 'Unauthorized',
              'message': 'new row violates row-level security policy',
            }),
            403,
            headers: json,
          ),
        ),
      );
      final r = await repo.subir(claseId: 'clase-4', jpeg: Uint8List(10), apta: false, rostrosCensurados: false);
      expect(r.error, 'No tienes permiso para subir fotos a esta clase.');
    });

    test('las fotos de la clase traen su URL firmada', () async {
      final repo = SupabaseEvidenciasRepository(
        cliente(
          (r) => r.url.path.startsWith('/storage')
              ? ok([
                  {
                    'path': 'clase-4/1731700000000.jpg',
                    'signedURL': '/object/sign/evidencias/clase-4/1731700000000.jpg?token=t',
                  },
                ])
              : ok([filaFoto]),
        ),
      );
      final fotos = await repo.fotos('clase-4');
      expect(fotos.single.url, contains('token=t'));
      expect(fotos.single.apta, isTrue);
      expect(pedidos.first.url.queryParameters['clase_id'], 'eq.clase-4');
    });

    test('las evidencias pendientes vienen de su vista (US-20)', () async {
      final repo = SupabaseEvidenciasRepository(
        cliente(
          (_) => ok([
            {
              'clase_id': 'clase-2',
              'curso_nombre': 'PCB',
              'sede_nombre': 'Sede Beauchef',
              'seccion': 1,
              'numero_sesion': 2,
              'fecha': '2026-11-07',
              'clase_tema': 'Condicionales',
              'horas_sin_foto': 50,
              'tutoras': 'Daniela Valenzuela',
            },
          ]),
        ),
      );
      final p = (await repo.pendientes()).single;
      expect(p.claseEtiqueta, 'Clase #2 · 07/11/2026');
      expect(p.demora, 'Hace 2 días');
      expect(pedidos.single.url.path, '/rest/v1/evidencias_pendientes');
    });

    test('el peso se muestra en KB o MB', () {
      expect(pesoLegible(812345), '812 KB');
      expect(pesoLegible(1450000), '1,4 MB');
    });
  });

  group('Compresión de la foto en el dispositivo (US-18 escenario 2, TC-12)', () {
    test('una foto de varios MB queda en JPEG de menos de 1,5 MB y a lo más 1920 px', () {
      // Ruido: casi no se comprime, como una foto real de mucho detalle
      final azar = Random(7);
      final original = img.Image(width: 3000, height: 2000);
      for (final p in original) {
        p
          ..r = azar.nextInt(256)
          ..g = azar.nextInt(256)
          ..b = azar.nextInt(256);
      }
      final pesada = img.encodePng(original, level: 0);
      expect(pesada.length, greaterThan(5 * 1000 * 1000));

      final comprimida = comprimirConImage(pesada)!;
      expect(comprimida.length, lessThan(pesoMaximoFoto));
      final leida = img.decodeJpg(comprimida)!;
      expect(max(leida.width, leida.height), lessThanOrEqualTo(ladoMaximoFoto));
      expect(leida.width / leida.height, closeTo(1.5, 0.01));
    });

    test('un archivo que no es imagen no se comprime', () {
      expect(comprimirConImage(Uint8List.fromList(utf8.encode('no soy una foto'))), isNull);
    });

    test('los tamaños se reducen de a 25 % hasta el mínimo', () {
      expect(ladosCompresion().take(3), [1920, 1440, 1080]);
      expect(ladosCompresion().last, greaterThanOrEqualTo(480));
    });
  });

  group('Precarga de justificadas en el pase de lista (US-16 escenario 2, US-38)', () {
    test('con un justificativo aprobado la alumna parte justificada y bloqueada', () async {
      final clase = FakeClaseRepository();
      addTearDown(clase.cerrar);
      clase.fijarJustificativo('clase-4', 'insc-2', EstadoJustificativo.aceptado, motivo: MotivoJustificativo.familiar);
      clase.fijarJustificativo('clase-4', 'insc-3', EstadoJustificativo.pendiente);
      final controller = ClaseSesionController(repository: clase, hoy: () => clase.hoy);
      addTearDown(controller.dispose);
      await controller.cargar();

      final porId = {for (final r in controller.registros) r.id: r};
      expect(porId['insc-1']!.estado, EstadoAsistencia.presente);
      expect(porId['insc-2']!.estado, EstadoAsistencia.justificada);
      expect(porId['insc-2']!.motivoJustificativo, MotivoJustificativo.familiar);
      expect(porId['insc-3']!.estado, EstadoAsistencia.presente);
      expect(porId['insc-3']!.justificativo, EstadoJustificativo.pendiente);
      final indice = controller.registros.indexWhere((r) => r.id == 'insc-2');
      expect(controller.ciclarEstado(indice), isFalse);
    });

    test('la nube mantiene justificada a la alumna aunque la lista la traiga presente', () async {
      final clase = FakeClaseRepository();
      addTearDown(clase.cerrar);
      clase.fijarJustificativo('clase-4', 'insc-1', EstadoJustificativo.aceptado);
      final lista = (await clase.lista('clase-4')).registros;
      final r = await clase.guardarAsistencia('clase-4', [
        for (final x in lista) x.copyWith(estado: EstadoAsistencia.presente),
      ]);
      expect(r.mensaje, contains('1 inasistencia justificada se mantiene'));
      expect(clase.estadoAlumna('clase-4', 'insc-1'), EstadoAsistencia.justificada);
    });

    test('el pase de lista mapea el estado y el motivo del justificativo', () {
      final lista = MapeoClase.lista('clase-1', [
        {
          'inscripcion_id': 'insc-1',
          'alumna_id': 'a-1',
          'nombres': 'Ana',
          'apellidos': 'Uno',
          'rut': '1-9',
          'autoriza_imagen': true,
          'estado': null,
          'justificativo_estado': 'aceptado',
          'justificativo_motivo': 'escolar',
        },
      ]);
      final r = lista.registros.single;
      expect(r.justificadaPorAdelantado, isTrue);
      expect(r.motivoJustificativo!.label, 'Académico / Pruebas');
      expect(lista.tienePaseLista, isFalse, reason: 'el justificativo no es un pase de lista');
      expect(precargarRegistro(r).estado, EstadoAsistencia.justificada);
    });
  });
}
