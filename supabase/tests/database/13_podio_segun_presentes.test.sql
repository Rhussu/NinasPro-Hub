BEGIN;
SELECT plan(11);

-- =============================================================================
-- Datos de prueba: una clase de hoy con tres alumnas activas y una tutora
-- =============================================================================
CREATE OR REPLACE FUNCTION pg_temp.actuar_como(p_user uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')::text,
    true
  );
  EXECUTE 'SET LOCAL role authenticated';
END;
$$;

-- Inscripción de la alumna n (1, 2 o 3)
CREATE OR REPLACE FUNCTION pg_temp.i(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('1d000000-0000-0000-0000-00000000000' || p_n)::uuid $$;

CREATE OR REPLACE FUNCTION pg_temp.marcar(p_n int, p_estado text) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT public.guardar_asistencia_clase(
    '2d000000-0000-0000-0000-000000000001',
    jsonb_build_array(jsonb_build_object('inscripcion_id', pg_temp.i(p_n), 'estado', p_estado)),
    now() + interval '1 day'
  );
$$;

CREATE OR REPLACE FUNCTION pg_temp.podio() RETURNS text
LANGUAGE sql AS $$
  SELECT coalesce(string_agg(right(inscripcion_id::text, 1) || '=' || podio_kahoot, ' ' ORDER BY podio_kahoot), '')
  FROM public.participacion_clase
  WHERE clase_id = '2d000000-0000-0000-0000-000000000001' AND podio_kahoot IS NOT NULL;
$$;

INSERT INTO public.sedes (id, nombre) VALUES ('ad000000-0000-0000-0000-00000000000a', 'Sede Podio');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('cd000000-0000-0000-0000-000000000001', 'Curso Podio', 'POD');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('0d000000-0000-0000-0000-00000000000a', 'cd000000-0000-0000-0000-000000000001', 'ad000000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha) VALUES
  ('2d000000-0000-0000-0000-000000000001', '0d000000-0000-0000-0000-00000000000a', 1, public.hoy_chile());

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('pod.tutora@ninaspro.cl', 'tutora', 'ad000000-0000-0000-0000-00000000000a', '24.411.111-1', 'Tutora', 'Podio', NULL);
INSERT INTO auth.users (instance_id, id, aud, role, email)
VALUES ('00000000-0000-0000-0000-000000000000', '7d000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'pod.tutora@ninaspro.cl');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('ad000000-0000-0000-0000-0000000000d1', 'Apoderada', 'Podio', 'apoderada.podio@correo.cl', '+56 9 3333 3333');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a1000000-0000-0000-0000-0000000000d1', '28.000.001-1', 'Uno', 'Podio', '2011-01-01', 'ad000000-0000-0000-0000-0000000000d1'),
  ('a1000000-0000-0000-0000-0000000000d2', '28.000.002-K', 'Dos', 'Podio', '2011-01-01', 'ad000000-0000-0000-0000-0000000000d1'),
  ('a1000000-0000-0000-0000-0000000000d3', '28.000.003-8', 'Tres', 'Podio', '2011-01-01', 'ad000000-0000-0000-0000-0000000000d1');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, registrado_por)
SELECT id, 'ad000000-0000-0000-0000-0000000000d1', 'otorgada', '7d000000-0000-0000-0000-000000000001'
FROM public.alumnas WHERE apoderado_id = 'ad000000-0000-0000-0000-0000000000d1';
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id) VALUES
  (pg_temp.i(1), 'a1000000-0000-0000-0000-0000000000d1', '0d000000-0000-0000-0000-00000000000a'),
  (pg_temp.i(2), 'a1000000-0000-0000-0000-0000000000d2', '0d000000-0000-0000-0000-00000000000a'),
  (pg_temp.i(3), 'a1000000-0000-0000-0000-0000000000d3', '0d000000-0000-0000-0000-00000000000a');

SELECT pg_temp.actuar_como('7d000000-0000-0000-0000-000000000001');
SELECT public.guardar_asistencia_clase('2d000000-0000-0000-0000-000000000001', jsonb_build_array(
  jsonb_build_object('inscripcion_id', pg_temp.i(1), 'estado', 'presente'),
  jsonb_build_object('inscripcion_id', pg_temp.i(2), 'estado', 'ausente'),
  jsonb_build_object('inscripcion_id', pg_temp.i(3), 'estado', 'ausente')
));

-- =============================================================================
-- 1. Con una sola presente, queda primera
-- =============================================================================
SELECT lives_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(1), NULL, NULL) $$,
  'Con una sola alumna presente se registra el Kahoot'
);
SELECT is(pg_temp.podio(), '1=1', 'La única presente queda en el 1° lugar');
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', NULL, pg_temp.i(1), NULL) $$,
  '22023', 'Completa los lugares del podio en orden, desde el 1° lugar.',
  'El podio se llena desde el 1° lugar'
);
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(1), pg_temp.i(2), NULL) $$,
  '22023', 'El podio solo admite alumnas presentes en la clase.',
  'Una alumna ausente no entra al podio'
);

-- =============================================================================
-- 2. Con dos presentes, se elige quién quedó primera y quién segunda
-- =============================================================================
SELECT pg_temp.marcar(2, 'presente');
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(1), NULL, NULL) $$,
  '22023', 'Con 2 alumnas presentes, el podio lleva 2 lugares.',
  'Con dos presentes, el podio lleva los dos lugares'
);
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(1), pg_temp.i(1), NULL) $$,
  '22023', 'Elige dos alumnas distintas para el podio.',
  'Las dos del podio son distintas'
);
SELECT lives_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(2), pg_temp.i(1), NULL) $$,
  'Con dos presentes se registra el 1° y el 2° lugar'
);
SELECT is(pg_temp.podio(), '2=1 1=2', 'La segunda alumna quedó primera y la primera, segunda');

-- =============================================================================
-- 3. Con tres o más presentes, los tres lugares
-- =============================================================================
SELECT pg_temp.marcar(3, 'presente');
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(2), pg_temp.i(1), NULL) $$,
  '22023', 'Con 3 alumnas presentes, el podio lleva 3 lugares.',
  'Con tres presentes, el podio lleva los tres lugares'
);
SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(3), pg_temp.i(2), pg_temp.i(1));
SELECT is(pg_temp.podio(), '3=1 2=2 1=3', 'Se guardan los tres lugares');

-- Si una pasa a ausente, el podio se vuelve a registrar con las dos que quedan
SELECT pg_temp.marcar(3, 'ausente');
SELECT public.guardar_podio_kahoot('2d000000-0000-0000-0000-000000000001', pg_temp.i(1), pg_temp.i(2), NULL);
SELECT is(pg_temp.podio(), '1=1 2=2', 'El podio corregido deja solo los lugares de las presentes');

SELECT * FROM finish();
ROLLBACK;
