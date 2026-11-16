BEGIN;
SELECT plan(17);

CREATE OR REPLACE FUNCTION pg_temp.actuar_como(p_user uuid, p_aal text DEFAULT 'aal1') RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text,
    true
  );
  EXECUTE 'SET LOCAL role authenticated';
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.como_sistema() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE 'RESET role';
  PERFORM set_config('request.jwt.claims', '', true);
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.crear_usuario(p_id uuid, p_correo text) RETURNS void
LANGUAGE sql AS $$
  INSERT INTO auth.users (instance_id, id, aud, role, email)
  VALUES ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_correo);
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('a8000000-0000-0000-0000-00000000000a', 'Sede Ñuñoa Pruebas'),
  ('b8000000-0000-0000-0000-00000000000b', 'Sede Con Personas'),
  ('c8000000-0000-0000-0000-00000000000c', 'Sede Con Acceso Pendiente'),
  ('e8000000-0000-0000-0000-00000000000e', 'Sede Libre');
INSERT INTO public.cursos (id, codigo, nombre) VALUES
  ('c8000000-0000-0000-0000-000000000001', 'NOM-USADO', 'Curso con instancia'),
  ('c8000000-0000-0000-0000-000000000002', 'NOM-LIBRE', 'Curso sin instancias');
INSERT INTO public.instancias_curso (curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('c8000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-00000000000a', '2026-2', '2026-08-01', '2026-11-28');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('nom.directiva@ninaspro.cl', 'directorio', NULL, '21.811.111-1', 'Directiva', 'Nombres', NULL),
  ('nom.gestion@ninaspro.cl', 'equipo_gestion', 'b8000000-0000-0000-0000-00000000000b', '22.822.222-2', 'Gestión', 'Nombres', NULL),
  ('nom.pendiente@ninaspro.cl', 'tutora', 'c8000000-0000-0000-0000-00000000000c', '23.833.333-3', 'Tutora', 'Pendiente', NULL);
SELECT pg_temp.crear_usuario('d8000000-0000-0000-0000-000000000001', 'nom.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('98000000-0000-0000-0000-00000000000b', 'nom.gestion@ninaspro.cl');
INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
VALUES (gen_random_uuid(), 'd8000000-0000-0000-0000-000000000001', 'NiñasPro Hub', 'totp', 'verified', now(), now());

-- =============================================================================
-- 1. Nombres únicos sin distinguir tildes, mayúsculas, espacios ni signos
-- =============================================================================
SELECT is(public.clave_nombre(' Sede  San Joaquín. '), 'sedesanjoaquin', 'La clave ignora tildes, mayúsculas, espacios y signos');
SELECT is(public.clave_nombre('Ñuñoa Ç'), 'nunoac', 'La clave convierte la ñ y la ç');

SELECT pg_temp.actuar_como('d8000000-0000-0000-0000-000000000001', 'aal2');
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('sede nunoa pruebas') $$,
  '23505', NULL,
  'No se crea una sede que solo difiere por tildes y mayúsculas'
);
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('Sede Ñuñoa-Pruebas.') $$,
  '23505', NULL,
  'No se crea una sede que solo difiere por signos'
);
SELECT throws_ok(
  $$ UPDATE public.sedes SET nombre = 'Sede Nunoa Pruebas' WHERE id = 'e8000000-0000-0000-0000-00000000000e' $$,
  '23505', NULL,
  'Tampoco se puede renombrar una sede con el nombre de otra'
);
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('...') $$,
  '23514', NULL,
  'El nombre de la sede necesita letras o números'
);
SELECT throws_ok(
  $$ INSERT INTO public.cursos (codigo, nombre) VALUES ('NOM USADO', 'Otro') $$,
  '23505', NULL,
  'El código del curso tampoco distingue espacios ni signos'
);
SELECT lives_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('Sede Ñuñoa Norte') $$,
  'Un nombre distinto se acepta'
);

-- =============================================================================
-- 2. Eliminar sedes y cursos sin uso
-- =============================================================================
SELECT throws_ok(
  $$ DELETE FROM public.sedes WHERE id = 'a8000000-0000-0000-0000-00000000000a' $$,
  '23503',
  'No se puede eliminar "Sede Ñuñoa Pruebas": tiene 1 instancia de curso. Puedes desactivarla en su lugar.',
  'No se elimina una sede con instancias'
);
SELECT throws_ok(
  $$ DELETE FROM public.sedes WHERE id = 'b8000000-0000-0000-0000-00000000000b' $$,
  '23503',
  'No se puede eliminar "Sede Con Personas": tiene 1 persona asignada. Puedes desactivarla en su lugar.',
  'No se elimina una sede con personas asignadas'
);
SELECT throws_ok(
  $$ DELETE FROM public.sedes WHERE id = 'c8000000-0000-0000-0000-00000000000c' $$,
  '23503',
  'No se puede eliminar "Sede Con Acceso Pendiente": tiene 1 acceso pendiente. Puedes desactivarla en su lugar.',
  'No se elimina una sede con accesos pendientes (se borrarían en cascada)'
);
SELECT throws_ok(
  $$ DELETE FROM public.cursos WHERE id = 'c8000000-0000-0000-0000-000000000001' $$,
  '23503',
  'No se puede eliminar "NOM-USADO": tiene 1 instancia de curso.',
  'No se elimina un curso con instancias'
);

SELECT pg_temp.actuar_como('98000000-0000-0000-0000-00000000000b');
SELECT is_empty(
  $$ DELETE FROM public.sedes WHERE id = 'e8000000-0000-0000-0000-00000000000e' RETURNING id $$,
  'Gestión no elimina sedes'
);
SELECT is_empty(
  $$ DELETE FROM public.cursos WHERE id = 'c8000000-0000-0000-0000-000000000002' RETURNING id $$,
  'Gestión no elimina cursos'
);

SELECT pg_temp.actuar_como('d8000000-0000-0000-0000-000000000001', 'aal2');
SELECT isnt_empty(
  $$ DELETE FROM public.sedes WHERE id = 'e8000000-0000-0000-0000-00000000000e' RETURNING id $$,
  'La Directiva elimina una sede sin uso'
);
SELECT isnt_empty(
  $$ DELETE FROM public.cursos WHERE id = 'c8000000-0000-0000-0000-000000000002' RETURNING id $$,
  'La Directiva elimina un curso sin instancias'
);

SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT count(*)::int FROM public.correos_autorizados WHERE sede_id = 'c8000000-0000-0000-0000-00000000000c'),
  1,
  'El acceso pendiente sigue intacto tras el intento de eliminar su sede'
);

SELECT * FROM finish();
ROLLBACK;
