BEGIN;
SELECT plan(7);

-- =============================================================================
-- Datos de prueba: un curso con 4 clases pasadas. Elena tiene una presente, una
-- ausente y dos que Gestión justifica.
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

CREATE OR REPLACE FUNCTION pg_temp.crear_usuario(p_id uuid, p_correo text) RETURNS void
LANGUAGE sql AS $$
  INSERT INTO auth.users (instance_id, id, aud, role, email)
  VALUES ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_correo);
$$;

CREATE OR REPLACE FUNCTION pg_temp.clase(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('f7200000-0000-0000-0000-00000000000' || p_n)::uuid; $$;

INSERT INTO public.sedes (id, nombre) VALUES ('f7a00000-0000-0000-0000-00000000000a', 'Sede Justificada');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('f7c00000-0000-0000-0000-000000000001', 'Curso Justificada', 'JUA');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('f7100000-0000-0000-0000-00000000000a', 'f7c00000-0000-0000-0000-000000000001', 'f7a00000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 40, public.hoy_chile() + 30);
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado)
SELECT pg_temp.clase(n), 'f7100000-0000-0000-0000-00000000000a', n, public.hoy_chile() - 7 * (5 - n), 'programada'
FROM generate_series(1, 4) AS n;

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('jua.directiva@ninaspro.cl', 'directorio', NULL, '21.170.001-7', 'Directiva', 'Justificada', NULL),
  ('jua.gestion@ninaspro.cl', 'equipo_gestion', 'f7a00000-0000-0000-0000-00000000000a', '21.170.002-5', 'Gestión', 'Justificada', NULL),
  ('jua.tutora@ninaspro.cl', 'tutora', 'f7a00000-0000-0000-0000-00000000000a', '21.170.003-3', 'Tutora', 'Justificada', NULL);
SELECT pg_temp.crear_usuario('97000000-0000-0000-0000-00000000000d', 'jua.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('97000000-0000-0000-0000-00000000000a', 'jua.gestion@ninaspro.cl');
SELECT pg_temp.crear_usuario('77000000-0000-0000-0000-000000000001', 'jua.tutora@ninaspro.cl');
INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada) VALUES
  ('77000000-0000-0000-0000-000000000001', '2025-03-01', true);
INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
  ('f7100000-0000-0000-0000-00000000000a', '77000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-00000000000d');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('f7d00000-0000-0000-0000-000000000001', 'Apoderada', 'Justificada', 'apoderada.jua@correo.cl', '+56 9 4444 1111');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a7000000-0000-0000-0000-000000000001', '27.170.001-6', 'Elena', 'Justificada', '2011-01-01', 'f7d00000-0000-0000-0000-000000000001');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, autoriza_uso_imagen_general, registrado_por)
VALUES ('a7000000-0000-0000-0000-000000000001', 'f7d00000-0000-0000-0000-000000000001', 'otorgada', 'otorgada', '97000000-0000-0000-0000-00000000000d');
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id, estado, fecha_inscripcion) VALUES
  ('f7300000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'f7100000-0000-0000-0000-00000000000a', 'activa', public.hoy_chile() - 40);
INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por) VALUES
  ('elena.jua@correo.cl', 'alumna', 'f7a00000-0000-0000-0000-00000000000a', 'a7000000-0000-0000-0000-000000000001', NULL);
SELECT pg_temp.crear_usuario('57000000-0000-0000-0000-000000000001', 'elena.jua@correo.cl');

-- Pase de lista: presente en la 1 y ausente en la 2, 3 y 4
SELECT pg_temp.actuar_como('77000000-0000-0000-0000-000000000001');
SELECT public.guardar_asistencia_clase(pg_temp.clase(n), jsonb_build_array(jsonb_build_object(
  'inscripcion_id', 'f7300000-0000-0000-0000-000000000001', 'estado', CASE WHEN n = 1 THEN 'presente' ELSE 'ausente' END)))
FROM generate_series(1, 4) AS n;

-- Gestión justifica la 3 y la 4
SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000a');
SELECT public.registrar_justificativo(pg_temp.clase(n), 'f7300000-0000-0000-0000-000000000001', 'salud', 'Aviso de la apoderada.')
FROM generate_series(3, 4) AS n;

-- =============================================================================
-- 1. La justificada cuenta como ausente
-- =============================================================================
SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000d', 'aal2');
SELECT is(
  (SELECT clases_asistidas || '/' || clases_computables FROM public.nomina_alumnas
   WHERE inscripcion_id = 'f7300000-0000-0000-0000-000000000001'),
  '1/4',
  'En la nómina, las 2 clases justificadas no suman a las asistidas'
);
SELECT results_eq(
  $$ SELECT clases_computables, clases_asistidas, porcentaje FROM public.asistencia_inscripcion('f7300000-0000-0000-0000-000000000001') $$,
  $$ VALUES (4, 1, 25.0::numeric) $$,
  'El porcentaje de la inscripción cuenta solo las presentes'
);
SELECT is(
  (public.exportar_reporte('nomina', p_instancia_id => 'f7100000-0000-0000-0000-00000000000a') -> 'filas' -> 0 ->> 11),
  '1',
  'La nómina exportada también cuenta solo las presentes'
);

-- =============================================================================
-- 2. El portal: la meta baja al 70 % una sola vez
-- =============================================================================
SELECT pg_temp.actuar_como('57000000-0000-0000-0000-000000000001');
SELECT is(
  (SELECT row(a ->> 'asistidas', a ->> 'justificadas', a ->> 'porcentaje')::text
   FROM (SELECT public.portal_alumna() -> 'asistencia' AS a) x),
  row('1', '2', '25.0')::text,
  'En el portal, sin ejercicios, las justificadas siguen como ausentes'
);
SELECT is(
  (SELECT row(a ->> 'umbral', a ->> 'umbral_reducido', a ->> 'justificativos_aceptados')::text
   FROM (SELECT public.portal_alumna() -> 'asistencia' AS a) x),
  row('70', 'true', '2')::text,
  'Con 2 justificativos aceptados la meta baja al 70 %, no más'
);

-- Con 25 ejercicios recupera una de las justificadas (US-25 E3)
RESET role;
INSERT INTO public.participacion_clase (clase_id, inscripcion_id, ejercicios_completados, registrado_por)
VALUES (pg_temp.clase(1), 'f7300000-0000-0000-0000-000000000001', 25, '77000000-0000-0000-0000-000000000001');
SELECT pg_temp.actuar_como('57000000-0000-0000-0000-000000000001');
SELECT is(
  (SELECT row(a ->> 'recuperadas', a ->> 'asistidas', a ->> 'porcentaje')::text
   FROM (SELECT public.portal_alumna() -> 'asistencia' AS a) x),
  row('1', '2', '50.0')::text,
  'Los ejercicios son la única forma de contar una justificada como presente'
);

SELECT pg_temp.actuar_como('97000000-0000-0000-0000-00000000000d', 'aal2');
SELECT is(
  (SELECT clases_asistidas FROM public.nomina_alumnas WHERE inscripcion_id = 'f7300000-0000-0000-0000-000000000001'),
  1,
  'La nómina cuenta asistencia real: los ejercicios no cambian sus presentes'
);

SELECT * FROM finish();
ROLLBACK;
