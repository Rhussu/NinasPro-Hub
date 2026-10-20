import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/utils/rut.dart';

/// Operaciones de la Directiva Nacional sobre el mock (US-01, 02, 07-10, 12, 21, 22, 24, 30-32, 43)
void main() {
  late MockHubRepository repository;

  setUp(() {
    repository = MockHubRepository();
  });

  group('RUT chileno (US-08)', () {
    test('valida el dígito verificador con módulo 11', () {
      expect(validarRut('22.341.890-2'), isTrue);
      expect(validarRut('21.998.765-k'), isTrue);
      expect(validarRut('22341890-1'), isFalse);
      expect(validarRut('abc'), isFalse);
      expect(formatearRut('219987651'), '21.998.765-1');
      expect(normalizarRut('21.998.765-k'), '21998765K');
    });
  });

  group('Sedes y catálogo (US-01)', () {
    test('crea sedes y rechaza nombres repetidos', () async {
      final ok = await repository.crearSede(
        nombre: 'Sede Concepción',
        universidad: 'Universidad de Concepción',
        region: 'Biobío',
        modalidad: 'Presencial',
        coordinadoraNombre: 'Ana Torres',
      );
      expect(ok, isTrue);
      expect((await repository.getSedes()).length, 4);

      final repetida = await repository.crearSede(
        nombre: ' sede concepción ',
        universidad: 'Otra',
        region: 'Biobío',
        modalidad: 'Online',
        coordinadoraNombre: 'X',
      );
      expect(repetida, isFalse);
    });

    test('renombrar una sede actualiza sus alumnas y cursos', () async {
      final sede = (await repository.getSedes()).firstWhere((s) => s.id == 'sede-valparaiso');
      final ok = await repository.actualizarSede(sede.copyWith(nombre: 'Sede Viña del Mar'));
      expect(ok, isTrue);
      final alumnas = await repository.getAlumnas(sedeId: 'sede-valparaiso');
      expect(alumnas.every((a) => a.sedeNombre == 'Sede Viña del Mar'), isTrue);

      final choque = await repository.actualizarSede(sede.copyWith(nombre: 'Sede Beauchef'));
      expect(choque, isFalse);
    });

    test('el código del catálogo es único y el nombre obligatorio', () async {
      expect(await repository.crearCursoCatalogo(codigo: 'IA', nombre: 'Introducción a la IA'), isTrue);
      expect(await repository.crearCursoCatalogo(codigo: 'pcb', nombre: 'Duplicado'), isFalse);
      expect(await repository.crearCursoCatalogo(codigo: 'NUEVO', nombre: '  '), isFalse);
      expect((await repository.getCatalogoCursos()).length, 4);
    });
  });

  group('Instancias de curso (US-02)', () {
    test('genera 18 sesiones sabatinas entre el 1 de agosto y el 28 de noviembre', () async {
      final curso = await repository.crearInstanciaCurso(
        catalogoId: 'cat-pcb',
        sedeId: 'sede-beauchef',
        inicio: DateTime(2026, 8, 1),
        termino: DateTime(2026, 11, 28),
        diaSemana: DateTime.saturday,
      );
      expect(curso, isNotNull);
      expect(curso!.semestre, 2);
      final sesiones = await repository.getSesiones(cursoId: curso.id);
      expect(sesiones.length, 18);
      expect(sesiones.every((s) => s.estado == 'programada' && s.fecha.weekday == DateTime.saturday), isTrue);
      expect(sesiones.last.numeroSesion, 18);

      expect(
        await repository.existeInstancia(catalogoId: 'cat-pcb', sedeId: 'sede-beauchef', anio: 2026, semestre: 2),
        isTrue,
      );
    });

    test('rechaza un término anterior o igual al inicio', () async {
      final curso = await repository.crearInstanciaCurso(
        catalogoId: 'cat-pcb',
        sedeId: 'sede-beauchef',
        inicio: DateTime(2026, 8, 1),
        termino: DateTime(2026, 8, 1),
        diaSemana: DateTime.saturday,
      );
      expect(curso, isNull);
    });
  });

  group('Alumnas (US-07, US-08, US-09)', () {
    test('la previsualización separa filas nuevas, existentes e inválidas', () async {
      final resultado = await repository.previsualizarImportacionAlumnas(cursoId: 'curso-pcb-sj');
      expect(resultado.errorColumnas, isNull);
      expect(resultado.contar(EstadoFilaImportacion.nueva), 3);
      expect(resultado.contar(EstadoFilaImportacion.existente), 1);
      expect(resultado.contar(EstadoFilaImportacion.invalida), 3);
      expect(resultado.filas.any((f) => (f.motivo ?? '').contains('dígito verificador')), isTrue);
      expect(resultado.filas.any((f) => (f.motivo ?? '').contains('repetido')), isTrue);
      expect(resultado.filas.any((f) => (f.motivo ?? '').contains('apoderado')), isTrue);

      final malas = await repository.previsualizarImportacionAlumnas(
        cursoId: 'curso-pcb-sj',
        columnasValidas: false,
      );
      expect(malas.errorColumnas, isNotNull);
      expect(malas.filas, isEmpty);
    });

    test('confirmar la carga deja preinscritas y reutiliza la ficha por RUT', () async {
      final antes = (await repository.getAlumnas()).length;
      final inscritas = await repository.confirmarImportacionAlumnas(cursoId: 'curso-pcb-sj');
      expect(inscritas, 4);
      final alumnas = await repository.getAlumnas();
      expect(alumnas.length, antes + 3);

      final renata = alumnas.firstWhere((a) => a.id == 'alumna-12');
      expect(renata.estado, 'preinscrita');
      expect(renata.historialInscripciones, isNotEmpty);
      expect(alumnas.any((a) => a.nombre == 'Antonia Núñez Ríos'), isTrue);
    });

    test('inscripción individual valida el RUT', () async {
      final invalida = await repository.inscribirAlumna(
        cursoId: 'curso-web-valpo',
        nombre: 'Prueba',
        rut: '11.111.111-2',
        apoderadoNombre: 'A',
        apoderadoTelefono: '+56 9 1',
        apoderadoCorreo: 'a@b.cl',
      );
      expect(invalida, isFalse);

      final ok = await repository.inscribirAlumna(
        cursoId: 'curso-web-valpo',
        nombre: 'Laura Díaz',
        rut: '23.012.345-4',
        apoderadoNombre: 'Pedro Díaz',
        apoderadoTelefono: '+56 9 7000 0000',
        apoderadoCorreo: 'pedro@correo.cl',
      );
      expect(ok, isTrue);
      final alumnas = await repository.getAlumnas(cursoId: 'curso-web-valpo');
      expect(alumnas.any((a) => a.nombre == 'Laura Díaz' && a.estado == 'preinscrita'), isTrue);
    });
  });

  group('Autorizaciones (US-10, US-12)', () {
    test('un canal sin respuesta queda como no autorizado', () {
      const autorizaciones = AutorizacionesAlumna(
        tratamientoDatos: true,
        canales: {CanalImagen.prensa: EstadoAutorizacion.otorgada},
      );
      expect(autorizaciones.estado(CanalImagen.redesSociales), EstadoAutorizacion.noAutorizada);
      expect(autorizaciones.permiteFotos, isTrue);
    });

    test('revocar todos los canales quita la aptitud para fotos desde esa fecha', () async {
      final ok = await repository.revocarAutorizacionImagen(
        alumnaId: 'alumna-1',
        canales: CanalImagen.values,
        fecha: DateTime(2026, 5, 1),
        motivo: 'Solicitud de la apoderada',
      );
      expect(ok, isTrue);
      final alumna = await repository.getAlumnaById('alumna-1');
      expect(alumna!.autorizaFoto, isFalse);
      expect(alumna.autorizaciones.estado(CanalImagen.prensa), EstadoAutorizacion.revocada);

      // Clases anteriores a la revocación no cambian; las posteriores sí
      final antes = await repository.getAsistenciaSesion(sesionId: 'sesion-4');
      expect(antes.firstWhere((r) => r.alumnaId == 'alumna-1').autorizaImagen, isTrue);
      final despues = await repository.getAsistenciaSesion(sesionId: 'sesion-5');
      expect(despues.firstWhere((r) => r.alumnaId == 'alumna-1').autorizaImagen, isFalse);
    });
  });

  group('Voluntariado (US-30, US-31, US-32)', () {
    test('no se asigna a un curso sin la declaración de adhesión', () async {
      expect(await repository.asignarVoluntariaACurso(tutoraId: 'tutora-12', cursoId: 'curso-web-valpo'), isFalse);

      final tutora = (await repository.getTutoras()).firstWhere((t) => t.id == 'tutora-12');
      await repository.actualizarVoluntaria(
        tutora.copyWith(adhesionFirmada: true, fechaFirmaAdhesion: DateTime(2026, 4, 1)),
      );
      expect(await repository.asignarVoluntariaACurso(tutoraId: 'tutora-12', cursoId: 'curso-web-valpo'), isTrue);
    });

    test('la fecha de salida no puede ser anterior al ingreso', () async {
      final tutora = (await repository.getTutoras()).firstWhere((t) => t.id == 'tutora-5');
      final invalida = await repository.actualizarVoluntaria(
        tutora.copyWith(estado: 'retirada', fechaSalida: DateTime(2000, 1, 1)),
      );
      expect(invalida, isFalse);
      final valida = await repository.actualizarVoluntaria(
        tutora.copyWith(estado: 'retirada', fechaSalida: DateTime(2026, 6, 30)),
      );
      expect(valida, isTrue);
    });

    test('la carga masiva crea solo las fichas nuevas y válidas', () async {
      final resultado = await repository.previsualizarImportacionVoluntariado();
      expect(resultado.contar(EstadoFilaImportacion.invalida), 2);
      expect(resultado.contar(EstadoFilaImportacion.existente), 1);
      final creadas = await repository.confirmarImportacionVoluntariado(sedeId: 'sede-valparaiso');
      expect(creadas, 5);
      expect((await repository.getTutoras(sedeId: 'sede-valparaiso')).length, 7);
    });
  });

  group('Exportación y auditoría (US-21, US-22, US-24)', () {
    test('la exportación disociada reemplaza nombres y RUT y queda auditada', () async {
      const filtro = FiltroExportacion(
        tipo: TipoExportacion.asistencia,
        sedeId: 'sede-beauchef',
        disociado: true,
      );
      final vista = await repository.previsualizarExportacion(filtro);
      expect(vista.filas, isNotEmpty);
      expect(vista.filas.every((f) => f[0].startsWith('ALUMNA-') && f[1] == '—'), isTrue);
      // 8 alumnas x 8 clases realizadas
      expect(vista.filas.length, 64);

      final antes = await repository.getEventosAuditoria(tipo: TipoAccionAuditoria.exportacion);
      await repository.exportarDatos(filtro);
      final despues = await repository.getEventosAuditoria(tipo: TipoAccionAuditoria.exportacion);
      expect(despues.length, antes.length + 1);
      expect(despues.first.descripcion, contains('disociada'));
    });

    test('un filtro sin datos solo trae encabezados', () async {
      final vista = await repository.previsualizarExportacion(
        FiltroExportacion(tipo: TipoExportacion.asistencia, desde: DateTime(2030, 1, 1)),
      );
      expect(vista.encabezados, isNotEmpty);
      expect(vista.filas, isEmpty);
    });

    test('filtra la bitácora por RUT de alumna, usuaria y fechas', () async {
      final porRut = await repository.getEventosAuditoria(rutAlumna: '22890634-4');
      expect(porRut.length, 2);

      final porCorreo = await repository.getEventosAuditoria(usuaria: 'paula.gutierrez');
      expect(porCorreo.every((e) => e.usuariaNombre.startsWith('Paula')), isTrue);
      expect(porCorreo, isNotEmpty);

      final porFecha = await repository.getEventosAuditoria(
        desde: DateTime(2026, 4, 25),
        hasta: DateTime(2026, 4, 25),
      );
      expect(porFecha.length, 1);
    });
  });

  group('Roles de tutoras (US-43)', () {
    test('eliminar un rol quita también sus asignaciones', () async {
      expect(await repository.contarAsignacionesRol('inventario'), greaterThan(0));
      expect(await repository.eliminarRolTutora('inventario'), isTrue);
      expect((await repository.getRolesTutora()).any((r) => r.codigo == 'inventario'), isFalse);
      expect(await repository.contarAsignacionesRol('inventario'), 0);
    });
  });

  test('la asistencia por clase agrupa por sede y fecha de clases realizadas', () async {
    final series = await repository.getAsistenciaPorClase();
    final beauchef = series.firstWhere((s) => s.sedeId == 'sede-beauchef');
    expect(beauchef.puntos.length, 8);
    // Clase 1: las 8 alumnas presentes
    expect(beauchef.puntos.first.porcentaje, 100);
    expect(beauchef.puntos.first.fecha, DateTime(2026, 4, 4));
    final sj = series.firstWhere((s) => s.sedeId == 'sede-san-joaquin');
    expect(sj.puntos.length, 4);
  });

  test('el resumen por sede cuenta solo los datos de cada sede', () async {
    final resumen = await repository.getResumenSedes();
    final beauchef = resumen.firstWhere((r) => r.sede.id == 'sede-beauchef');
    expect(beauchef.alumnasActivas, 8);
    expect(beauchef.voluntariasActivas, 8);
    final sj = resumen.firstWhere((r) => r.sede.id == 'sede-san-joaquin');
    expect(sj.alumnasActivas, 3);
    expect(sj.cursos, 1);
  });
}
