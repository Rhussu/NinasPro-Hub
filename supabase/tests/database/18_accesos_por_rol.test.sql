BEGIN;
SELECT plan(20);

-- =============================================================================
-- Ajustes como acceso a todo lo de cada perfil (PR 8). La app muestra en
-- Ajustes solo lo que cada rol puede hacer según la base; este archivo fija
-- los permisos en que se apoyan las entradas nuevas:
--   - La Directiva abre lo de Gestión en todas las sedes: lee y resuelve
--     justificativos, ingresa el aviso de una apoderada, atiende alertas y
--     asigna los roles de la clase en cualquier sede.
--   - Gestión ve el voluntariado de su sede en solo lectura y no opera otra sede.
--   - La tutora no lee la tabla de justificativos (ve el estado en el pase de lista).
--
-- Datos: sedes A y B con un curso cada una y dos clases pasadas; Gestión de la
-- sede A, una tutora en cada sede y una alumna en cada sede.
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

CREATE OR REPLACE FUNCTION pg_temp.como_directiva() RETURNS void
LANGUAGE sql AS $$ SELECT pg_temp.actuar_como('98000000-0000-0000-0000-00000000000d', 'aal2'); $$;

CREATE OR REPLACE FUNCTION pg_temp.como_gestion_a() RETURNS void
LANGUAGE sql AS $$ SELECT pg_temp.actuar_como('98000000-0000-0000-0000-00000000000a'); $$;

CREATE OR REPLACE FUNCTION pg_temp.como_tutora_a() RETURNS void
LANGUAGE sql AS $$ SELECT pg_temp.actuar_como('78000000-0000-0000-0000-000000000001'); $$;

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

-- Clase N de la sede S ('a' o 'b')
CREATE OR REPLACE FUNCTION pg_temp.clase(p_sede text, p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('f820000' || p_sede || '-0000-0000-0000-00000000000' || p_n)::uuid; $$;

CREATE OR REPLACE FUNCTION pg_temp.estado_justificativo(p_id uuid) RETURNS text
LANGUAGE sql SECURITY DEFINER AS $$ SELECT estado::text FROM public.justificativos_inasistencia WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION pg_temp.roles_de(p_clase uuid, p_tutora uuid) RETURNS bigint
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*) FROM public.tareas_semanales_tutores WHERE clase_id = p_clase AND tutor_id = p_tutora;
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('f8a00000-0000-0000-0000-00000000000a', 'Sede Accesos A'),
  ('f8b00000-0000-0000-0000-00000000000b', 'Sede Accesos B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('f8c00000-0000-0000-0000-000000000001', 'Curso Accesos', 'ACC');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('f8100000-0000-0000-0000-00000000000a', 'f8c00000-0000-0000-0000-000000000001', 'f8a00000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60),
  ('f8100000-0000-0000-0000-00000000000b', 'f8c00000-0000-0000-0000-000000000001', 'f8b00000-0000-0000-0000-00000000000b', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado) VALUES
  (pg_temp.clase('a', 1), 'f8100000-0000-0000-0000-00000000000a', 1, public.hoy_chile() - 14, 'programada'),
  (pg_temp.clase('a', 2), 'f8100000-0000-0000-0000-00000000000a', 2, public.hoy_chile() - 7, 'programada'),
  (pg_temp.clase('b', 1), 'f8100000-0000-0000-0000-00000000000b', 1, public.hoy_chile() - 14, 'programada'),
  (pg_temp.clase('b', 2), 'f8100000-0000-0000-0000-00000000000b', 2, public.hoy_chile() - 7, 'programada');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('acc.directiva@ninaspro.cl', 'directorio', NULL, '21.180.001-1', 'Directiva', 'Accesos', NULL),
  ('acc.gestion.a@ninaspro.cl', 'equipo_gestion', 'f8a00000-0000-0000-0000-00000000000a', '21.180.002-K', 'Gestión', 'A', NULL),
  ('acc.tutora.a@ninaspro.cl', 'tutora', 'f8a00000-0000-0000-0000-00000000000a', '21.180.003-8', 'Tutora', 'A', NULL),
  ('acc.tutora.b@ninaspro.cl', 'tutora', 'f8b00000-0000-0000-0000-00000000000b', '21.180.004-6', 'Tutora', 'B', NULL);
SELECT pg_temp.crear_usuario('98000000-0000-0000-0000-00000000000d', 'acc.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('98000000-0000-0000-0000-00000000000a', 'acc.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('78000000-0000-0000-0000-000000000001', 'acc.tutora.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('78000000-0000-0000-0000-000000000002', 'acc.tutora.b@ninaspro.cl');
INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada) VALUES
  ('98000000-0000-0000-0000-00000000000a', '2025-03-01', true),
  ('78000000-0000-0000-0000-000000000001', '2025-03-01', true),
  ('78000000-0000-0000-0000-000000000002', '2025-03-01', true);
INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
  ('f8100000-0000-0000-0000-00000000000a', '78000000-0000-0000-0000-000000000001', '98000000-0000-0000-0000-00000000000d'),
  ('f8100000-0000-0000-0000-00000000000b', '78000000-0000-0000-0000-000000000002', '98000000-0000-0000-0000-00000000000d');
INSERT INTO public.rol_tarea_tutor (id, codigo, nombre) VALUES
  ('f8300000-0000-0000-0000-000000000001', 'acc_presentar', 'Acc Presentar');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono, parentesco) VALUES
  ('f8d00000-0000-0000-0000-000000000001', 'Paula', 'Apoderada', 'paula.acc@correo.cl', '+56 9 3333 2222', 'Madre');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a8000000-0000-0000-0000-00000000000a', '27.180.001-0', 'Ana', 'Accesos A', '2011-01-01', 'f8d00000-0000-0000-0000-000000000001'),
  ('a8000000-0000-0000-0000-00000000000b', '27.180.002-9', 'Berta', 'Accesos B', '2011-01-01', 'f8d00000-0000-0000-0000-000000000001');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, autoriza_uso_imagen_general, registrado_por)
SELECT id, 'f8d00000-0000-0000-0000-000000000001', 'otorgada', 'otorgada', '98000000-0000-0000-0000-00000000000d'
FROM public.alumnas WHERE id::text LIKE 'a8000000-%';
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id, estado, fecha_inscripcion) VALUES
  ('f8400000-0000-0000-0000-00000000000a', 'a8000000-0000-0000-0000-00000000000a', 'f8100000-0000-0000-0000-00000000000a', 'activa', public.hoy_chile() - 30),
  ('f8400000-0000-0000-0000-00000000000b', 'a8000000-0000-0000-0000-00000000000b', 'f8100000-0000-0000-0000-00000000000b', 'activa', public.hoy_chile() - 30);

-- Un justificativo pendiente y una alerta sin atender en cada sede
INSERT INTO public.justificativos_inasistencia (id, clase_id, inscripcion_id, motivo, explicacion, subido_por) VALUES
  ('f8500000-0000-0000-0000-00000000000a', pg_temp.clase('a', 1), 'f8400000-0000-0000-0000-00000000000a', 'salud', 'Estuvo con fiebre.', '98000000-0000-0000-0000-00000000000d'),
  ('f8500000-0000-0000-0000-00000000000b', pg_temp.clase('b', 1), 'f8400000-0000-0000-0000-00000000000b', 'salud', 'Estuvo con fiebre.', '98000000-0000-0000-0000-00000000000d');
INSERT INTO public.alertas_desercion (id, inscripcion_id, clase_id) VALUES
  ('f8600000-0000-0000-0000-00000000000a', 'f8400000-0000-0000-0000-00000000000a', pg_temp.clase('a', 2)),
  ('f8600000-0000-0000-0000-00000000000b', 'f8400000-0000-0000-0000-00000000000b', pg_temp.clase('b', 2));

-- =============================================================================
-- 1. Justificativos: la Directiva en todas las sedes; Gestión, solo la suya
-- =============================================================================
SELECT pg_temp.como_directiva();
SELECT is(
  (SELECT count(*) FROM public.justificativos_detalle WHERE id::text LIKE 'f8500000-%'),
  2::bigint,
  'La Directiva ve la bandeja de justificativos de todas las sedes'
);
SELECT is(
  (SELECT count(DISTINCT sede_nombre) FROM public.justificativos_detalle WHERE id::text LIKE 'f8500000-%'),
  2::bigint,
  'Cada justificativo trae su sede para filtrarlo en la bandeja'
);

SELECT pg_temp.como_gestion_a();
SELECT is(
  (SELECT count(*) FROM public.justificativos_detalle WHERE id::text LIKE 'f8500000-%'),
  1::bigint,
  'Gestión ve solo los justificativos de su sede'
);
SELECT throws_ok(
  $$ SELECT public.resolver_justificativo('f8500000-0000-0000-0000-00000000000b', true) $$,
  '42501', NULL,
  'Gestión no resuelve justificativos de otra sede'
);

SELECT pg_temp.como_tutora_a();
SELECT is(
  (SELECT count(*) FROM public.justificativos_detalle WHERE id::text LIKE 'f8500000-%'),
  0::bigint,
  'La tutora no lee la bandeja: no tiene la entrada de justificativos en Ajustes'
);

SELECT pg_temp.como_directiva();
SELECT lives_ok(
  $$ SELECT public.resolver_justificativo('f8500000-0000-0000-0000-00000000000b', true) $$,
  'La Directiva aprueba un justificativo de la sede B'
);
SELECT pg_temp.como_sistema();
SELECT is(pg_temp.estado_justificativo('f8500000-0000-0000-0000-00000000000b'), 'aceptado', 'Queda aprobado');

SELECT pg_temp.como_directiva();
SELECT lives_ok(
  $$ SELECT public.registrar_justificativo(
       pg_temp.clase('a', 2), 'f8400000-0000-0000-0000-00000000000a',
       'transporte', 'La apoderada avisó por teléfono.') $$,
  'La Directiva ingresa el aviso de una apoderada en la sede A'
);
SELECT is(
  (SELECT estado::text FROM public.justificativos_detalle
   WHERE clase_id = pg_temp.clase('a', 2) AND inscripcion_id = 'f8400000-0000-0000-0000-00000000000a'),
  'aceptado',
  'El aviso que ingresa la Directiva queda aprobado, como el de Gestión'
);

-- =============================================================================
-- 2. Alertas de deserción: la Directiva en todas las sedes
-- =============================================================================
SELECT is(
  (SELECT count(*) FROM public.alertas_detalle WHERE id::text LIKE 'f8600000-%'),
  2::bigint,
  'La Directiva ve las alertas de todas las sedes'
);
SELECT is(
  (SELECT count(DISTINCT sede_id) FROM public.alertas_detalle WHERE id::text LIKE 'f8600000-%'),
  2::bigint,
  'Cada alerta trae su sede para filtrarla'
);
SELECT lives_ok(
  $$ SELECT public.registrar_contacto_alerta('f8600000-0000-0000-0000-00000000000b', 'Llamé a la apoderada.') $$,
  'La Directiva registra el contacto de una alerta de la sede B'
);

SELECT pg_temp.como_gestion_a();
SELECT is(
  (SELECT count(*) FROM public.alertas_detalle WHERE id::text LIKE 'f8600000-%'),
  1::bigint,
  'Gestión ve solo las alertas de su sede'
);

-- =============================================================================
-- 3. Roles de la clase: la Directiva en cualquier sede
-- =============================================================================
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora(
       pg_temp.clase('b', 2), '78000000-0000-0000-0000-000000000002',
       ARRAY['f8300000-0000-0000-0000-000000000001']::uuid[]) $$,
  '42501', NULL,
  'Gestión no asigna roles en una clase de otra sede'
);

SELECT pg_temp.como_directiva();
SELECT lives_ok(
  $$ SELECT public.guardar_roles_tutora(
       pg_temp.clase('b', 2), '78000000-0000-0000-0000-000000000002',
       ARRAY['f8300000-0000-0000-0000-000000000001']::uuid[]) $$,
  'La Directiva asigna los roles de la clase en la sede B'
);
SELECT pg_temp.como_sistema();
SELECT is(
  pg_temp.roles_de(pg_temp.clase('b', 2), '78000000-0000-0000-0000-000000000002'),
  1::bigint,
  'La tutora de la sede B queda con su rol'
);

-- =============================================================================
-- 4. Voluntariado: Gestión ve su sede en solo lectura
-- =============================================================================
SELECT pg_temp.como_directiva();
SELECT is(
  (SELECT count(*) FROM public.voluntariado WHERE correo LIKE 'acc.%@ninaspro.cl'),
  3::bigint,
  'La Directiva ve las fichas de todas las sedes'
);

SELECT pg_temp.como_gestion_a();
SELECT is(
  (SELECT count(*) FROM public.voluntariado WHERE correo LIKE 'acc.%@ninaspro.cl'),
  2::bigint,
  'Gestión ve las fichas de su sede'
);
SELECT is(
  (SELECT count(*) FROM public.voluntariado WHERE perfil_id = '78000000-0000-0000-0000-000000000002'),
  0::bigint,
  'Gestión no ve las fichas de otra sede'
);
SELECT throws_ok(
  $$ SELECT public.registrar_adhesion_voluntaria(
       (SELECT id FROM public.voluntariado WHERE perfil_id = '78000000-0000-0000-0000-000000000001'), false) $$,
  '42501', NULL,
  'Gestión no cambia el voluntariado: su entrada en Ajustes es de solo lectura'
);

SELECT * FROM finish();
ROLLBACK;
