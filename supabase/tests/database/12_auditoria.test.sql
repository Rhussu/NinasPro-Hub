BEGIN;
SELECT plan(13);

-- =============================================================================
-- Datos de prueba: una clase de hoy con una alumna activa, una tutora, Gestión
-- y la Directiva
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

CREATE OR REPLACE FUNCTION pg_temp.marcar(p_estado text, p_guardado_en timestamptz DEFAULT NULL) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT public.guardar_asistencia_clase(
    '2c000000-0000-0000-0000-000000000001',
    jsonb_build_array(jsonb_build_object('inscripcion_id', '1c000000-0000-0000-0000-000000000001', 'estado', p_estado)),
    p_guardado_en
  );
$$;

INSERT INTO public.sedes (id, nombre) VALUES ('ac000000-0000-0000-0000-00000000000a', 'Sede Auditoría');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('cc000000-0000-0000-0000-000000000001', 'Curso Auditoría', 'AUD');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('0c000000-0000-0000-0000-00000000000a', 'cc000000-0000-0000-0000-000000000001', 'ac000000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha) VALUES
  ('2c000000-0000-0000-0000-000000000001', '0c000000-0000-0000-0000-00000000000a', 1, public.hoy_chile());

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('aud.directiva@ninaspro.cl', 'directorio', NULL, '21.511.111-1', 'Directiva', 'Auditoría', NULL),
  ('aud.gestion@ninaspro.cl', 'equipo_gestion', 'ac000000-0000-0000-0000-00000000000a', '22.522.222-2', 'Gestión', 'Auditoría', NULL),
  ('aud.tutora@ninaspro.cl', 'tutora', 'ac000000-0000-0000-0000-00000000000a', '23.533.333-3', 'Tutora', 'Auditoría', NULL);
SELECT pg_temp.crear_usuario('dc000000-0000-0000-0000-000000000001', 'aud.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('9c000000-0000-0000-0000-000000000001', 'aud.gestion@ninaspro.cl');
SELECT pg_temp.crear_usuario('7c000000-0000-0000-0000-000000000001', 'aud.tutora@ninaspro.cl');
INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
VALUES (gen_random_uuid(), 'dc000000-0000-0000-0000-000000000001', 'NiñasPro Hub', 'totp', 'verified', now(), now());

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('ad000000-0000-0000-0000-0000000000c1', 'Apoderada', 'Auditoría', 'apoderada.aud@correo.cl', '+56 9 2222 2222');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a1000000-0000-0000-0000-0000000000c1', '27.000.001-5', 'Alumna', 'Auditada', '2011-01-01', 'ad000000-0000-0000-0000-0000000000c1');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, registrado_por) VALUES
  ('a1000000-0000-0000-0000-0000000000c1', 'ad000000-0000-0000-0000-0000000000c1', 'otorgada', '9c000000-0000-0000-0000-000000000001');
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id) VALUES
  ('1c000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-0000000000c1', '0c000000-0000-0000-0000-00000000000a');

-- Los eventos de esta prueba
CREATE TEMP VIEW _eventos WITH (security_invoker = true) AS
  SELECT * FROM public.auditoria_cambios_datos
  WHERE tabla_afectada = 'asistencia_alumnas'
    AND (valor_nuevo ->> 'clase_id' = '2c000000-0000-0000-0000-000000000001'
      OR valor_anterior ->> 'clase_id' = '2c000000-0000-0000-0000-000000000001');
GRANT SELECT ON _eventos TO authenticated;

-- =============================================================================
-- 1. Registro automático de cada cambio (US-15)
-- =============================================================================
SELECT pg_temp.actuar_como('7c000000-0000-0000-0000-000000000001');
SELECT pg_temp.marcar('ausente');
SELECT pg_temp.marcar('ausente');
SELECT pg_temp.marcar('presente', now() + interval '1 day');

SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT string_agg(accion::text, ' ' ORDER BY fecha_hora, accion) FROM _eventos),
  'insert update',
  'Se registran el alta y la corrección; reenviar la misma lista no deja eventos'
);
SELECT is(
  (SELECT (valor_anterior ->> 'estado') || ' -> ' || (valor_nuevo ->> 'estado') FROM _eventos WHERE accion = 'update'),
  'ausente -> presente',
  'La corrección guarda el valor anterior y el nuevo (llegada tardía, US-15 escenario 1)'
);
SELECT is(
  (SELECT count(*)::int FROM _eventos WHERE ejecutado_por = '7c000000-0000-0000-0000-000000000001'),
  2,
  'Cada evento queda con la autora del cambio'
);

SELECT pg_temp.actuar_como('9c000000-0000-0000-0000-000000000001');
SELECT pg_temp.marcar('justificada', now() + interval '2 days');
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT ejecutado_por FROM _eventos WHERE valor_nuevo ->> 'estado' = 'justificada'),
  '9c000000-0000-0000-0000-000000000001'::uuid,
  'La edición de Gestión queda auditada con su autora (US-15 escenario 3)'
);

UPDATE public.asistencia_alumnas SET estado = 'presente'
WHERE clase_id = '2c000000-0000-0000-0000-000000000001';
SELECT is(
  (SELECT count(*)::int FROM _eventos WHERE ejecutado_por IS NULL AND valor_nuevo ->> 'estado' = 'presente'),
  1,
  'Los cambios del sistema quedan con autora NULL'
);
UPDATE public.asistencia_alumnas SET updated_at = now() - interval '1 hour'
WHERE clase_id = '2c000000-0000-0000-0000-000000000001';
SELECT is(
  (SELECT count(*)::int FROM _eventos),
  4,
  'Tocar solo la marca de tiempo no deja eventos'
);
DELETE FROM public.asistencia_alumnas WHERE clase_id = '2c000000-0000-0000-0000-000000000001';
SELECT is(
  (SELECT valor_anterior ->> 'estado' FROM _eventos WHERE accion = 'delete'),
  'presente',
  'Al borrar un registro se conserva su último valor'
);

-- =============================================================================
-- 2. Inmutabilidad y acceso (US-23, US-24)
-- =============================================================================
SELECT pg_temp.actuar_como('dc000000-0000-0000-0000-000000000001', 'aal2');
SELECT is((SELECT count(*)::int FROM _eventos), 5, 'La Directiva consulta la bitácora');
SELECT throws_ok(
  $$ UPDATE public.auditoria_cambios_datos SET valor_nuevo = '{}'::jsonb $$,
  '42501', NULL,
  'Nadie modifica la bitácora, ni la Directiva'
);
SELECT throws_ok(
  $$ DELETE FROM public.auditoria_cambios_datos $$,
  '42501', NULL,
  'Nadie borra la bitácora'
);
SELECT throws_ok(
  $$ INSERT INTO public.auditoria_cambios_datos (tabla_afectada, registro_id, accion, ejecutado_por)
     VALUES ('alumnas', gen_random_uuid(), 'update', auth.uid()) $$,
  '42501', NULL,
  'Nadie inventa eventos en la bitácora'
);
SELECT throws_ok(
  $$ INSERT INTO public.auditoria_accesos_descargas (usuario_id, tipo_operacion) VALUES (auth.uid(), 'export') $$,
  '42501', NULL,
  'Las descargas solo las registra el sistema'
);
SELECT pg_temp.actuar_como('9c000000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT 1 FROM _eventos $$, 'Gestión no lee la bitácora');

SELECT * FROM finish();
ROLLBACK;
