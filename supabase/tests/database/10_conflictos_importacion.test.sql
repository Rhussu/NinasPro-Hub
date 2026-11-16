BEGIN;
SELECT plan(24);

-- =============================================================================
-- Conflictos de una carga masiva: se resuelven en la misma carga o quedan
-- pendientes para la Directiva (US-07, US-08, US-09)
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

CREATE OR REPLACE FUNCTION pg_temp.rut(p_cuerpo int) RETURNS text
LANGUAGE sql AS $$
  SELECT public.formatear_rut(p_cuerpo::text || d)
  FROM unnest(ARRAY['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'K']) AS d
  WHERE public.rut_valido(p_cuerpo::text || d);
$$;

CREATE OR REPLACE FUNCTION pg_temp.fila(p_fila int, p_rut text, p_nombres text DEFAULT 'Alumna', p_extra jsonb DEFAULT '{}')
RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_build_object(
    'fila', p_fila, 'rut', p_rut, 'nombres', p_nombres, 'apellidos', 'Conflicto',
    'fecha_nacimiento', '2011-04-15',
    'nombres_apoderado', 'Apoderada', 'apellidos_apoderado', 'Conflicto',
    'telefono_apoderado', '+56 9 1234 5678', 'correo_apoderado', 'apoderada@correo.cl'
  ) || p_extra;
$$;

-- Estado de cada fila de una respuesta de importar_alumnas
CREATE OR REPLACE FUNCTION pg_temp.estados(r jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_agg(f->>'estado' ORDER BY (f->>'fila')::int) FROM jsonb_array_elements(r->'filas') f;
$$;

INSERT INTO public.sedes (id, nombre) VALUES ('a1000000-0000-0000-0000-00000000000a', 'Sede Conflictos');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('c1000000-0000-0000-0000-000000000001', 'Curso Conflictos', 'CNF');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('11a00000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-00000000000a', '2026-2', current_date - 30, current_date + 60),
  ('11b00000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-00000000000a', '2027-1', current_date + 70, current_date + 160);

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('cnf.directiva@ninaspro.cl', 'directorio', NULL, '21.101.111-1', 'Directiva', 'Conflictos', NULL),
  ('cnf.gestion@ninaspro.cl', 'equipo_gestion', 'a1000000-0000-0000-0000-00000000000a', '22.102.222-2', 'Gestión', 'Conflictos', NULL);
SELECT pg_temp.crear_usuario('d1000000-0000-0000-0000-000000000001', 'cnf.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('91000000-0000-0000-0000-000000000001', 'cnf.gestion@ninaspro.cl');
-- Otra alumna que ya usa el correo que traerá la planilla
INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('a1b00000-0000-0000-0000-000000000001', 'Otra', 'Apoderada', 'otra@correo.cl', '+56911111111');
INSERT INTO public.alumnas (rut, nombres, apellidos, fecha_nacimiento, correo, apoderado_id) VALUES
  ('26.999.999-9', 'Otra', 'Alumna', '2011-01-01', 'ocupado@correo.cl', 'a1b00000-0000-0000-0000-000000000001');

-- Ficha existente de una alumna inscrita en el período anterior
SELECT pg_temp.actuar_como('d1000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(
  ((public.importar_alumnas('11a00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(1, pg_temp.rut(26000001), 'Antonia'))))->>'inscritas')::int,
  1,
  'Se inscribe una alumna que luego aparecerá en otra planilla'
);

-- =============================================================================
-- Vista previa: cada conflicto se avisa con lo que hace falta para resolverlo
-- =============================================================================
CREATE TEMP TABLE _planilla AS SELECT jsonb_build_array(
  pg_temp.fila(2, pg_temp.rut(26000002), 'Bea'),
  pg_temp.fila(3, pg_temp.rut(26000002), 'Beatriz'),
  pg_temp.fila(4, pg_temp.rut(26000001), 'Antonella', '{"telefono_apoderado": "+56 9 9999 0000", "establecimiento": "Liceo Nuevo"}'),
  pg_temp.fila(5, pg_temp.rut(26000005), 'Carla', '{"correo": "ocupado@correo.cl"}'),
  pg_temp.fila(6, '26.000.006-0', 'Dana')
) AS filas;
GRANT SELECT ON _planilla TO authenticated;
SELECT ok(NOT public.rut_valido('26.000.006-0'), 'La fila 6 tiene un RUT inválido');

CREATE TEMP TABLE _previa AS
SELECT public.importar_alumnas('11b00000-0000-0000-0000-000000000001', filas, true, 'nomina.csv') AS r FROM _planilla;

SELECT is(
  (SELECT pg_temp.estados(r) FROM _previa),
  '["conflicto", "conflicto", "conflicto", "conflicto", "invalida"]'::jsonb,
  'Los RUT repetidos, la ficha distinta y el correo en uso son conflictos; el RUT inválido es un error'
);
SELECT is(
  (SELECT r->'filas'->0->'filas_repetidas' FROM _previa),
  '[2, 3]'::jsonb,
  'El RUT repetido indica en qué filas aparece'
);
SELECT is(
  (SELECT jsonb_agg(d->>'campo') FROM _previa, jsonb_array_elements(r->'filas'->2->'diferencias') d),
  '["Nombres", "Teléfono del apoderado/a"]'::jsonb,
  'La ficha distinta muestra qué datos difieren (un dato vacío en la ficha no es conflicto)'
);
SELECT is(
  (SELECT r->'filas'->2->'diferencias'->0 FROM _previa),
  '{"campo": "Nombres", "ficha": "Antonia", "planilla": "Antonella"}'::jsonb,
  'Cada diferencia trae el valor de la ficha y el de la planilla'
);
SELECT is(
  (SELECT r->'filas'->3->'conflictos' FROM _previa),
  '["correo_en_uso"]'::jsonb,
  'El correo que ya usa otra cuenta es un conflicto'
);

-- Resolver en la misma vista previa
SELECT is(
  pg_temp.estados(public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(
    pg_temp.fila(2, pg_temp.rut(26000002), 'Bea', '{"resolucion": "descartar"}'),
    pg_temp.fila(3, pg_temp.rut(26000002), 'Beatriz'),
    pg_temp.fila(4, pg_temp.rut(26000001), 'Antonella', '{"telefono_apoderado": "+56 9 9999 0000", "resolucion": "actualizar_ficha"}'),
    pg_temp.fila(5, pg_temp.rut(26000005), 'Carla', '{"correo": "ocupado@correo.cl", "resolucion": "sin_correo"}'),
    pg_temp.fila(6, pg_temp.rut(26000006), 'Dana')
  ), true)),
  '["descartada", "nueva", "existente", "nueva", "nueva"]'::jsonb,
  'Descartar una fila repetida, elegir qué hacer con la ficha, inscribir sin correo y corregir el RUT resuelven los conflictos'
);
SELECT throws_ok(
  $$ SELECT public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(2, pg_temp.rut(26000002), 'X', '{"resolucion": "ignorar"}')), true) $$,
  '22023', NULL,
  'Una resolución desconocida se rechaza'
);

-- =============================================================================
-- Confirmar con conflictos sin resolver: quedan pendientes
-- =============================================================================
CREATE TEMP TABLE _carga AS
SELECT public.importar_alumnas('11b00000-0000-0000-0000-000000000001', filas, false, 'nomina.csv') AS r FROM _planilla;
SELECT is(
  (SELECT (r->>'inscritas')::int || '/' || (r->>'pendientes')::int FROM _carga),
  '0/5',
  'Al confirmar, lo que no se resolvió queda pendiente y no se inscribe'
);
SELECT is(
  (SELECT pg_temp.estados(r) FROM _carga),
  '["pendiente", "pendiente", "pendiente", "pendiente", "pendiente"]'::jsonb,
  'Cada fila sin resolver se informa como pendiente'
);
SELECT is(
  (SELECT count(*)::int FROM public.conflictos_importacion WHERE archivo = 'nomina.csv' AND instancia_curso_id = '11b00000-0000-0000-0000-000000000001'),
  5,
  'Los pendientes quedan guardados con su archivo y curso'
);
SELECT is(
  (SELECT motivo FROM public.conflictos_importacion WHERE numero_fila = 6 AND archivo = 'nomina.csv'),
  'RUT de la alumna inválido (dígito verificador)',
  'Cada pendiente guarda su motivo'
);

-- =============================================================================
-- Resolver después desde la lista de pendientes
-- =============================================================================
CREATE TEMP TABLE _pend AS
SELECT numero_fila, id FROM public.conflictos_importacion WHERE archivo = 'nomina.csv';
GRANT SELECT ON _pend TO authenticated;

-- Fila 6 corregida: se inscribe y el pendiente desaparece
SELECT is(
  (public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(
    pg_temp.fila(6, pg_temp.rut(26000006), 'Dana') || jsonb_build_object('conflicto_id', (SELECT id FROM _pend WHERE numero_fila = 6))
  )))->>'inscritas',
  '1',
  'Una fila pendiente corregida se inscribe'
);
SELECT is_empty(
  $$ SELECT 1 FROM public.conflictos_importacion WHERE id = (SELECT id FROM _pend WHERE numero_fila = 6) $$,
  'El pendiente resuelto se borra'
);

-- Fila 5 resuelta sin resolver todavía: se reemplaza (no se duplica)
SELECT is(
  (public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(
    pg_temp.fila(5, pg_temp.rut(26000005), 'Carla', '{"correo": "ocupado@correo.cl"}') || jsonb_build_object('conflicto_id', (SELECT id FROM _pend WHERE numero_fila = 5))
  )))->>'pendientes',
  '1',
  'Un pendiente que sigue sin resolverse vuelve a quedar pendiente'
);
SELECT is(
  (SELECT count(*)::int || ' ' || min(archivo) FROM public.conflictos_importacion WHERE numero_fila = 5 AND instancia_curso_id = '11b00000-0000-0000-0000-000000000001'),
  '1 nomina.csv',
  'El pendiente se reemplaza conservando el archivo de origen'
);

-- Fila 4: actualizar la ficha con los datos de la planilla
SELECT lives_ok(
  $$ SELECT public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(
       pg_temp.fila(4, pg_temp.rut(26000001), 'Antonella', '{"telefono_apoderado": "+56 9 9999 0000", "establecimiento": "Liceo Nuevo", "resolucion": "actualizar_ficha"}')
       || jsonb_build_object('conflicto_id', (SELECT id FROM _pend WHERE numero_fila = 4))
     )) $$,
  'Se resuelve la ficha distinta actualizándola'
);
SELECT is(
  (SELECT a.nombres || ' · ' || a.establecimiento_educacional || ' · ' || ap.telefono
   FROM public.alumnas a JOIN public.apoderados ap ON ap.id = a.apoderado_id WHERE a.rut = pg_temp.rut(26000001)),
  'Antonella · Liceo Nuevo · +56 9 9999 0000',
  'Actualizar la ficha cambia sus datos y el contacto del apoderado/a'
);

-- Filas 2 y 3: se descarta una y se inscribe la otra
SELECT lives_ok(
  $$ SELECT public.descartar_conflicto_importacion((SELECT id FROM _pend WHERE numero_fila = 2)) $$,
  'La Directiva descarta un pendiente'
);
SELECT is(
  (public.importar_alumnas('11b00000-0000-0000-0000-000000000001', jsonb_build_array(
    pg_temp.fila(3, pg_temp.rut(26000002), 'Beatriz') || jsonb_build_object('conflicto_id', (SELECT id FROM _pend WHERE numero_fila = 3))
  )))->>'inscritas',
  '1',
  'Al descartar el repetido, la otra fila se inscribe'
);
SELECT is(
  (SELECT count(*)::int FROM public.conflictos_importacion WHERE archivo = 'nomina.csv'),
  1,
  'Solo queda pendiente la fila del correo en uso'
);

-- =============================================================================
-- Gestión no ve ni resuelve los conflictos
-- =============================================================================
SELECT pg_temp.actuar_como('91000000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT 1 FROM public.conflictos_importacion $$, 'Gestión no ve los conflictos de importación');
SELECT throws_ok(
  $$ SELECT public.descartar_conflicto_importacion(gen_random_uuid()) $$,
  '42501', NULL,
  'Gestión no descarta conflictos'
);

SELECT * FROM finish();
ROLLBACK;
