import 'package:ninas_pro_hub/repositories/portal_repository.dart';

/// [PortalRepository] en memoria con el portal de Valentina, alineado con el
/// curso del [FakeClaseRepository]: 10 sesiones, la 4 es hoy y en las 1 a 3
/// fue presente, presente y ausente.
class FakePortalRepository implements PortalRepository {
  PortalAlumna? valor;

  /// Si no es null, la base rechaza el portal con este mensaje
  String? rechazo;

  /// Si es true, falla la conexión
  bool sinConexion = false;

  var consultas = 0;

  FakePortalRepository({this.valor, this.rechazo});

  @override
  Future<PortalAlumna> portal() async {
    consultas++;
    if (sinConexion) throw Exception('sin conexión');
    if (rechazo != null) throw PortalDenegado(rechazo!);
    return valor ??= portalDemo();
  }

  static PortalAlumna portalDemo({
    DateTime? hoy,
    AsistenciaPortal? asistencia,
    int ejercicios = 30,
    bool conCurso = true,
  }) {
    final h = hoy ?? DateTime.now();
    final dia = DateTime(h.year, h.month, h.day);
    final curso = Curso(
      id: 'inst-pcb',
      codigo: 'PCB',
      nombre: 'Programación Competitiva Básica (Python)',
      sedeId: '',
      sedeNombre: 'Sede Beauchef',
      anio: dia.year,
      semestre: 2,
      totalSesiones: 10,
      classroomUrl: 'https://classroom.google.com/c/demo',
      juezVirtualUrl: 'https://vjudge.net/group/demo',
    );
    final sesiones = [
      for (var n = 1; n <= 10; n++)
        SesionClase(
          id: 'clase-$n',
          cursoId: curso.id,
          numeroSesion: n,
          fecha: dia.add(Duration(days: 7 * (n - 4))),
          tema: n == 4 ? 'Funciones y Modularización del Código' : 'Tema de la clase $n',
          estado: n < 4 ? 'realizada' : (n == 6 ? 'suspendida' : 'programada'),
          motivoSuspension: n == 6 ? 'Feriado' : null,
          recursos: n == 1
              ? const [
                  RecursoEducativo(
                    id: 'rec-1',
                    titulo: 'Diapositivas: Variables',
                    tipo: 'slides',
                    url: 'https://slides.ninaspro.cl/pcb-1',
                  ),
                  RecursoEducativo(
                    id: 'rec-2',
                    titulo: 'Colab: práctica guiada',
                    tipo: 'codigo',
                    url: 'https://colab.research.google.com/pcb-1',
                  ),
                ]
              : const [],
        ),
    ];
    return PortalAlumna(
      alumnaId: 'alumna-valentina',
      nombres: 'Valentina',
      apellidos: 'Soto Morales',
      rut: '22.341.890-2',
      apoderadoNombre: 'Marcela Morales Gómez',
      apoderadoTelefono: '+56 9 8765 4321',
      inscripcionEstado: conCurso ? 'activa' : null,
      curso: conCurso ? curso : null,
      sesiones: conCurso ? sesiones : const [],
      asistencias: conCurso
          ? const {
              'clase-1': EstadoAsistencia.presente,
              'clase-2': EstadoAsistencia.presente,
              'clase-3': EstadoAsistencia.ausente,
            }
          : const {},
      asistencia:
          asistencia ??
          const AsistenciaPortal(
            realizadas: 3,
            presentes: 2,
            asistidas: 2,
            porcentaje: 66.7,
            umbral: 80,
            totalClases: 9,
            restantes: 6,
            clasesNecesarias: 6,
          ),
      ejercicios: ejercicios,
      hitosEjercicios: (ejercicios ~/ 25).clamp(0, 2),
      podiosPrimero: 1,
      podiosTercero: 2,
      hoy: dia,
    );
  }
}
