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

    test('getSedes returns list of sedes', () async {
      final sedes = await repository.getSedes();
      expect(sedes.length, 3);
      expect(sedes.any((s) => s.nombre.contains('Beauchef')), isTrue);
    });

    test('getCursos filters by sedeId correctly', () async {
      final allCursos = await repository.getCursos();
      expect(allCursos.isNotEmpty, isTrue);

      final cursosStgo = await repository.getCursos(sedeId: 'sede-beauchef');
      expect(cursosStgo.length, 1);
      expect(cursosStgo.first.codigo, contains('PCB'));
    });

    test('getAlumnas filters by cursoId and sedeId', () async {
      final allAlumnas = await repository.getAlumnas();
      expect(allAlumnas.length, 8);

      final alumnasStgo = await repository.getAlumnas(sedeId: 'sede-beauchef');
      expect(alumnasStgo.length, 8);

      final alumna = await repository.getAlumnaById('alumna-1');
      expect(alumna, isNotNull);
      expect(alumna!.nombre, 'Valentina Soto Morales');

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
      expect(alumna!.estado, 'retirada');
      expect(alumna.motivoRetiro, 'Tope horario escolar');

      final fallo = await repository.registrarRetiroAlumna(
        alumnaId: 'id-falso',
        motivo: 'prueba',
      );
      expect(fallo, isFalse);
    });

    test('getSesiones returns sessions for given course with resources (US-26)', () async {
      final sesiones = await repository.getSesiones(cursoId: 'curso-pcb-stgo');
      expect(sesiones.length, 10);
      expect(sesiones.any((s) => s.numeroSesion == 4), isTrue);

      // Verify educational resources in session
      final s1 = sesiones.firstWhere((s) => s.numeroSesion == 1);
      expect(s1.recursos.isNotEmpty, isTrue);
      expect(s1.recursos.any((r) => r.url.startsWith('https://')), isTrue);
    });

    test('getAsistenciaSesion and guardarAsistencia update state (US-13)', () async {
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
    });

    test('guardarParticipacion and getParticipacionSesion (US-28)', () async {
      final nuevaPart = [
        const ParticipacionClase(
          id: 'part-test',
          sesionId: 'sesion-4',
          alumnaId: 'alumna-1',
          alumnaNombre: 'Valentina Soto Morales',
          ejerciciosResueltos: 5,
          participacionActiva: true,
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

    test('guardarPodioKahoot registers podium (US-29)', () async {
      final ok = await repository.guardarPodioKahoot(
        sesionId: 'sesion-4',
        primerLugarAlumnaId: 'alumna-1',
        segundoLugarAlumnaId: 'alumna-2',
        tercerLugarAlumnaId: 'alumna-3',
      );
      expect(ok, isTrue);

      final sesiones = await repository.getSesiones(cursoId: 'curso-pcb-stgo');
      final s4 = sesiones.firstWhere((s) => s.id == 'sesion-4');
      expect(s4.podioKahoot, isNotNull);
      expect(s4.podioKahoot!.primerLugarAlumnaId, 'alumna-1');
    });

    test('contactarAlerta marks alert as contacted (US-39, US-40)', () async {
      final alertas = await repository.getAlertasDesercion();
      expect(alertas.isNotEmpty, isTrue);
      expect(alertas.first.estado, 'activa');

      final ok = await repository.contactarAlerta(
        alertaId: alertas.first.id,
        observacionesContacto: 'Contacto preventivo realizado con apoderada vía WhatsApp.',
      );
      expect(ok, isTrue);

      final resueltas = await repository.getAlertasDesercion();
      expect(resueltas.first.estado, 'contactada');
      expect(resueltas.first.observacionesContacto, contains('preventivo'));

      final fallo = await repository.contactarAlerta(
        alertaId: 'id-falso',
        observacionesContacto: 'test',
      );
      expect(fallo, isFalse);
    });

    test('resolverJustificativo approves or rejects (US-37)', () async {
      final justs = await repository.getJustificativos();
      expect(justs.isNotEmpty, isTrue);

      final ok = await repository.resolverJustificativo(
        justificativoId: justs.first.id,
        aprobado: true,
        observaciones: 'Certificado validado por gestión',
      );
      expect(ok, isTrue);

      final actualizados = await repository.getJustificativos();
      expect(actualizados.first.estado, 'aprobado');

      final fallo = await repository.resolverJustificativo(
        justificativoId: 'invalido',
        aprobado: false,
      );
      expect(fallo, isFalse);
    });

    test('getPortalAlumnaData, podios and exercise recovery (US-25, US-26, US-29, US-35)', () async {
      final portalData = await repository.getPortalAlumnaData(alumnaId: 'alumna-1');
      expect(portalData.alumna.nombre, 'Valentina Soto Morales');
      expect(portalData.curso.id, 'curso-pcb-stgo');
      expect(portalData.sesiones.isNotEmpty, isTrue);
      expect(portalData.podiosPrimerLugar, greaterThanOrEqualTo(0));
      expect(portalData.totalEjerciciosResueltos, greaterThan(0));
      expect(portalData.umbralAprobacion, isIn([70.0, 80.0]));

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

    test('getTutoras, esEquipoGestion and actualizarAsistenciaTutora (US-33)', () async {
      final tutoras = await repository.getTutoras();
      expect(tutoras.length, 4);
      expect(tutoras.any((t) => t.esEquipoGestion), isTrue);

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

    test('roles dinámicos y asignación semanal (US-43)', () async {
      final roles = await repository.getRolesTutora();
      expect(roles.isNotEmpty, isTrue);
      expect(roles.any((r) => r.codigo == 'facilitadora'), isTrue);

      // Crear nuevo rol
      final nuevoRol = const RolTutorConfig(
        codigo: 'dinamica_pausa',
        nombre: 'Encargada de Pausas Activas',
        descripcion: 'Lidera dinámicas de relajación y energización',
        colorHex: '#FF7300',
        esRequerido: false,
      );
      final creado = await repository.crearRolTutora(nuevoRol);
      expect(creado, isTrue);

      final rolesActualizados = await repository.getRolesTutora();
      expect(rolesActualizados.any((r) => r.codigo == 'dinamica_pausa'), isTrue);

      // Asignar rol semanal
      final asignado = await repository.asignarRolSemanal(
        tutoraId: 'tutora-2',
        semanaNumero: 4,
        rolCodigo: 'dinamica_pausa',
      );
      expect(asignado, isTrue);

      final asignaciones = await repository.getAsignacionesSemanales(semanaNumero: 4);
      expect(asignaciones.any((a) => a.tutoraId == 'tutora-2' && a.rolCodigo == 'dinamica_pausa'), isTrue);
    });
  });
}
