import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/roles_repository.dart';
import 'package:ninas_pro_hub/repositories/voluntariado_repository.dart';
import 'package:ninas_pro_hub/screens/gestion/gestion_tutoras_views.dart' show claseParaRoles;
import 'package:ninas_pro_hub/utils/exportacion.dart';
import 'package:ninas_pro_hub/utils/planilla.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Mapeos de los repositorios de voluntariado y roles, la plantilla del
/// voluntariado y la exportación a CSV/XLSX (US-30..32, US-43, US-44)
void main() {
  group('MapeoVoluntariado', () {
    test('lee una fila de la vista voluntariado con su trayectoria y sus sedes', () {
      final f = MapeoVoluntariado.ficha({
        'id': 'v1',
        'perfil_id': null,
        'rut': '20.123.456-5',
        'nombres': 'Sofía',
        'apellidos': 'Araya Medina',
        'correo': 'sofia.araya@ninaspro.cl',
        'telefono': '+56 9 1111 2222',
        'institucion': 'U. de Chile',
        'rol': 'equipo_gestion',
        'sede_id': 's1',
        'sede_nombre': 'Sede Beauchef',
        'fecha_ingreso': '2026-03-01',
        'fecha_salida': null,
        'adhesion_firmada': true,
        'fecha_firma_adhesion': '2026-03-02',
        'cuenta': 'autorizada',
        'autorizacion_expira_en': '2026-12-01T12:00:00+00:00',
        'cursos': [
          {
            'instancia_id': 'i1',
            'curso_codigo': 'PCB',
            'curso_nombre': 'Programación',
            'sede_id': 's2',
            'sede_nombre': 'Sede Valparaíso',
            'periodo': '2026-2',
            'seccion': 2,
          },
        ],
        'sede_ids': ['s1', 's2'],
      });

      expect(f.nombre, 'Sofía Araya Medina');
      expect(f.rol, RolVoluntaria.equipoGestion);
      expect(f.cuenta, CuentaVoluntaria.autorizada);
      expect(f.retirada, isFalse);
      expect(f.apta, isTrue);
      expect(f.fechaFirmaAdhesion, DateTime(2026, 3, 2));
      expect(f.autorizacionExpiraEn, isNotNull);
      expect(f.cursos.single.etiqueta, 'PCB · Sede Valparaíso · 2026-2 (Sección B)');
      expect(f.sedeIds, {'s1', 's2'});
    });

    test('una ficha retirada no es apta y una cuenta desconocida queda sin autorización', () {
      final f = MapeoVoluntariado.ficha({
        'id': 'v2',
        'rut': '1-9',
        'nombres': 'A',
        'apellidos': 'B',
        'correo': 'a@ninaspro.cl',
        'fecha_ingreso': '2024-01-01',
        'fecha_salida': '2025-01-01',
        'adhesion_firmada': true,
        'cuenta': 'otra',
      });
      expect(f.retirada, isTrue);
      expect(f.apta, isFalse);
      expect(f.rol, RolVoluntaria.tutora);
      expect(f.cuenta, CuentaVoluntaria.sinAutorizacion);
    });

    test('lee la revisión de una carga y arma la fila del alta individual', () {
      final r = MapeoVoluntariado.revision({
        'filas': [
          {
            'fila': 2,
            'rut': '21.190.008-3',
            'nombre': 'A B',
            'correo': 'a@ninaspro.cl',
            'estado': 'nueva',
            'ficha_id': 'v9',
          },
          {'fila': 3, 'rut': 'x', 'nombre': 'C', 'correo': '', 'estado': 'invalida', 'motivo': 'RUT inválido'},
        ],
        'creadas': 1,
        'actualizadas': 0,
        'rechazadas': 1,
      });
      expect(r.creadas, 1);
      expect(r.rechazadasFilas.single.motivo, 'RUT inválido');
      expect(r.filas.first.fichaId, 'v9');

      final fila = MapeoVoluntariado.filaAlta(
        DatosVoluntaria(
          rut: ' 21.190.008-3 ',
          nombres: 'Camila ',
          apellidos: 'Rojas',
          correo: 'camila@ninaspro.cl',
          rol: RolVoluntaria.equipoGestion,
          fechaIngreso: DateTime(2026, 3, 1),
        ),
      );
      expect(fila, {
        'fila': 1,
        'rut': '21.190.008-3',
        'nombres': 'Camila',
        'apellidos': 'Rojas',
        'correo': 'camila@ninaspro.cl',
        'telefono': '',
        'institucion': '',
        'rol': 'equipo_gestion',
        'fecha_ingreso': '2026-03-01',
      });
    });
  });

  group('MapeoRoles', () {
    test('lee el catálogo, el equipo de una clase y mis roles', () {
      final rol = MapeoRoles.rol({
        'id': 'r1',
        'codigo': 'presentar',
        'nombre': 'Presentar',
        'descripcion': null,
        'color_hex': '#1D5CA5',
        'es_requerido': true,
        'activo': false,
      });
      expect(rol.esRequerido, isTrue);
      expect(rol.activo, isFalse);
      expect(rol.color.toARGB32(), 0xFF1D5CA5);
      expect(MapeoRoles.filaRol(rol.copyWith(nombre: ' Presentar la Clase ')), {
        'nombre': 'Presentar la Clase',
        'descripcion': '',
        'color_hex': '#1D5CA5',
        'es_requerido': true,
        'activo': false,
      });

      final equipo = MapeoRoles.equipo({
        'tutor_id': 't1',
        'nombres': 'Daniela',
        'apellidos': 'Valenzuela',
        'es_equipo_gestion': false,
        'tareas': [
          {'id': 'a', 'rol_id': 'r1', 'completada': true},
          {'id': 'b', 'rol_id': 'r2', 'completada': false},
        ],
      });
      expect(equipo.nombre, 'Daniela Valenzuela');
      expect(equipo.rolIds, {'r1', 'r2'});
      expect(equipo.tareas.first.completada, isTrue);

      final mia = MapeoRoles.miTarea({
        'tarea_id': 'a',
        'clase_id': 'c4',
        'numero_sesion': 4,
        'rol_id': 'r1',
        'completada': false,
      });
      expect((mia.claseId, mia.numeroSesion, mia.tarea.id), ('c4', 4, 'a'));
    });

    test('el color inválido cae en el violeta de marca', () {
      expect(const RolTarea(id: 'x', nombre: 'x', colorHex: 'nada').color.toARGB32(), 0xFF8B3295);
    });

    test('los mensajes de la base se muestran tal cual y el nombre repetido se explica', () {
      expect(
        mensajeRoles(const PostgrestException(message: 'Ya existe', code: '23505')),
        'Ya existe un rol con ese nombre.',
      );
      expect(
        mensajeRoles(
          const PostgrestException(message: 'La clase está suspendida: no se asignan roles.', code: '22023'),
        ),
        'La clase está suspendida: no se asignan roles.',
      );
      expect(mensajeRoles(const PostgrestException(message: 'boom', code: 'XX000')), startsWith('No pudimos guardar'));
    });
  });

  group('Plantilla del voluntariado', () {
    test('la plantilla descargable se lee de vuelta con sus columnas y la fecha en ISO', () {
      final planilla = leerPlanilla(plantillaVoluntariadoCsv(), 'plantilla_voluntariado.csv');
      final filas = filasVoluntariado(planilla);
      expect(planilla.encabezados, columnasPlantillaVoluntariado);
      expect(filas.single['correo'], 'camila.rojas@ninaspro.cl');
      expect(filas.single['rol'], 'Tutora');
      expect(filas.single['fecha_ingreso'], '2026-03-01');
      expect(filas.single['fila'], 2);
    });

    test('una planilla con las columnas de alumnas se rechaza completa', () {
      final planilla = leerPlanilla(plantillaAlumnasCsv(), 'alumnas.csv');
      expect(() => filasVoluntariado(planilla), throwsA(isA<PlanillaInvalida>()));
    });
  });

  group('Exportación', () {
    test('el CSV va en UTF-8 con BOM y las celdas con comas entre comillas', () {
      final bytes = archivoTabla(
        FormatoExportacion.csv,
        'Hoja',
        ['nombre', 'cursos'],
        [
          ['Ñandú', 'PCB; WEB, B'],
        ],
      );
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.skip(3).toList()), 'nombre,cursos\r\nÑandú,"PCB; WEB, B"\r\n');
    });

    test('el XLSX tiene una hoja con los encabezados y las filas', () {
      final bytes = archivoTabla(
        FormatoExportacion.xlsx,
        'Voluntariado',
        ['rut', 'nombre'],
        [
          ['21.190.008-3', 'Camila Ñuñez'],
        ],
      );
      final libro = Excel.decodeBytes(bytes);
      final hoja = libro.tables['Voluntariado']!;
      expect(libro.tables.keys, ['Voluntariado']);
      expect(hoja.rows.length, 2);
      expect(hoja.rows[1][1]?.value.toString(), 'Camila Ñuñez');
    });
  });

  group('claseParaRoles', () {
    SesionClase sesion(int n, DateTime fecha, {String estado = 'programada'}) =>
        SesionClase(id: 'c$n', cursoId: 'i', numeroSesion: n, fecha: fecha, tema: '', estado: estado);

    test('elige la próxima clase no suspendida, hoy incluida', () {
      final hoy = DateTime(2026, 11, 16, 15);
      final sesiones = [
        sesion(1, DateTime(2026, 11, 7), estado: 'realizada'),
        sesion(2, DateTime(2026, 11, 14), estado: 'realizada'),
        sesion(3, DateTime(2026, 11, 21), estado: 'suspendida'),
        sesion(4, DateTime(2026, 11, 28)),
      ];
      expect(claseParaRoles(sesiones, hoy)?.id, 'c4');
      expect(claseParaRoles(sesiones, DateTime(2026, 11, 14, 18))?.id, 'c2');
    });

    test('con el curso terminado elige la última clase y sin clases, ninguna', () {
      final sesiones = [sesion(1, DateTime(2026, 1, 3)), sesion(2, DateTime(2026, 1, 10))];
      expect(claseParaRoles(sesiones, DateTime(2026, 6, 1))?.id, 'c2');
      expect(claseParaRoles(const [], DateTime(2026, 6, 1)), isNull);
    });
  });
}
