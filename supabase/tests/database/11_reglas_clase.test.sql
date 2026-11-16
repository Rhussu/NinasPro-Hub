BEGIN;
SELECT plan(45);

-- =============================================================================
-- Datos de prueba: un curso de la sede A con tutoras asignadas y cuatro alumnas
-- activas, una preinscrita y una alumna de otro curso
-- =============================================================================
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

-- Lista de asistencia en JSON a partir de pares (alumna, estado)
CREATE OR REPLACE FUNCTION pg_temp.lista(p_pares text[]) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_agg(jsonb_build_object('inscripcion_id', ('1b000000-0000-0000-0000-00000000000' || p[1])::uuid, 'estado', p[2]))
  FROM (SELECT string_to_array(x, ':') AS p FROM unnest(p_pares) AS x) AS pares;
$$;

CREATE OR REPLACE FUNCTION pg_temp.estado(p_alumna int) RETURNS text
LANGUAGE sql AS $$
  SELECT estado::text FROM public.asistencia_alumnas
  WHERE clase_id = '2b000000-0000-0000-0000-000000000002'
    AND inscripcion_id = ('1b000000-0000-0000-0000-00000000000' || p_alumna)::uuid;
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('ab000000-0000-0000-0000-00000000000a', 'Sede Clase A'),
  ('bb000000-0000-0000-0000-00000000000b', 'Sede Clase B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('cb000000-0000-0000-0000-000000000001', 'Curso Clase', 'CLA');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('0b000000-0000-0000-0000-00000000000a', 'cb000000-0000-0000-0000-000000000001', 'ab000000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60),
  ('0b000000-0000-0000-0000-00000000000b', 'cb000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-00000000000b', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);

-- Clases de la sede A: una de hace una semana, la de hoy, una futura y una suspendida
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado, motivo_suspension) VALUES
  ('2b000000-0000-0000-0000-000000000001', '0b000000-0000-0000-0000-00000000000a', 1, public.hoy_chile() - 7, 'programada', NULL),
  ('2b000000-0000-0000-0000-000000000002', '0b000000-0000-0000-0000-00000000000a', 2, public.hoy_chile(), 'programada', NULL),
  ('2b000000-0000-0000-0000-000000000003', '0b000000-0000-0000-0000-00000000000a', 3, public.hoy_chile() + 7, 'programada', NULL),
  ('2b000000-0000-0000-0000-000000000004', '0b000000-0000-0000-0000-00000000000a', 4, public.hoy_chile() - 14, 'suspendida', 'Paro');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('cla.gestion.a@ninaspro.cl', 'equipo_gestion', 'ab000000-0000-0000-0000-00000000000a', '21.611.111-1', 'Gestión', 'A', NULL),
  ('cla.gestion.b@ninaspro.cl', 'equipo_gestion', 'bb000000-0000-0000-0000-00000000000b', '22.622.222-2', 'Gestión', 'B', NULL),
  ('cla.tutora.1@ninaspro.cl', 'tutora', 'ab000000-0000-0000-0000-00000000000a', '23.633.333-3', 'Tutora', 'Uno', NULL),
  ('cla.tutora.2@ninaspro.cl', 'tutora', 'ab000000-0000-0000-0000-00000000000a', '24.644.444-4', 'Tutora', 'Dos', NULL),
  ('cla.tutora.x@ninaspro.cl', 'tutora', 'ab000000-0000-0000-0000-00000000000a', '25.655.555-5', 'Tutora', 'Sin Adhesión', NULL);
SELECT pg_temp.crear_usuario('9b000000-0000-0000-0000-00000000000a', 'cla.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('9b000000-0000-0000-0000-00000000000b', 'cla.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('7b000000-0000-0000-0000-000000000001', 'cla.tutora.1@ninaspro.cl');
SELECT pg_temp.crear_usuario('7b000000-0000-0000-0000-000000000002', 'cla.tutora.2@ninaspro.cl');
SELECT pg_temp.crear_usuario('7b000000-0000-0000-0000-00000000000f', 'cla.tutora.x@ninaspro.cl');

INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada, fecha_salida) VALUES
  ('9b000000-0000-0000-0000-00000000000a', '2025-03-01', true, NULL),
  ('7b000000-0000-0000-0000-000000000001', '2025-03-01', true, NULL),
  ('7b000000-0000-0000-0000-000000000002', '2025-03-01', true, NULL),
  ('7b000000-0000-0000-0000-00000000000f', '2025-03-01', false, NULL),
  ('9b000000-0000-0000-0000-00000000000b', '2024-03-01', true, '2025-03-01');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('ad000000-0000-0000-0000-000000000001', 'Apoderada', 'Clase', 'apoderada@correo.cl', '+56 9 1111 1111');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a1000000-0000-0000-0000-000000000001', '26.000.001-8', 'Ana', 'Uno', '2011-01-01', 'ad000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000002', '26.000.002-6', 'Berta', 'Dos', '2011-01-01', 'ad000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000003', '26.000.003-4', 'Carla', 'Tres', '2011-01-01', 'ad000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000004', '26.000.004-2', 'Dana', 'Cuatro', '2011-01-01', 'ad000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000005', '26.000.005-0', 'Elsa', 'Preinscrita', '2011-01-01', 'ad000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000006', '26.000.006-9', 'Fran', 'Otra Sede', '2011-01-01', 'ad000000-0000-0000-0000-000000000001');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, autoriza_uso_imagen_general, registrado_por)
SELECT id, 'ad000000-0000-0000-0000-000000000001', 'otorgada', CASE WHEN id = 'a1000000-0000-0000-0000-000000000004' THEN 'no_otorgada' ELSE 'otorgada' END::public.estado_autorizacion,
       '9b000000-0000-0000-0000-00000000000a'
FROM public.alumnas WHERE id <> 'a1000000-0000-0000-0000-000000000005' AND rut LIKE '26.000.00%';
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id) VALUES
  ('1b000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', '0b000000-0000-0000-0000-00000000000a'),
  ('1b000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', '0b000000-0000-0000-0000-00000000000a'),
  ('1b000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003', '0b000000-0000-0000-0000-00000000000a'),
  ('1b000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000004', '0b000000-0000-0000-0000-00000000000a'),
  ('1b000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000005', '0b000000-0000-0000-0000-00000000000a'),
  ('1b000000-0000-0000-0000-000000000006', 'a1000000-0000-0000-0000-000000000006', '0b000000-0000-0000-0000-00000000000b');

-- =============================================================================
-- 1. Asignación a cursos: adhesión firmada y voluntaria vigente (US-31)
-- =============================================================================
SELECT lives_ok(
  $$ INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
       ('0b000000-0000-0000-0000-00000000000a', '9b000000-0000-0000-0000-00000000000a', '9b000000-0000-0000-0000-00000000000a'),
       ('0b000000-0000-0000-0000-00000000000a', '7b000000-0000-0000-0000-000000000001', '9b000000-0000-0000-0000-00000000000a'),
       ('0b000000-0000-0000-0000-00000000000a', '7b000000-0000-0000-0000-000000000002', '9b000000-0000-0000-0000-00000000000a') $$,
  'Se asignan al curso las voluntarias con la adhesión firmada'
);
SELECT throws_ok(
  $$ INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por)
     VALUES ('0b000000-0000-0000-0000-00000000000a', '7b000000-0000-0000-0000-00000000000f', '9b000000-0000-0000-0000-00000000000a') $$,
  '22023', 'Para asignarla a un curso, la voluntaria debe tener firmada la declaración de adhesión.',
  'No se asigna a un curso a una voluntaria sin la adhesión firmada'
);
SELECT throws_ok(
  $$ INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por)
     VALUES ('0b000000-0000-0000-0000-00000000000b', '9b000000-0000-0000-0000-00000000000b', '9b000000-0000-0000-0000-00000000000b') $$,
  '22023', NULL,
  'No se asigna a un curso a una voluntaria que ya salió del voluntariado'
);

-- =============================================================================
-- 2. Pase de lista de alumnas (US-13, US-14)
-- =============================================================================
SELECT pg_temp.actuar_como('7b000000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
     VALUES ('2b000000-0000-0000-0000-000000000002', '1b000000-0000-0000-0000-000000000001', 'presente', auth.uid()) $$,
  '42501', NULL,
  'La asistencia no se escribe directo en la tabla: pasa por la RPC'
);
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002',
     pg_temp.lista(ARRAY['1:presente', '2:presente', '3:presente', '4:ausente'])) ->> 'guardados')::int,
  4,
  'La tutora guarda el pase de lista de la clase de hoy'
);
SELECT is(
  (SELECT estado::text || ' ' || (registrada_por = auth.uid())::text || ' ' || (fecha_realizacion IS NOT NULL)::text
   FROM public.clases WHERE id = '2b000000-0000-0000-0000-000000000002'),
  'realizada true true',
  'El primer pase de lista deja la clase realizada, con la autora y la hora (US-13 escenario 4)'
);
SELECT is(
  (SELECT count(*)::int FROM public.asistencia_alumnas
   WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND registrado_por = auth.uid()),
  4,
  'Cada registro queda con la tutora que lo guardó'
);
SELECT is(
  public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002',
    pg_temp.lista(ARRAY['1:presente', '2:presente', '3:presente', '4:ausente'])) - 'omitidas' - 'justificadas_conservadas',
  '{"guardados": 0, "sin_cambios": 4, "conservados_por_edicion_posterior": 0}'::jsonb,
  'Reenviar la misma lista (reintento tras un corte) no escribe nada'
);
SELECT is(
  (SELECT count(*)::int FROM public.asistencia_alumnas WHERE clase_id = '2b000000-0000-0000-0000-000000000002'),
  4,
  'Los reintentos no duplican registros (US-14 escenario 3)'
);
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000003', pg_temp.lista(ARRAY['1:presente'])) $$,
  '22023', NULL,
  'No se pasa lista de una clase que aún no se realiza'
);
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000004', pg_temp.lista(ARRAY['1:presente'])) $$,
  '22023', 'La clase está suspendida: no se registra asistencia ni participación.',
  'No se pasa lista de una clase suspendida'
);
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['6:presente'])) $$,
  '22023', 'La alumna no está inscrita en el curso de esta clase.',
  'No se registra a una alumna de otro curso'
);
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', '[]'::jsonb) $$,
  '22023', NULL,
  'Una lista vacía no se guarda'
);
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['5:presente'])) ->> 'omitidas')::int,
  1,
  'La alumna preinscrita (sin consentimiento) se omite del pase de lista (RB-1)'
);

SELECT pg_temp.actuar_como('9b000000-0000-0000-0000-00000000000b');
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['1:ausente'])) $$,
  '42501', NULL,
  'Gestión de otra sede no registra la asistencia'
);
SELECT is_empty(
  $$ SELECT 1 FROM public.lista_asistencia_clase('2b000000-0000-0000-0000-000000000002') $$,
  'Gestión de otra sede no ve la lista de la clase'
);

-- =============================================================================
-- 3. Justificadas: solo el Equipo de Gestión (US-13 escenarios 1 y 2)
-- =============================================================================
SELECT pg_temp.actuar_como('9b000000-0000-0000-0000-00000000000a');
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['4:justificada'])) ->> 'guardados')::int,
  1,
  'Gestión de la sede marca una inasistencia como justificada'
);
SELECT pg_temp.actuar_como('7b000000-0000-0000-0000-000000000001');
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['4:presente', '1:justificada'])) ->> 'justificadas_conservadas')::int,
  2,
  'La tutora no cambia una justificada ni marca justificadas'
);
SELECT is(pg_temp.estado(4) || ' ' || pg_temp.estado(1), 'justificada presente', 'Los estados quedan como estaban');

-- =============================================================================
-- 4. Concurrencia: prevalece el último guardado (US-15 escenario 2, US-14)
-- =============================================================================
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002',
     pg_temp.lista(ARRAY['3:ausente']), now() - interval '10 minutes') ->> 'conservados_por_edicion_posterior')::int,
  1,
  'Una lista guardada sin conexión antes de la última edición no la pisa al sincronizar'
);
SELECT is(pg_temp.estado(3), 'presente', 'Se conserva la versión más reciente');

SELECT pg_temp.actuar_como('7b000000-0000-0000-0000-000000000002');
SELECT is(
  (public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002',
     pg_temp.lista(ARRAY['3:ausente']), now() + interval '1 day') ->> 'guardados')::int,
  1,
  'Una corrección posterior reemplaza el registro (llegada tardía, US-15 escenario 1)'
);
SELECT is(
  (SELECT pg_temp.estado(3) || ' ' || (registrado_por = auth.uid())::text FROM public.asistencia_alumnas
   WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND inscripcion_id = '1b000000-0000-0000-0000-000000000003'),
  'ausente true',
  'El registro muestra a la última tutora que lo editó'
);

-- =============================================================================
-- 5. Participación y ejercicios: solo presentes (US-28, TC-13)
-- =============================================================================
SELECT throws_ok(
  $$ INSERT INTO public.participacion_clase (clase_id, inscripcion_id, ejercicios_completados, registrado_por)
     VALUES ('2b000000-0000-0000-0000-000000000002', '1b000000-0000-0000-0000-000000000001', 3, auth.uid()) $$,
  '42501', NULL,
  'La participación no se escribe directo en la tabla'
);
SELECT is(
  public.guardar_participacion_clase('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
    jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000001', 'ejercicios', 5, 'participo_activa', true),
    jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000002', 'ejercicios', 2, 'participo_activa', false),
    jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000003', 'ejercicios', 1, 'participo_activa', true),
    jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000004', 'ejercicios', 1, 'participo_activa', true)
  )),
  '{"guardados": 2, "omitidas": 2}'::jsonb,
  'Solo las presentes reciben ejercicios y participación; ausentes y justificadas se omiten'
);
SELECT is(
  (SELECT ejercicios_completados || ' ' || participo_activa FROM public.participacion_clase
   WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND inscripcion_id = '1b000000-0000-0000-0000-000000000001'),
  '5 true',
  'Se guardan los ejercicios y la participación activa'
);
SELECT throws_ok(
  $$ SELECT public.guardar_participacion_clase('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
       jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000001', 'ejercicios', -1))) $$,
  '22023', NULL,
  'Los ejercicios no pueden ser negativos'
);

-- =============================================================================
-- 6. Podio Kahoot: tres presentes distintas (US-29)
-- =============================================================================
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2b000000-0000-0000-0000-000000000002',
       '1b000000-0000-0000-0000-000000000001', '1b000000-0000-0000-0000-000000000002', '1b000000-0000-0000-0000-000000000003') $$,
  '22023', 'El podio solo admite alumnas presentes en la clase.',
  'El podio no admite alumnas ausentes'
);
SELECT throws_ok(
  $$ SELECT public.guardar_podio_kahoot('2b000000-0000-0000-0000-000000000002',
       '1b000000-0000-0000-0000-000000000001', '1b000000-0000-0000-0000-000000000001', '1b000000-0000-0000-0000-000000000002') $$,
  '22023', 'Elige tres alumnas distintas para el podio.',
  'El podio necesita tres alumnas distintas'
);
SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['3:presente']), now() + interval '1 day');
SELECT lives_ok(
  $$ SELECT public.guardar_podio_kahoot('2b000000-0000-0000-0000-000000000002',
       '1b000000-0000-0000-0000-000000000002', '1b000000-0000-0000-0000-000000000001', '1b000000-0000-0000-0000-000000000003') $$,
  'Se guarda el podio con tres presentes distintas'
);
SELECT is(
  (SELECT string_agg(right(inscripcion_id::text, 1) || '=' || podio_kahoot, ' ' ORDER BY podio_kahoot)
   FROM public.participacion_clase WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND podio_kahoot IS NOT NULL),
  '2=1 1=2 3=3',
  'Cada alumna queda en su lugar del podio'
);
SELECT lives_ok(
  $$ SELECT public.guardar_podio_kahoot('2b000000-0000-0000-0000-000000000002',
       '1b000000-0000-0000-0000-000000000001', '1b000000-0000-0000-0000-000000000002', '1b000000-0000-0000-0000-000000000003') $$,
  'Se corrige el podio intercambiando lugares'
);
SELECT public.guardar_participacion_clase('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
  jsonb_build_object('inscripcion_id', '1b000000-0000-0000-0000-000000000001', 'ejercicios', 6, 'participo_activa', true)));
SELECT is(
  (SELECT ejercicios_completados || ' ' || podio_kahoot FROM public.participacion_clase
   WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND inscripcion_id = '1b000000-0000-0000-0000-000000000001'),
  '6 1',
  'Guardar los ejercicios no borra el podio'
);
SELECT public.guardar_asistencia_clase('2b000000-0000-0000-0000-000000000002', pg_temp.lista(ARRAY['1:ausente']), now() + interval '1 day');
SELECT is(
  (SELECT count(*)::int FROM public.participacion_clase
   WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND inscripcion_id = '1b000000-0000-0000-0000-000000000001'),
  0,
  'Si la alumna pasa a ausente, pierde su participación y su lugar en el podio'
);

-- =============================================================================
-- 7. Pase de lista de tutoras (US-33, US-34, TC-10)
-- =============================================================================
SELECT pg_temp.actuar_como('7b000000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ INSERT INTO public.asistencia_tutores (clase_id, tutor_id, estado, registrado_por)
     VALUES ('2b000000-0000-0000-0000-000000000002', auth.uid(), 'presente', auth.uid()) $$,
  '42501', NULL,
  'La asistencia de tutoras no se escribe directo en la tabla'
);
SELECT is(
  (public.guardar_asistencia_tutores('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
     jsonb_build_object('tutor_id', '9b000000-0000-0000-0000-00000000000a', 'estado', 'presente'),
     jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-000000000001', 'estado', 'presente'),
     jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-000000000002', 'estado', 'ausente'))) ->> 'guardados')::int,
  3,
  'La tutora guarda la asistencia del equipo de la clase'
);
SELECT is(
  (SELECT count(*) FILTER (WHERE estado = 'presente') || '/' || count(*) FILTER (WHERE estado = 'ausente')
   FROM public.asistencia_tutores WHERE clase_id = '2b000000-0000-0000-0000-000000000002' AND registrado_por = auth.uid()),
  '2/1',
  'Quedan presentes y ausentes con la autora del registro'
);
SELECT is(
  (public.guardar_asistencia_tutores('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
     jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-000000000002', 'estado', 'ausente'))) ->> 'sin_cambios')::int,
  1,
  'Reenviar la asistencia de tutoras no la duplica'
);
SELECT throws_ok(
  $$ SELECT public.guardar_asistencia_tutores('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
       jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-00000000000f', 'estado', 'presente'))) $$,
  '22023', 'La tutora no está asignada al curso de esta clase.',
  'Solo se registra a las tutoras asignadas al curso'
);
SELECT pg_temp.actuar_como('9b000000-0000-0000-0000-00000000000a');
SELECT is(
  (public.guardar_asistencia_tutores('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
     jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-000000000002', 'estado', 'presente')), now() + interval '1 day') ->> 'guardados')::int,
  1,
  'Gestión corrige la asistencia de una tutora que llegó tarde (US-33 escenario 3)'
);
SELECT is(
  (public.guardar_asistencia_tutores('2b000000-0000-0000-0000-000000000002', jsonb_build_array(
     jsonb_build_object('tutor_id', '7b000000-0000-0000-0000-000000000002', 'estado', 'ausente')), now() - interval '1 hour') ->> 'conservados_por_edicion_posterior')::int,
  1,
  'Un guardado anterior que llega tarde no pisa la corrección (US-34 escenario 3)'
);

-- =============================================================================
-- 8. Lectura de la clase (respeta la RLS)
-- =============================================================================
SELECT pg_temp.actuar_como('7b000000-0000-0000-0000-000000000002');
SELECT is(
  (SELECT string_agg(nombres || ':' || coalesce(estado::text, '-') || ':' || autoriza_imagen, ' ' ORDER BY apellidos)
   FROM public.lista_asistencia_clase('2b000000-0000-0000-0000-000000000002')),
  'Dana:justificada:false Berta:presente:true Carla:presente:true Ana:ausente:true',
  'La lista trae a las alumnas activas con su estado y si autorizan fotos (sin la preinscrita)'
);
SELECT is(
  (SELECT registrado_por_nombre FROM public.lista_asistencia_clase('2b000000-0000-0000-0000-000000000002') WHERE nombres = 'Carla'),
  'Tutora Dos',
  'La lista muestra quién hizo la última edición (US-15)'
);
SELECT is(
  (SELECT count(*)::int FROM public.lista_asistencia_clase('2b000000-0000-0000-0000-000000000001') WHERE estado IS NULL),
  4,
  'Una clase sin pase de lista trae a las alumnas sin estado'
);
SELECT is(
  (SELECT string_agg(nombres || ':' || estado || ':' || es_equipo_gestion, ' ' ORDER BY nombres, apellidos)
   FROM public.lista_asistencia_tutores('2b000000-0000-0000-0000-000000000002')),
  'Gestión:presente:true Tutora:presente:false Tutora:presente:false',
  'La lista de tutoras trae al equipo asignado con su estado'
);

SELECT * FROM finish();
ROLLBACK;
