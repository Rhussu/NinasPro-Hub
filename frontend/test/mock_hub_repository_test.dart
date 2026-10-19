import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';

void main() {
  group('MockHubRepository Tests', () {
    late MockHubRepository repository;

    setUp(() {
      repository = MockHubRepository();
    });

    test('getSedes returns initial list of 4 sedes', () async {
      final sedes = await repository.getSedes();
      expect(sedes.length, 4);
      expect(sedes.any((s) => s.nombre.contains('Santiago')), isTrue);
      expect(sedes.any((s) => s.modalidad == 'Online'), isTrue);
    });

    test('getCursos filters by sedeId correctly', () async {
      final allCursos = await repository.getCursos();
      expect(allCursos.isNotEmpty, isTrue);

      final cursosStgo = await repository.getCursos(sedeId: 'sede-santiago');
      expect(cursosStgo.length, 1);
      expect(cursosStgo.first.codigo, contains('STGO'));
    });

    test('getAlumnas filters by cursoId and sedeId', () async {
      final allAlumnas = await repository.getAlumnas();
      expect(allAlumnas.length, 8);

      final alumnasStgo = await repository.getAlumnas(sedeId: 'sede-santiago');
      expect(alumnasStgo.length, 8);

      final alumna = await repository.getAlumnaById('alumna-1');
      expect(alumna, isNotNull);
      expect(alumna!.nombre, 'Valentina');

      final inexistente = await repository.getAlumnaById('id-no-existe');
      expect(inexistente, isNull);
    });

    test('registrarRetiroAlumna updates student state (US-09)', () async {
      final ok = await repository.registrarRetiroAlumna(
        alumnaId: 'alumna-4',
        motivo: 'Tope horario escolar',
      );
      expect(ok, isTrue);

      final alumna = await repository.getAlumnaById('alumna-4');
      expect(alumna!.retirado, isTrue);
      expect(alumna.estadoMatricula, 'Retirada');
      expect(alumna.motivoRetiro, 'Tope horario escolar');

      final fallo = await repository.registrarRetiroAlumna(
        alumnaId: 'id-falso',
        motivo: 'prueba',
      );
      expect(fallo, isFalse);
    });

    test('getSesiones returns sessions for given course', () async {
      final sesiones = await repository.getSesiones(cursoId: 'curso-pcb-stgo');
      expect(sesiones.length, 6);
      expect(sesiones.any((s) => s.numeroSesion == 4), isTrue);
    });

    test('getAsistenciaSesion and guardarAsistencia update in-memory state and recalculates attendance (US-13)', () async {
      final initial = await repository.getAsistenciaSesion(sesionId: 'sesion-4');
      expect(initial.length, 8);

      // Modify attendance: mark alumna-1 as absent
      final modified = initial.map((r) {
        if (r.alumnaId == 'alumna-1') {
          return r.copyWith(estado: EstadoAsistencia.ausente);
        }
        return r;
      }).toList();

      final guardado = await repository.guardarAsistencia(
        sesionId: 'sesion-4',
        registros: modified,
      );
      expect(guardado, isTrue);

      final actualizadas = await repository.getAsistenciaSesion(sesionId: 'sesion-4');
      final reg1 = actualizadas.firstWhere((r) => r.alumnaId == 'alumna-1');
      expect(reg1.estado, EstadoAsistencia.ausente);

      // Session should now be marked as realizada
      final sesiones = await repository.getSesiones(cursoId: 'curso-pcb-stgo');
      final s4 = sesiones.firstWhere((s) => s.id == 'sesion-4');
      expect(s4.estado, 'realizada');
    });

    test('guardarParticipacion and getParticipacionSesion (US-28)', () async {
      final nuevaPart = [
        const ParticipacionClase(
          id: 'part-test',
          sesionId: 'sesion-4',
          alumnaId: 'alumna-1',
          alumnaNombre: 'Valentina Soto',
          ejerciciosResueltos: 5,
          participacionActiva: true,
          podioKahoot: 1,
        ),
      ];

      final ok = await repository.guardarParticipacion(
        sesionId: 'sesion-4',
        participaciones: nuevaPart,
      );
      expect(ok, isTrue);

      final parts = await repository.getParticipacionSesion(sesionId: 'sesion-4');
      expect(parts.length, 1);
      expect(parts.first.ejerciciosResueltos, 5);
    });

    test('atenderAlertaDesercion resolves alert (US-40)', () async {
      final alertas = await repository.getAlertasDesercion();
      expect(alertas.isNotEmpty, isTrue);
      expect(alertas.first.atendida, isFalse);

      final ok = await repository.atenderAlertaDesercion(
        alertaId: alertas.first.id,
        observacion: 'Contacto preventivo realizado con apoderado.',
      );
      expect(ok, isTrue);

      final resueltas = await repository.getAlertasDesercion();
      expect(resueltas.first.atendida, isTrue);
      expect(resueltas.first.observacionGestion, contains('Contacto preventivo'));

      final fallo = await repository.atenderAlertaDesercion(
        alertaId: 'id-falso',
        observacion: 'test',
      );
      expect(fallo, isFalse);
    });

    test('resolverJustificativo approves or rejects (US-37)', () async {
      final justs = await repository.getJustificativos();
      expect(justs.isNotEmpty, isTrue);

      final ok = await repository.resolverJustificativo(
        justificativoId: justs.first.id,
        nuevoEstado: 'aprobado',
      );
      expect(ok, isTrue);

      final actualizados = await repository.getJustificativos();
      expect(actualizados.first.estado, 'aprobado');

      final fallo = await repository.resolverJustificativo(
        justificativoId: 'invalido',
        nuevoEstado: 'rechazado',
      );
      expect(fallo, isFalse);
    });

    test('getPortalAlumnaData and enviarJustificativo (US-25, US-35)', () async {
      final portalData = await repository.getPortalAlumnaData(alumnaId: 'alumna-1');
      expect(portalData.alumna.nombre, 'Valentina');
      expect(portalData.curso.id, 'curso-pcb-stgo');
      expect(portalData.sesiones.isNotEmpty, isTrue);

      final enviado = await repository.enviarJustificativo(
        alumnaId: 'alumna-1',
        sesionId: 'sesion-4',
        motivoTipificado: 'Salud',
        detalle: 'Reposo médico certificado',
      );
      expect(enviado, isTrue);

      final updatedData = await repository.getPortalAlumnaData(alumnaId: 'alumna-1');
      expect(updatedData.justificativos.any((j) => j.motivoTipificado == 'Salud'), isTrue);

      final envioInvalido = await repository.enviarJustificativo(
        alumnaId: 'alumna-no-existe',
        sesionId: 'sesion-1',
        motivoTipificado: 'Otro',
        detalle: 'prueba',
      );
      expect(envioInvalido, isFalse);
    });

    test('getTutoras and actualizarAsistenciaTutora (US-30, US-33)', () async {
      final tutoras = await repository.getTutoras();
      expect(tutoras.length, 4);

      final ok = await repository.actualizarAsistenciaTutora(
        tutoraId: 'tutora-1',
        presente: false,
      );
      expect(ok, isTrue);

      final updated = await repository.getTutoras();
      expect(updated.firstWhere((t) => t.id == 'tutora-1').presenteClaseActual, isFalse);

      final fallo = await repository.actualizarAsistenciaTutora(
        tutoraId: 'tutora-falsa',
        presente: true,
      );
      expect(fallo, isFalse);
    });
  });
}
