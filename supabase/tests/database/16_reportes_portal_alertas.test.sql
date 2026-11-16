BEGIN;
SELECT plan(69);

-- =============================================================================
-- Datos de prueba: un curso de la sede A con 9 clases ya pasadas, la de hoy y
-- una futura; tres alumnas (Ana y Berta con cuenta) y una de la sede B. Gestión
-- y una tutora en cada sede, y la Directiva.
--
-- Asistencia que se guarda clase a clase (A = ausente, P = presente):
--   clase   1 2 3 4 5 6 7 8 9
--   Ana     A A A A A P A A A   -> alerta en la 3, otra racha desde la 7
--   Berta   A A P P P P P P P   -> 2 faltas seguidas: sin alerta
--   Carla   P P A A A P P P P   -> alerta en la 5 (luego se justifica la 4)
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

CREATE OR REPLACE FUNCTION pg_temp.clase(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('f6200000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid; $$;

CREATE OR REPLACE FUNCTION pg_temp.insc(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('f6300000-0000-0000-0000-00000000000' || p_n)::uuid; $$;

CREATE OR REPLACE FUNCTION pg_temp.lista(p_pares text[]) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_agg(jsonb_build_object('inscripcion_id', pg_temp.insc(p[1]::int), 'estado', p[2]))
  FROM (SELECT string_to_array(x, ':') AS p FROM unnest(p_pares) AS x) AS pares;
$$;

-- Alertas de la alumna N: todas y las sin atender
CREATE OR REPLACE FUNCTION pg_temp.alertas(p_n int, p_solo_activas boolean DEFAULT false) RETURNS bigint
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*) FROM public.alertas_desercion
  WHERE inscripcion_id = pg_temp.insc(p_n) AND (NOT p_solo_activas OR NOT atendida);
$$;

CREATE OR REPLACE FUNCTION pg_temp.alerta_activa(p_n int) RETURNS public.alertas_desercion
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.alertas_desercion WHERE inscripcion_id = pg_temp.insc(p_n) AND NOT atendida;
$$;

CREATE OR REPLACE FUNCTION pg_temp.eventos_denegados(p_usuario uuid, p_recurso text) RETURNS bigint
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*) FROM public.auditoria_seguridad
  WHERE evento = 'acceso_denegado' AND usuario_id = p_usuario AND detalle ->> 'recurso' = p_recurso;
$$;

CREATE OR REPLACE FUNCTION pg_temp.descargas(p_usuario uuid) RETURNS bigint
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*) FROM public.auditoria_accesos_descargas WHERE usuario_id = p_usuario;
$$;

CREATE OR REPLACE FUNCTION pg_temp.descarga(p_usuario uuid, p_tipo text) RETURNS public.auditoria_accesos_descargas
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.auditoria_accesos_descargas WHERE usuario_id = p_usuario AND tipo_reporte = p_tipo
  ORDER BY fecha_hora DESC LIMIT 1;
$$;

CREATE TEMP TABLE resultado (clave text PRIMARY KEY, valor jsonb);
GRANT ALL ON resultado TO authenticated;

INSERT INTO public.sedes (id, nombre) VALUES
  ('f6a00000-0000-0000-0000-00000000000a', 'Sede Reportes A'),
  ('f6b00000-0000-0000-0000-00000000000b', 'Sede Reportes B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('f6c00000-0000-0000-0000-000000000001', 'Curso Reportes', 'REP');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('f6100000-0000-0000-0000-00000000000a', 'f6c00000-0000-0000-0000-000000000001', 'f6a00000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 70, public.hoy_chile() + 30),
  ('f6100000-0000-0000-0000-00000000000b', 'f6c00000-0000-0000-0000-000000000001', 'f6b00000-0000-0000-0000-00000000000b', '2026-2', public.hoy_chile() - 70, public.hoy_chile() + 30);

-- Sede A: clases 1 a 9 (hace 9 a 1 semanas), la 10 hoy y la 11 en una semana. Sede B: una clase pasada
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado)
SELECT pg_temp.clase(n), 'f6100000-0000-0000-0000-00000000000a', n, public.hoy_chile() - 7 * (10 - n), 'programada'
FROM generate_series(1, 11) AS n;
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado) VALUES
  (pg_temp.clase(99), 'f6100000-0000-0000-0000-00000000000b', 1, public.hoy_chile() - 7, 'programada');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('rep.directiva@ninaspro.cl', 'directorio', NULL, '21.160.001-2', 'Directiva', 'Reportes', NULL),
  ('rep.gestion.a@ninaspro.cl', 'equipo_gestion', 'f6a00000-0000-0000-0000-00000000000a', '21.160.002-0', 'Gestión', 'A', NULL),
  ('rep.gestion.b@ninaspro.cl', 'equipo_gestion', 'f6b00000-0000-0000-0000-00000000000b', '21.160.003-9', 'Gestión', 'B', NULL),
  ('rep.tutora.a@ninaspro.cl', 'tutora', 'f6a00000-0000-0000-0000-00000000000a', '21.160.004-7', 'Tutora', 'A', NULL),
  ('rep.tutora.b@ninaspro.cl', 'tutora', 'f6b00000-0000-0000-0000-00000000000b', '21.160.005-5', 'Tutora', 'B', NULL);
SELECT pg_temp.crear_usuario('96000000-0000-0000-0000-00000000000d', 'rep.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('96000000-0000-0000-0000-00000000000a', 'rep.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('96000000-0000-0000-0000-00000000000b', 'rep.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('76000000-0000-0000-0000-000000000001', 'rep.tutora.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('76000000-0000-0000-0000-000000000002', 'rep.tutora.b@ninaspro.cl');
INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada) VALUES
  ('76000000-0000-0000-0000-000000000001', '2025-03-01', true),
  ('76000000-0000-0000-0000-000000000002', '2025-03-01', true);
INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
  ('f6100000-0000-0000-0000-00000000000a', '76000000-0000-0000-0000-000000000001', '96000000-0000-0000-0000-00000000000d'),
  ('f6100000-0000-0000-0000-00000000000b', '76000000-0000-0000-0000-000000000002', '96000000-0000-0000-0000-00000000000d');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono, parentesco) VALUES
  ('f6d00000-0000-0000-0000-000000000001', 'Paula', 'Apoderada', 'paula.rep@correo.cl', '+56 9 3333 1111', 'Madre');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a6000000-0000-0000-0000-000000000001', '27.160.001-1', 'Ana', 'Reportes', '2011-01-01', 'f6d00000-0000-0000-0000-000000000001'),
  ('a6000000-0000-0000-0000-000000000002', '27.160.002-K', 'Berta', 'Reportes', '2011-01-01', 'f6d00000-0000-0000-0000-000000000001'),
  ('a6000000-0000-0000-0000-000000000003', '27.160.003-8', 'Carla', 'Reportes', '2011-01-01', 'f6d00000-0000-0000-0000-000000000001'),
  ('a6000000-0000-0000-0000-000000000004', '27.160.004-6', 'Dana', 'Otra Sede', '2011-01-01', 'f6d00000-0000-0000-0000-000000000001');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, autoriza_uso_imagen_general, registrado_por)
SELECT id, 'f6d00000-0000-0000-0000-000000000001', 'otorgada', 'otorgada', '96000000-0000-0000-0000-00000000000d'
FROM public.alumnas WHERE id::text LIKE 'a6000000-%';
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id, estado, fecha_inscripcion) VALUES
  ('f6300000-0000-0000-0000-000000000001', 'a6000000-0000-0000-0000-000000000001', 'f6100000-0000-0000-0000-00000000000a', 'activa', public.hoy_chile() - 70),
  ('f6300000-0000-0000-0000-000000000002', 'a6000000-0000-0000-0000-000000000002', 'f6100000-0000-0000-0000-00000000000a', 'activa', public.hoy_chile() - 70),
  ('f6300000-0000-0000-0000-000000000003', 'a6000000-0000-0000-0000-000000000003', 'f6100000-0000-0000-0000-00000000000a', 'activa', public.hoy_chile() - 70),
  ('f6300000-0000-0000-0000-000000000004', 'a6000000-0000-0000-0000-000000000004', 'f6100000-0000-0000-0000-00000000000b', 'activa', public.hoy_chile() - 70);
INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por) VALUES
  ('ana.rep@correo.cl', 'alumna', 'f6a00000-0000-0000-0000-00000000000a', 'a6000000-0000-0000-0000-000000000001', NULL),
  ('berta.rep@correo.cl', 'alumna', 'f6a00000-0000-0000-0000-00000000000a', 'a6000000-0000-0000-0000-000000000002', NULL);
SELECT pg_temp.crear_usuario('56000000-0000-0000-0000-000000000001', 'ana.rep@correo.cl');
SELECT pg_temp.crear_usuario('56000000-0000-0000-0000-000000000002', 'berta.rep@correo.cl');

-- =============================================================================
-- 1. Detección de 3 inasistencias seguidas sin justificar (US-39)
-- =============================================================================
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT public.guardar_asistencia_clase(pg_temp.clase(1), pg_temp.lista(ARRAY['1:ausente', '2:ausente', '3:presente']));
SELECT public.guardar_asistencia_clase(pg_temp.clase(2), pg_temp.lista(ARRAY['1:ausente', '2:ausente', '3:presente']));

SELECT is(pg_temp.alertas(1), 0::bigint, 'Con 2 inasistencias seguidas aún no hay alerta');

SELECT public.guardar_asistencia_clase(pg_temp.clase(3), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:ausente']));

SELECT is(
  (SELECT row(inasistencias_consecutivas, clase_id, atendida)::text FROM pg_temp.alerta_activa(1)),
  row(3, pg_temp.clase(3), false)::text,
  'La 3ª inasistencia seguida crea la alerta de la inscripción con su clase (E1)'
);
SELECT is(pg_temp.alertas(2), 0::bigint, 'Asistir después de 2 faltas corta la racha: sin alerta (E2)');

SELECT public.guardar_asistencia_clase(pg_temp.clase(4), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:ausente']));

SELECT is(
  (SELECT row(pg_temp.alertas(1), a.inasistencias_consecutivas, a.clase_id)::text FROM pg_temp.alerta_activa(1) a),
  row(1::bigint, 4, pg_temp.clase(4))::text,
  'Otra falta en la misma racha actualiza la alerta sin crear otra (E3)'
);

SELECT throws_ok(
  $$ INSERT INTO public.alertas_desercion (inscripcion_id, clase_id) VALUES (pg_temp.insc(2), pg_temp.clase(1)) $$,
  '42501', NULL,
  'Nadie crea alertas a mano: las escribe el sistema'
);

-- =============================================================================
-- 2. Panel de alertas y contacto preventivo (US-40)
-- =============================================================================
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT row(alumna_nombres, inasistencias_consecutivas, apoderado_nombre, apoderado_telefono)::text
   FROM public.alertas_detalle WHERE inscripcion_id = pg_temp.insc(1)),
  row('Ana', 4, 'Paula Apoderada', '+56 9 3333 1111')::text,
  'Gestión de la sede ve la alerta con el contacto de la apoderada'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000b');
SELECT is_empty(
  $$ SELECT 1 FROM public.alertas_detalle WHERE inscripcion_id = pg_temp.insc(1) $$,
  'Gestión de otra sede no ve la alerta'
);
SELECT throws_ok(
  $$ SELECT public.registrar_contacto_alerta((SELECT id FROM pg_temp.alerta_activa(1)), 'Llamé a la apoderada') $$,
  '42501', 'Solo el Equipo de Gestión de la sede registra el contacto.',
  'Gestión de otra sede no registra el contacto'
);

SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT 1 FROM public.alertas_detalle $$, 'Las tutoras no ven las alertas');
SELECT throws_ok(
  $$ SELECT public.registrar_contacto_alerta((SELECT id FROM pg_temp.alerta_activa(1)), 'Llamé a la apoderada') $$,
  '42501', NULL,
  'Las tutoras no registran el contacto'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ SELECT public.registrar_contacto_alerta((SELECT id FROM pg_temp.alerta_activa(1)), '   ') $$,
  '22023', 'Cuenta brevemente qué conversaste con la apoderada.',
  'El contacto pide la observación de lo conversado'
);
SELECT throws_ok(
  $$ UPDATE public.alertas_desercion SET atendida = true WHERE inscripcion_id = pg_temp.insc(1) $$,
  '42501', NULL,
  'La alerta no se marca atendida sin la RPC'
);

INSERT INTO resultado VALUES ('alerta_ana', to_jsonb((SELECT id FROM pg_temp.alerta_activa(1))));
SELECT lives_ok(
  $$ SELECT public.registrar_contacto_alerta((SELECT (valor #>> '{}')::uuid FROM resultado WHERE clave = 'alerta_ana'),
                                             'Problemas de transporte; la apoderada la acompañará desde la próxima clase.') $$,
  'Gestión de la sede registra el contacto (E2)'
);
SELECT is(
  (SELECT row(atendida, fecha_contacto, atendida_por_nombre)::text FROM public.alertas_detalle WHERE inscripcion_id = pg_temp.insc(1)),
  row(true, public.hoy_chile(), 'Gestión A')::text,
  'La alerta queda contactada con la fecha y quién la atendió'
);
SELECT throws_ok(
  $$ SELECT public.registrar_contacto_alerta((SELECT (valor #>> '{}')::uuid FROM resultado WHERE clave = 'alerta_ana'), 'Otra vez') $$,
  '22023', 'Esta alerta ya tiene un contacto registrado.',
  'Una alerta contactada no se vuelve a registrar'
);

SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT public.guardar_asistencia_clase(pg_temp.clase(5), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:ausente']));
SELECT is(
  row(pg_temp.alertas(1), pg_temp.alertas(1, true))::text, row(1::bigint, 0::bigint)::text,
  'Tras el contacto, otra falta de la misma racha no repite la alerta'
);
SELECT is(
  (SELECT row(inasistencias_consecutivas, clase_id)::text FROM pg_temp.alerta_activa(3)),
  row(3, pg_temp.clase(5))::text,
  'Carla acumula su 3ª falta seguida: nueva alerta'
);

SELECT public.guardar_asistencia_clase(pg_temp.clase(6), pg_temp.lista(ARRAY['1:presente', '2:presente', '3:presente']));
SELECT public.guardar_asistencia_clase(pg_temp.clase(7), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:presente']));
SELECT public.guardar_asistencia_clase(pg_temp.clase(8), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:presente']));
SELECT public.guardar_asistencia_clase(pg_temp.clase(9), pg_temp.lista(ARRAY['1:ausente', '2:presente', '3:presente']));
SELECT is(
  row(pg_temp.alertas(1), (SELECT inasistencias_consecutivas FROM pg_temp.alerta_activa(1)))::text,
  row(2::bigint, 3)::text,
  'Una racha nueva, después de asistir, abre una alerta nueva'
);

-- Gestión justifica una falta de Carla: la racha se corta y la alerta sin atender se va (E2)
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT public.registrar_justificativo(pg_temp.clase(4), pg_temp.insc(3), 'salud', 'Aviso de la apoderada por teléfono.');
SELECT is(pg_temp.alertas(3), 0::bigint, 'Justificar una de las faltas corta la racha y elimina la alerta sin atender');
SELECT ok(
  (SELECT count(*) > 0 FROM public.consultar_auditoria(p_tipo => 'modificacion', p_rut => '27.160.003-8')
   WHERE descripcion = 'Alerta de deserción: registro eliminado'),
  'La alerta eliminada queda en la auditoría'
);


-- =============================================================================
-- 3. Lecturas denegadas: se registran y responden 403 (US-06 E2, US-27 E3)
-- =============================================================================
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000002');
SELECT is_empty(
  $$ SELECT * FROM public.lista_asistencia_clase(pg_temp.clase(1)) $$,
  'Una tutora de otra sede no lee el pase de lista'
);
SELECT is_empty($$ SELECT * FROM public.lista_asistencia_tutores(pg_temp.clase(1)) $$, 'Ni la asistencia de sus tutoras');
SELECT is_empty($$ SELECT * FROM public.roles_clase(pg_temp.clase(1)) $$, 'Ni los roles de la clase');
SELECT is(current_setting('response.status', true), '403', 'La lectura denegada responde 403');
SELECT pg_temp.como_sistema();
SELECT is(
  row(pg_temp.eventos_denegados('76000000-0000-0000-0000-000000000002', 'lista_asistencia_clase'),
      pg_temp.eventos_denegados('76000000-0000-0000-0000-000000000002', 'lista_asistencia_tutores'),
      pg_temp.eventos_denegados('76000000-0000-0000-0000-000000000002', 'roles_clase'))::text,
  row(1::bigint, 1::bigint, 1::bigint)::text,
  'Cada intento queda en la bitácora de seguridad con la cuenta y el recurso'
);
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT isnt_empty(
  $$ SELECT * FROM public.lista_asistencia_clase(pg_temp.clase(1)) $$,
  'La tutora de la sede sí lee su pase de lista'
);

-- =============================================================================
-- 4. Portal de la alumna (US-25, US-26, US-27)
-- =============================================================================
-- Berta resuelve 26 ejercicios (1 clase recuperable)
SELECT pg_temp.como_sistema();
INSERT INTO public.participacion_clase (clase_id, inscripcion_id, ejercicios_completados, participo_activa, podio_kahoot, registrado_por) VALUES
  (pg_temp.clase(3), pg_temp.insc(2), 12, true, 1, '76000000-0000-0000-0000-000000000001'),
  (pg_temp.clase(6), pg_temp.insc(3), 3, false, NULL, '76000000-0000-0000-0000-000000000001'),
  (pg_temp.clase(7), pg_temp.insc(2), 14, true, 2, '76000000-0000-0000-0000-000000000001');
INSERT INTO public.recursos_clase (clase_id, titulo, tipo, url, orden) VALUES
  (pg_temp.clase(3), 'Guía de la clase 3', 'guia', 'https://recursos.ninaspro.cl/rep-3.pdf', 0);

SELECT pg_temp.actuar_como('56000000-0000-0000-0000-000000000002');
INSERT INTO resultado VALUES ('portal', public.portal_alumna());
SELECT is(
  (SELECT valor -> 'asistencia' FROM resultado WHERE clave = 'portal'),
  jsonb_build_object(
    'realizadas', 9, 'presentes', 7, 'justificadas', 0, 'recuperadas', 0, 'asistidas', 7, 'porcentaje', 77.8,
    'umbral', 80, 'umbral_reducido', false, 'justificativos_aceptados', 0, 'total_clases', 11, 'restantes', 2,
    'clases_necesarias', 2
  ),
  'La alumna ve 7 de 9 clases, la meta del 80 % y cuántas clases le faltan (E1, E2)'
);
SELECT is(
  (SELECT valor -> 'ejercicios' FROM resultado WHERE clave = 'portal'),
  '{"total": 26, "hitos": 1}'::jsonb,
  'Con 26 ejercicios gana 1 clase recuperable, aunque sin faltas justificadas no se aplica (E3)'
);
SELECT is(
  (SELECT row(valor -> 'podios' ->> 'primero', valor -> 'podios' ->> 'segundo', valor #>> '{alumna,rut}')::text
   FROM resultado WHERE clave = 'portal'),
  row('1', '1', '27.160.002-K')::text,
  'El portal trae sus podios y su ficha'
);
SELECT is(
  (SELECT row(jsonb_array_length(valor -> 'sesiones'), valor #>> '{sesiones,2,asistencia}', valor #>> '{sesiones,2,recursos,0,url}',
              valor #>> '{sesiones,10,estado}')::text
   FROM resultado WHERE clave = 'portal'),
  row(11, 'presente', 'https://recursos.ninaspro.cl/rep-3.pdf', 'programada')::text,
  'El cronograma trae cada sesión con su asistencia y sus recursos (US-26)'
);

-- Gestión acepta un justificativo de Berta: umbral del 70 % y la clase recuperada con ejercicios
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT public.registrar_justificativo(pg_temp.clase(1), pg_temp.insc(2), 'escolar', 'Prueba en el liceo.');
SELECT pg_temp.actuar_como('56000000-0000-0000-0000-000000000002');
SELECT is(
  (SELECT row(a ->> 'justificadas', a ->> 'recuperadas', a ->> 'asistidas', a ->> 'porcentaje', a ->> 'umbral',
              a ->> 'umbral_reducido', a ->> 'clases_necesarias')::text
   FROM (SELECT public.portal_alumna() -> 'asistencia' AS a) x),
  row('1', '1', '8', '88.9', '70', 'true', '0')::text,
  'Con un justificativo aceptado la meta baja al 70 % y los ejercicios recuperan la clase justificada (E1, E3)'
);

SELECT is(
  public.portal_alumna('a6000000-0000-0000-0000-000000000001') ->> 'code', '42501',
  'Con el id de otra alumna el portal responde 403 (US-27 E2)'
);
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT is(public.portal_alumna() ->> 'code', '42501', 'El portal es solo para alumnas');
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT row(count(*), max(detalle ->> 'id'))::text FROM public.auditoria_seguridad
   WHERE evento = 'acceso_denegado' AND usuario_id = '56000000-0000-0000-0000-000000000002'),
  row(1::bigint, 'a6000000-0000-0000-0000-000000000001')::text,
  'El intento queda registrado con la cuenta y la alumna ajena (US-27 E3)'
);

-- =============================================================================
-- 5. Dashboard (resumen por sede y asistencia por clase)
-- =============================================================================
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000d', 'aal2');
SELECT is(
  (SELECT count(*) FROM public.resumen_sedes() WHERE sede_id IN ('f6a00000-0000-0000-0000-00000000000a', 'f6b00000-0000-0000-0000-00000000000b')),
  2::bigint,
  'La Directiva ve todas las sedes'
);
SELECT is(
  (SELECT row(cursos, alumnas_activas, asistencia_promedio, voluntarias_activas)::text
   FROM public.resumen_sedes() WHERE sede_id = 'f6a00000-0000-0000-0000-00000000000a'),
  row(1, 3, 51.9, 1)::text,
  'Indicadores de la sede: cursos, alumnas activas, asistencia (presentes sobre registros) y voluntarias'
);
SELECT is(
  (SELECT row(count(*), sum(presentes), sum(total))::text FROM public.asistencia_por_clase()
   WHERE sede_id = 'f6a00000-0000-0000-0000-00000000000a'),
  row(9::bigint, 14::bigint, 27::bigint)::text,
  'Asistencia de la sede en cada clase realizada'
);
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT array_agg(nombre) FROM public.resumen_sedes()),
  ARRAY['Sede Reportes A'],
  'Gestión ve solo su sede'
);
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT * FROM public.resumen_sedes() $$, 'Las tutoras no ven el dashboard');

-- =============================================================================
-- 6. Exportación filtrada y disociada (US-21, US-22)
-- =============================================================================
SELECT is(
  public.exportar_reporte('asistencia') ->> 'code', '42501',
  'Las tutoras no exportan'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT is(
  public.exportar_reporte('asistencia', 'f6b00000-0000-0000-0000-00000000000b') ->> 'code', '42501',
  'Gestión no exporta otra sede (US-21 E3)'
);
SELECT pg_temp.como_sistema();
SELECT is(
  pg_temp.eventos_denegados('96000000-0000-0000-0000-00000000000a', 'exportar_reporte'), 1::bigint,
  'El intento de exportar otra sede queda registrado'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
INSERT INTO resultado VALUES ('previa', public.exportar_reporte('asistencia', p_vista_previa => true));
SELECT is(
  (SELECT row((valor ->> 'total')::int, jsonb_array_length(valor -> 'filas'))::text FROM resultado WHERE clave = 'previa'),
  row(27, 10)::text,
  'La vista previa cuenta todas las filas y trae solo 10'
);
SELECT is(pg_temp.descargas('96000000-0000-0000-0000-00000000000a'), 0::bigint, 'La vista previa no es una descarga');

INSERT INTO resultado VALUES ('asistencia', public.exportar_reporte('asistencia', p_formato => 'xlsx'));
SELECT is(
  (SELECT row((valor ->> 'total')::int, jsonb_array_length(valor -> 'filas'), valor -> 'encabezados' ->> 5)::text
   FROM resultado WHERE clave = 'asistencia'),
  row(27, 27, 'RUT')::text,
  'Sin sede elegida, Gestión exporta su sede: una fila por alumna y clase (US-21 E1)'
);
SELECT is(
  (SELECT valor -> 'filas' -> 0 FROM resultado WHERE clave = 'asistencia'),
  jsonb_build_array('Sede Reportes A', 'REP', '2026-2', '1', to_char(public.hoy_chile() - 63, 'DD-MM-YYYY'),
                    '27.160.001-1', 'Ana', 'Reportes', 'Ausente'),
  'Cada fila trae la clase, el RUT con formato y el estado'
);
SELECT is(
  (SELECT row(tipo_operacion, tipo_reporte, filtro_sede_id, formato_archivo, cantidad_registros, disociado,
              cardinality(alumnas_incluidas))::text
   FROM pg_temp.descarga('96000000-0000-0000-0000-00000000000a', 'asistencia')),
  row('exportacion', 'asistencia', 'f6a00000-0000-0000-0000-00000000000a'::uuid, 'XLSX', 27, false, 3)::text,
  'La descarga queda en la auditoría con la sede, el formato, las filas y las alumnas incluidas (US-22 E2)'
);

INSERT INTO resultado VALUES ('disociado', public.exportar_reporte('participacion', p_disociado => true));
SELECT is(
  (SELECT row(valor -> 'encabezados' ->> 5, valor -> 'filas' -> 0 ->> 5, valor -> 'filas' -> 0 ->> 6,
              jsonb_array_length(valor -> 'filas'))::text
   FROM resultado WHERE clave = 'disociado'),
  row('Alumna', 'ALUMNA-001', '12', 3)::text,
  'Disociado: un código por alumna en lugar del RUT y el nombre (US-22 E1)'
);
SELECT ok(
  (SELECT valor::text NOT LIKE '%27.160%' AND valor::text NOT LIKE '%Berta%' FROM resultado WHERE clave = 'disociado'),
  'El archivo disociado no trae RUT ni nombres'
);
SELECT is(
  (SELECT array_agg(DISTINCT f ->> 5 ORDER BY f ->> 5) FROM resultado, jsonb_array_elements(valor -> 'filas') AS f WHERE clave = 'disociado'),
  ARRAY['ALUMNA-001', 'ALUMNA-002'],
  'El código de cada alumna se repite en todas sus filas'
);
SELECT is(
  (SELECT row(disociado, cardinality(alumnas_incluidas))::text
   FROM pg_temp.descarga('96000000-0000-0000-0000-00000000000a', 'participacion')),
  row(true, 0)::text,
  'La descarga disociada no guarda alumnas identificables'
);

SELECT throws_ok(
  $$ SELECT public.exportar_reporte('nomina') $$,
  '42501', 'La nómina de alumnas la exporta la Directiva.',
  'La nómina (con consentimientos) la exporta solo la Directiva'
);

INSERT INTO resultado VALUES ('vacio', public.exportar_reporte('asistencia', p_desde => public.hoy_chile() + 1));
SELECT is(
  (SELECT row((valor ->> 'total')::int, jsonb_array_length(valor -> 'filas'), jsonb_array_length(valor -> 'encabezados'))::text
   FROM resultado WHERE clave = 'vacio'),
  row(0, 0, 9)::text,
  'Sin registros, el reporte trae solo los encabezados (US-22 E3)'
);
SELECT throws_ok(
  $$ SELECT public.exportar_reporte('asistencia', p_desde => public.hoy_chile(), p_hasta => public.hoy_chile() - 1) $$,
  '22023', 'La fecha de término no puede ser anterior a la de inicio.',
  'Rango de fechas inválido'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000d', 'aal2');
INSERT INTO resultado VALUES ('nomina', public.exportar_reporte('nomina', p_instancia_id => 'f6100000-0000-0000-0000-00000000000a', p_disociado => true));
SELECT is(
  (SELECT row((valor ->> 'total')::int, valor -> 'encabezados' ->> 3, valor -> 'filas' -> 0 ->> 3, valor -> 'filas' -> 0 ->> 9)::text
   FROM resultado WHERE clave = 'nomina'),
  row(3, 'Alumna', 'ALUMNA-001', '1')::text,
  'La nómina disociada de la Directiva también reemplaza el RUT y el nombre'
);
SELECT is(
  (public.exportar_reporte('asistencia', p_instancia_id => 'f6100000-0000-0000-0000-00000000000a', p_vista_previa => true) ->> 'total')::int,
  27,
  'La Directiva exporta cualquier curso'
);

-- =============================================================================
-- 7. Auditoría: inmutable y consultable por alumna, usuaria y sede (US-23, US-24)
-- =============================================================================
SELECT ok(
  (SELECT count(*) > 0 AND bool_and(alumna_rut = '27.160.001-1')
   FROM public.consultar_auditoria(p_rut => '27160001-1')),
  'Filtrar por el RUT de la alumna trae solo sus eventos (ARCO, E1)'
);
SELECT ok(
  (SELECT count(*) > 0 FROM public.consultar_auditoria(p_rut => '27.160.001-1', p_tipo => 'modificacion')
   WHERE descripcion LIKE 'Asistencia de alumna:%'),
  'Incluye los cambios de su asistencia'
);
SELECT ok(
  (SELECT count(*) > 0 FROM public.consultar_auditoria(p_rut => '27.160.001-1', p_tipo => 'exportacion')),
  'Incluye las descargas que la identificaban'
);
SELECT is(
  (SELECT count(*) FROM public.consultar_auditoria(p_rut => '27.160.002-K', p_tipo => 'exportacion')),
  1::bigint,
  'Una descarga disociada no cuenta como acceso a sus datos'
);
SELECT ok(
  (SELECT count(*) > 0 AND bool_and(usuaria_correo = 'rep.gestion.a@ninaspro.cl')
   FROM public.consultar_auditoria(p_usuaria => 'rep.gestion.a')),
  'Filtrar por el correo de una voluntaria trae solo sus acciones (E2)'
);
SELECT ok(
  (SELECT count(*) > 0 FROM public.consultar_auditoria(p_tipo => 'acceso_denegado', p_usuaria => 'Tutora B')),
  'La Directiva ve los accesos denegados'
);
SELECT is_empty(
  $$ SELECT 1 FROM public.consultar_auditoria(p_desde => public.hoy_chile() + 1) $$,
  'El rango de fechas acota los eventos'
);

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000b');
SELECT is_empty(
  $$ SELECT 1 FROM public.consultar_auditoria(p_rut => '27.160.001-1') $$,
  'Gestión de otra sede no ve los eventos de la alumna (E3)'
);
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-00000000000a');
SELECT ok(
  (SELECT count(*) > 0 AND bool_and(sede_id = 'f6a00000-0000-0000-0000-00000000000a') FROM public.consultar_auditoria()),
  'Gestión ve solo lo ocurrido en su sede (E3)'
);
SELECT pg_temp.actuar_como('76000000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT 1 FROM public.consultar_auditoria() $$, 'Las tutoras no consultan la auditoría');

SELECT pg_temp.como_sistema();
SELECT throws_ok(
  $$ UPDATE public.auditoria_cambios_datos SET valor_nuevo = '{}'::jsonb $$,
  '42501', 'La bitácora de auditoría es inmutable: no se puede modificar ni eliminar.',
  'Ni el administrador modifica la bitácora de cambios (US-23 E2)'
);
SELECT throws_ok(
  $$ DELETE FROM public.auditoria_accesos_descargas $$,
  '42501', 'La bitácora de auditoría es inmutable: no se puede modificar ni eliminar.',
  'Ni el administrador elimina descargas registradas'
);
SELECT throws_ok(
  $$ TRUNCATE public.auditoria_seguridad $$,
  '42501', 'La bitácora de auditoría es inmutable: no se puede modificar ni eliminar.',
  'Ni el administrador vacía la bitácora de seguridad'
);

SELECT * FROM finish();
ROLLBACK;
