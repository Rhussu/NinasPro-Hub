BEGIN;
SELECT plan(8);

-- 1. Verificar existencia de tablas nucleares
SELECT has_table('public', 'perfiles', 'Tabla perfiles existe');
SELECT has_table('public', 'alumnas', 'Tabla alumnas existe');
SELECT has_table('public', 'inscripciones', 'Tabla inscripciones existe');
SELECT has_table('public', 'asistencia_alumnas', 'Tabla asistencia_alumnas existe');

-- 2. Verificar que los ENUMs rechacen valores inválidos (Código Postgres 22P02)
SELECT throws_ok(
    $$ SELECT 'rol_fantasma'::rol_usuario $$,
    '22P02',
    NULL,
    'El tipo rol_usuario debe rechazar valores que no pertenezcan al enum'
);

SELECT throws_ok(
    $$ SELECT 'expulsada'::estado_inscripcion $$,
    '22P02',
    NULL,
    'El tipo estado_inscripcion debe rechazar estados fuera del catálogo definido'
);

-- 3. Verificar que la tabla sedes rechace nombres duplicados (UNIQUE)
PREPARE insert_sede AS INSERT INTO sedes (nombre, ciudad, region) VALUES ('Sede Concepción', 'Concepción', 'Biobío');

SELECT lives_ok(
    'EXECUTE insert_sede',
    'Permite registrar una sede válida'
);

SELECT throws_ok(
    'EXECUTE insert_sede',
    '23505', -- unique_violation
    NULL,
    'Rechaza duplicar el nombre de una sede (violación de restricción UNIQUE)'
);

SELECT * FROM finish();
ROLLBACK;