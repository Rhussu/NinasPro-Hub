BEGIN;
SELECT plan(8); -- Actualizado a 8 aserciones

-- 1. Crear usuario base en auth.users y su perfil
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000001', 'tutora@ninaspro.cl');

INSERT INTO perfiles (id, rut, nombres, apellidos, correo, rol)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    '11111111-1',
    'Andrea',
    'González',
    'tutora@ninaspro.cl',
    'tutora'
);

SELECT is(
    (SELECT count(*)::integer FROM perfiles WHERE id = '00000000-0000-0000-0000-000000000001'),
    1,
    'El perfil fue insertado correctamente vinculado al auth.user'
);

-- 2. Crear estructura académica (Sede + Curso + Instancia)
INSERT INTO sedes (id, nombre, modalidad)
VALUES ('00000000-0000-0000-0000-000000000010', 'Sede Online', 'online');

INSERT INTO cursos (id, nombre, codigo)
VALUES ('00000000-0000-0000-0000-000000000020', 'Introducción a Python', 'PY-101');

INSERT INTO instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino)
VALUES (
    '00000000-0000-0000-0000-000000000030',
    '00000000-0000-0000-0000-000000000020',
    '00000000-0000-0000-0000-000000000010',
    '2026-S1',
    '2026-03-01',
    '2026-07-01'
);

-- 3. Crear apoderado y alumna
INSERT INTO apoderados (id, rut, nombres, apellidos, correo, telefono)
VALUES (
    '00000000-0000-0000-0000-000000000100',
    '22222222-2',
    'Carlos',
    'Soto',
    'carlos.soto@correo.cl',
    '+56912345678'
);

INSERT INTO alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id)
VALUES (
    '00000000-0000-0000-0000-000000000200',
    '33333333-3',
    'Valentina',
    'Soto',
    '2010-05-12',
    '00000000-0000-0000-0000-000000000100'
);

-- 4. Registrar inscripción
INSERT INTO inscripciones (id, alumna_id, instancia_curso_id, estado)
VALUES (
    '00000000-0000-0000-0000-000000000300',
    '00000000-0000-0000-0000-000000000200',
    '00000000-0000-0000-0000-000000000030',
    'activa'
);

-- Test 2: Verificar inserción de inscripción
SELECT is(
    (SELECT estado FROM inscripciones WHERE id = '00000000-0000-0000-0000-000000000300'),
    'activa'::estado_inscripcion,
    'La inscripción se crea con el estado enum correcto'
);

-- Test 3: Probar restricción UNIQUE compuesta en inscripciones
SELECT throws_ok(
    $$ INSERT INTO inscripciones (alumna_id, instancia_curso_id, estado)
       VALUES ('00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000030', 'preinscrita') $$,
    '23505',
    NULL,
    'No se puede duplicar la inscripción de una alumna en la misma instancia de curso'
);

-- Test 4: Probar ON DELETE RESTRICT en apoderados
SELECT throws_ok(
    $$ DELETE FROM apoderados WHERE id = '00000000-0000-0000-0000-000000000100' $$,
    '23503',
    NULL,
    'No se puede eliminar un apoderado con alumnas asociadas (ON DELETE RESTRICT)'
);

-- Test 5: Probar ON DELETE RESTRICT en cursos (ID corregido a ...000020)
SELECT throws_ok(
    $$ DELETE FROM cursos WHERE id = '00000000-0000-0000-0000-000000000020' $$,
    '23503',
    NULL,
    'No se puede eliminar un curso si tiene instancias vinculadas'
);

-- Test 6: Probar ON DELETE RESTRICT en sedes
SELECT throws_ok(
    $$ DELETE FROM sedes WHERE id = '00000000-0000-0000-0000-000000000010' $$,
    '23503',
    NULL,
    'No se puede eliminar una sede si tiene instancias de curso asignadas'
);

-- Test 7: Probar que una alumna no se puede borrar si tiene inscripciones
SELECT throws_ok(
    $$ DELETE FROM alumnas WHERE id = '00000000-0000-0000-0000-000000000200' $$,
    '23503',
    NULL,
    'No se puede eliminar una alumna si registra inscripciones activas'
);

-- Test 8: Probar que falla insertar asistencia para una clase inexistente
SELECT throws_ok(
    $$ INSERT INTO asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
       VALUES (
           '00000000-0000-0000-0000-000000009999',
           '00000000-0000-0000-0000-000000000300',
           'presente',
           '00000000-0000-0000-0000-000000000001'
       ) $$,
    '23503',
    NULL,
    'Falla al registrar asistencia si la clase no existe en la base de datos'
);

SELECT * FROM finish();
ROLLBACK;