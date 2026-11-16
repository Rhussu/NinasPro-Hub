BEGIN;
SELECT plan(43);

-- =============================================================================
-- Datos de prueba: Directiva, Gestión y Tutora de la sede A, Gestión de la sede B
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

INSERT INTO public.sedes (id, nombre) VALUES
  ('a7000000-0000-0000-0000-00000000000a', 'Sede Calendario A'),
  ('b7000000-0000-0000-0000-00000000000b', 'Sede Calendario B');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('cal.directiva@ninaspro.cl', 'directorio', NULL, '21.711.111-1', 'Directiva', 'Calendario', NULL),
  ('cal.gestion.a@ninaspro.cl', 'equipo_gestion', 'a7000000-0000-0000-0000-00000000000a', '22.722.222-2', 'Gestión', 'A', NULL),
  ('cal.gestion.b@ninaspro.cl', 'equipo_gestion', 'b7000000-0000-0000-0000-00000000000b', '23.733.333-3', 'Gestión', 'B', NULL),
  ('cal.tutora.a@ninaspro.cl', 'tutora', 'a7000000-0000-0000-0000-00000000000a', '24.744.444-4', 'Tutora', 'A', NULL);
SELECT pg_temp.crear_usuario('d7000000-0000-0000-0000-000000000001', 'cal.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('97000000-0000-0000-0000-00000000000a', 'cal.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('97000000-0000-0000-0000-00000000000b', 'cal.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('77000000-0000-0000-0000-00000000000a', 'cal.tutora.a@ninaspro.cl');
INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
VALUES (gen_random_uuid(), 'd7000000-0000-0000-0000-000000000001', 'NiñasPro Hub', 'totp', 'verified', now(), now());

-- =============================================================================
-- 1. Catálogo de sedes y cursos (US-01)
-- =============================================================================
SELECT pg_temp.actuar_como('d7000000-0000-0000-0000-000000000001', 'aal2');
SELECT lives_ok(
  $$ INSERT INTO public.sedes (nombre, modalidad, institucion_anfitriona)
     VALUES ('  Sede   Concepción Test ', 'presencial', 'Universidad de Concepción') $$,
  'La Directiva crea una sede'
);
SELECT is(
  (SELECT activa FROM public.sedes WHERE nombre = 'Sede Concepción Test'),
  true,
  'La sede queda activa y con el nombre sin espacios sobrantes'
);
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('sede concepción test') $$,
  '23505', NULL,
  'No se repite el nombre de una sede aunque cambien las mayúsculas'
);
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('   ') $$,
  '23514', NULL,
  'La sede necesita un nombre'
);
SELECT lives_ok(
  $$ INSERT INTO public.cursos (id, codigo, nombre) VALUES ('c7000000-0000-0000-0000-000000000001', ' pcb-cal ', 'Programación Calendario') $$,
  'La Directiva agrega un curso al catálogo'
);
SELECT is(
  (SELECT codigo FROM public.cursos WHERE id = 'c7000000-0000-0000-0000-000000000001')::text,
  'PCB-CAL',
  'El código del curso se guarda en mayúsculas'
);
SELECT throws_ok(
  $$ INSERT INTO public.cursos (codigo, nombre) VALUES ('Pcb-Cal', 'Otro curso') $$,
  '23505', NULL,
  'El código institucional del curso es único'
);
SELECT throws_ok(
  $$ INSERT INTO public.cursos (codigo, nombre) VALUES ('VACIO-CAL', '  ') $$,
  '23514', NULL,
  'El curso necesita un nombre'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ INSERT INTO public.sedes (nombre) VALUES ('Sede Gestión Test') $$,
  '42501', NULL,
  'Gestión no crea sedes (403)'
);
SELECT throws_ok(
  $$ INSERT INTO public.cursos (codigo, nombre) VALUES ('GES-CAL', 'Curso de Gestión') $$,
  '42501', NULL,
  'Gestión no crea cursos (403)'
);
SELECT is_empty(
  $$ UPDATE public.cursos SET nombre = 'Cambiado' WHERE id = 'c7000000-0000-0000-0000-000000000001' RETURNING id $$,
  'Gestión no modifica el catálogo de cursos'
);

-- =============================================================================
-- 2. Programación de instancias y generación de sesiones (US-02)
-- =============================================================================
SELECT is(
  (SELECT count(*)::int FROM public.fechas_sesiones('2026-08-01', '2026-11-28', 6)),
  18,
  'Entre el 1 de agosto y el 28 de noviembre de 2026 hay 18 sábados'
);
SELECT is(
  (SELECT count(*)::int FROM public.fechas_sesiones('2026-08-03', '2026-08-28', 6)),
  3,
  'Si el inicio no cae en el día elegido se parte desde el siguiente'
);
SELECT is(public.periodo_academico_de('2026-08-01'), '2026-2', 'Agosto pertenece al segundo semestre');

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ SELECT public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-00000000000a', '2026-08-01', '2026-11-28', 6) $$,
  '42501', NULL,
  'Gestión no programa instancias (403)'
);

SELECT pg_temp.actuar_como('d7000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(
  (public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-00000000000a', '2026-08-01', '2026-11-28', 6) ->> 'total_sesiones')::int,
  18,
  'La Directiva programa la instancia y se generan 18 sesiones'
);

SELECT pg_temp.como_sistema();
CREATE TEMP TABLE _inst_a AS
  SELECT id FROM public.instancias_curso
  WHERE curso_id = 'c7000000-0000-0000-0000-000000000001' AND sede_id = 'a7000000-0000-0000-0000-00000000000a';
GRANT SELECT ON _inst_a TO authenticated;

SELECT results_eq(
  $$ SELECT count(*)::int, min(numero_sesion), max(numero_sesion),
            bool_and(estado = 'programada'), bool_and(extract(isodow FROM fecha) = 6)
     FROM public.clases WHERE instancia_curso_id = (SELECT id FROM _inst_a) $$,
  $$ VALUES (18, 1, 18, true, true) $$,
  'Las sesiones quedan programadas, numeradas del 1 al 18 y todas en sábado'
);
SELECT is(
  (SELECT periodo_academico || ' ' || seccion || ' ' || dia_semana FROM public.instancias_curso WHERE id = (SELECT id FROM _inst_a)),
  '2026-2 1 Sábado',
  'La instancia guarda su período, su sección y el día de clases'
);

SELECT pg_temp.actuar_como('d7000000-0000-0000-0000-000000000001', 'aal2');
SELECT throws_ok(
  $$ SELECT public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-00000000000b', '2026-11-28', '2026-08-01', 6) $$,
  '22023',
  'La fecha de término debe ser posterior a la de inicio.',
  'Se rechaza una fecha de término anterior al inicio'
);
SELECT throws_ok(
  $$ SELECT public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-00000000000b', '2026-08-01', '2026-08-01', 6) $$,
  '22023',
  'La fecha de término debe ser posterior a la de inicio.',
  'Se rechaza una fecha de término igual al inicio'
);
SELECT is_empty(
  $$ SELECT 1 FROM public.instancias_curso WHERE sede_id = 'b7000000-0000-0000-0000-00000000000b' $$,
  'Con fechas inválidas no se crea la instancia ni sus clases'
);
SELECT throws_ok(
  $$ SELECT public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-00000000000a', '2026-08-01', '2026-11-28', 6) $$,
  'PT409', NULL,
  'Una instancia repetida avisa la duplicidad (409) y no se crea'
);
SELECT is(
  (public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-00000000000a', '2026-08-03', '2026-11-27', 5, '18:00', '20:00', true) ->> 'seccion')::int,
  2,
  'Al confirmar, la repetida se crea como sección paralela'
);
SELECT throws_ok(
  $$ INSERT INTO public.instancias_curso (curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino)
     VALUES ('c7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-00000000000b', '2026-2', '2026-08-01', '2026-11-28') $$,
  '42501', NULL,
  'Ni la Directiva inserta instancias sin generar su calendario'
);
SELECT lives_ok(
  $$ SELECT public.crear_instancia_curso('c7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-00000000000b', '2026-08-01', '2026-11-28', 6) $$,
  'La Directiva programa el mismo curso en la sede B'
);

-- =============================================================================
-- 3. Calendario de la sede y suspensión de clases (US-03)
-- =============================================================================
SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT count(DISTINCT ic.sede_id)::int FROM public.clases c JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
   WHERE ic.curso_id = 'c7000000-0000-0000-0000-000000000001'),
  1,
  'Gestión de la sede A solo ve el calendario de su sede'
);

SELECT pg_temp.actuar_como('77000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ UPDATE public.clases SET estado = 'suspendida', motivo_suspension = 'Feriado'
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3 $$,
  '42501', NULL,
  'La tutora no suspende clases'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ UPDATE public.clases SET estado = 'suspendida'
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3 $$,
  '22023',
  'Indica el motivo de la suspensión.',
  'Suspender exige un motivo'
);
SELECT lives_ok(
  $$ UPDATE public.clases SET estado = 'suspendida', motivo_suspension = ' Feriado 18 de septiembre '
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3 $$,
  'Gestión suspende una clase de su sede'
);
SELECT is(
  (SELECT estado::text || ' / ' || motivo_suspension FROM public.clases WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3),
  'suspendida / Feriado 18 de septiembre',
  'La clase queda suspendida con su motivo'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000b');
SELECT is_empty(
  $$ UPDATE public.clases SET estado = 'suspendida', motivo_suspension = 'Ajena'
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 4 RETURNING id $$,
  'Gestión de otra sede no suspende clases ajenas'
);

-- Fichas de alumna para probar la asistencia
SELECT pg_temp.como_sistema();
INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('a7b00000-0000-0000-0000-000000000001', 'Marta', 'Calendario', 'marta.cal@correo.cl', '+56911111111');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a7a00000-0000-0000-0000-000000000001', '32.000.001-1', 'Clara', 'Calendario', '2011-03-03', 'a7b00000-0000-0000-0000-000000000001');
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id, estado)
  SELECT 'a7c00000-0000-0000-0000-000000000001', 'a7a00000-0000-0000-0000-000000000001', id, 'activa' FROM _inst_a;

SELECT throws_ok(
  $$ INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
     SELECT c.id, 'a7c00000-0000-0000-0000-000000000001', 'presente', '77000000-0000-0000-0000-00000000000a'
     FROM public.clases c WHERE c.instancia_curso_id = (SELECT id FROM _inst_a) AND c.numero_sesion = 3 $$,
  '22023', NULL,
  'Una clase suspendida no admite asistencia'
);
SELECT results_eq(
  $$ SELECT clases_computables, porcentaje FROM public.asistencia_inscripcion('a7c00000-0000-0000-0000-000000000001') $$,
  $$ VALUES (0, NULL::numeric) $$,
  'Sin clases realizadas el denominador es 0 y no hay porcentaje'
);

-- Sesiones 1 y 2 realizadas (presente y ausente); la 3 sigue suspendida
UPDATE public.clases SET estado = 'realizada'
WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion IN (1, 2);
INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
SELECT c.id, 'a7c00000-0000-0000-0000-000000000001',
       CASE c.numero_sesion WHEN 1 THEN 'presente' ELSE 'ausente' END::public.estado_asistencia,
       '77000000-0000-0000-0000-00000000000a'
FROM public.clases c WHERE c.instancia_curso_id = (SELECT id FROM _inst_a) AND c.numero_sesion IN (1, 2);

SELECT results_eq(
  $$ SELECT clases_computables, clases_asistidas, porcentaje FROM public.asistencia_inscripcion('a7c00000-0000-0000-0000-000000000001') $$,
  $$ VALUES (2, 1, 50.0::numeric) $$,
  'La clase suspendida no cuenta en el porcentaje de asistencia'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ UPDATE public.clases SET estado = 'suspendida', motivo_suspension = 'Tarde'
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 1 $$,
  '22023', NULL,
  'No se suspende una clase que ya se realizó'
);
SELECT lives_ok(
  $$ UPDATE public.clases SET estado = 'programada'
     WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3 $$,
  'Gestión reanuda una clase suspendida'
);
SELECT is(
  (SELECT motivo_suspension FROM public.clases WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND numero_sesion = 3),
  NULL,
  'Al reanudar se borra el motivo de la suspensión'
);

-- =============================================================================
-- 4. Sesión especial o de recuperación (US-03 escenario 3)
-- =============================================================================
SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000b');
SELECT throws_ok(
  $$ SELECT public.agregar_sesion_especial((SELECT id FROM _inst_a), '2026-12-02', '15:00', '18:00') $$,
  '42501', NULL,
  'Gestión de otra sede no agrega sesiones'
);

SELECT pg_temp.actuar_como('77000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ SELECT public.agregar_sesion_especial((SELECT id FROM _inst_a), '2026-12-02', '15:00', '18:00') $$,
  '42501', NULL,
  'La tutora no agrega sesiones'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT numero_sesion || ' ' || es_especial || ' ' || hora_inicio
   FROM public.agregar_sesion_especial((SELECT id FROM _inst_a), '2026-12-02', '15:00', '18:00')),
  '19 true 15:00:00',
  'Gestión agrega una sesión especial con su fecha y hora, a continuación de la última'
);
SELECT throws_ok(
  $$ SELECT public.agregar_sesion_especial((SELECT id FROM _inst_a), '2026-12-02', '10:00', '12:00') $$,
  '22023', NULL,
  'No se agregan dos sesiones el mismo día'
);
SELECT throws_ok(
  $$ INSERT INTO public.clases (instancia_curso_id, numero_sesion, fecha) SELECT id, 50, '2026-12-20' FROM _inst_a $$,
  '42501', NULL,
  'Las sesiones solo se agregan con la RPC'
);

SELECT pg_temp.actuar_como('77000000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT estado::text FROM public.clases WHERE instancia_curso_id = (SELECT id FROM _inst_a) AND fecha = '2026-12-02'),
  'programada',
  'La tutora del curso ve de inmediato la sesión especial programada'
);

SELECT * FROM finish();
ROLLBACK;
