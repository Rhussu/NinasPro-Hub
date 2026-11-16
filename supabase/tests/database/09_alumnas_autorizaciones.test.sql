BEGIN;
SELECT plan(66);

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

-- RUT válido con el cuerpo dado: '25000001' -> '25.000.001-K'
CREATE OR REPLACE FUNCTION pg_temp.rut(p_cuerpo int) RETURNS text
LANGUAGE sql AS $$
  SELECT public.formatear_rut(p_cuerpo::text || d)
  FROM unnest(ARRAY['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'K']) AS d
  WHERE public.rut_valido(p_cuerpo::text || d);
$$;

-- Fila de la plantilla con datos completos
CREATE OR REPLACE FUNCTION pg_temp.fila(p_fila int, p_rut text, p_nombres text DEFAULT 'Alumna', p_apellidos text DEFAULT 'Prueba')
RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_build_object(
    'fila', p_fila, 'rut', p_rut, 'nombres', p_nombres, 'apellidos', p_apellidos,
    'fecha_nacimiento', '2011-04-15', 'establecimiento', 'Liceo 1', 'curso_escolar', '1° medio',
    'nombres_apoderado', 'Apoderada', 'apellidos_apoderado', 'Prueba',
    'telefono_apoderado', '+56 9 1234 5678', 'correo_apoderado', 'apoderada@correo.cl'
  );
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('a9000000-0000-0000-0000-00000000000a', 'Sede Nómina A'),
  ('b9000000-0000-0000-0000-00000000000b', 'Sede Nómina B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('c9000000-0000-0000-0000-000000000001', 'Curso Nómina', 'NOM');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('19a00000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-00000000000a', '2026-2', current_date - 30, current_date + 60),
  ('19b00000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001', 'b9000000-0000-0000-0000-00000000000b', '2026-2', current_date - 30, current_date + 60);

-- Tres sesiones de la sede A: dos ya pasaron y una es futura
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado) VALUES
  ('29a00000-0000-0000-0000-000000000001', '19a00000-0000-0000-0000-000000000001', 1, current_date - 14, 'realizada'),
  ('29a00000-0000-0000-0000-000000000002', '19a00000-0000-0000-0000-000000000001', 2, current_date - 7, 'realizada'),
  ('29a00000-0000-0000-0000-000000000003', '19a00000-0000-0000-0000-000000000001', 3, current_date + 7, 'programada');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('nom.directiva@ninaspro.cl', 'directorio', NULL, '21.911.111-1', 'Directiva', 'Nómina', NULL),
  ('nom.gestion.a@ninaspro.cl', 'equipo_gestion', 'a9000000-0000-0000-0000-00000000000a', '22.922.222-2', 'Gestión', 'A', NULL),
  ('nom.gestion.b@ninaspro.cl', 'equipo_gestion', 'b9000000-0000-0000-0000-00000000000b', '23.933.333-3', 'Gestión', 'B', NULL),
  ('nom.tutora.a@ninaspro.cl', 'tutora', 'a9000000-0000-0000-0000-00000000000a', '24.944.444-4', 'Tutora', 'A', NULL);
SELECT pg_temp.crear_usuario('d9000000-0000-0000-0000-000000000001', 'nom.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('99a00000-0000-0000-0000-000000000001', 'nom.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('99b00000-0000-0000-0000-000000000001', 'nom.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('79a00000-0000-0000-0000-000000000001', 'nom.tutora.a@ninaspro.cl');

-- =============================================================================
-- RUT chileno (US-08)
-- =============================================================================
SELECT ok(public.rut_valido('22.341.890-2'), 'Un RUT con su dígito verificador correcto es válido');
SELECT ok(public.rut_valido('10.000.013-k'), 'El dígito K se acepta en minúscula');
SELECT ok(NOT public.rut_valido('22.341.890-3'), 'Un dígito verificador incorrecto no es válido (módulo 11)');
SELECT ok(NOT public.rut_valido('abc'), 'Un texto sin formato de RUT no es válido');
SELECT is(public.formatear_rut('10000013k'), '10.000.013-K', 'El RUT se guarda con puntos, guion y K mayúscula');

-- =============================================================================
-- Carga masiva: previsualización y confirmación (US-07, US-08, TC-04)
-- =============================================================================
-- 30 filas: 28 válidas, una con dígito verificador inválido y otra sin contacto del apoderado
CREATE TEMP TABLE _planilla AS
SELECT jsonb_agg(
  CASE n
    WHEN 7 THEN pg_temp.fila(n, '25.000.007-0', 'Josefa', 'Inválida')
    WHEN 12 THEN pg_temp.fila(n, pg_temp.rut(25000000 + n)) - 'correo_apoderado' - 'telefono_apoderado'
    WHEN 1 THEN pg_temp.fila(n, pg_temp.rut(25000000 + n), 'María José', 'Muñoz Ñúñez')
    WHEN 2 THEN pg_temp.fila(n, pg_temp.rut(25000000 + n), 'Zoë Anaïs', 'Güemes') || '{"correo": "zoe.guemes@correo.cl"}'
    ELSE pg_temp.fila(n, pg_temp.rut(25000000 + n))
  END ORDER BY n
) AS filas
FROM generate_series(1, 30) AS n;
GRANT SELECT ON _planilla TO authenticated;
-- El RUT 25.000.007-0 debe ser inválido para que la prueba tenga sentido
SELECT ok(NOT public.rut_valido('25.000.007-0'), 'La fila 7 de la planilla tiene un RUT inválido');

SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');

CREATE TEMP TABLE _previa AS
SELECT public.importar_alumnas('19a00000-0000-0000-0000-000000000001', filas, true) AS r FROM _planilla;

SELECT is(
  (SELECT count(*)::int FROM _previa, jsonb_array_elements(r->'filas') f WHERE f->>'estado' = 'nueva'),
  28,
  'La previsualización desglosa 28 alumnas nuevas'
);
SELECT is(
  (SELECT jsonb_agg(f->'fila' ORDER BY (f->>'fila')::int) FROM _previa, jsonb_array_elements(r->'filas') f WHERE f->>'estado' = 'invalida'),
  '[7, 12]'::jsonb,
  'Las filas 7 y 12 quedan como inválidas'
);
SELECT ok(
  (SELECT f->>'motivo' FROM _previa, jsonb_array_elements(r->'filas') f WHERE (f->>'fila')::int = 7) LIKE '%dígito verificador%',
  'La fila 7 informa el RUT inválido'
);
SELECT ok(
  (SELECT f->>'motivo' FROM _previa, jsonb_array_elements(r->'filas') f WHERE (f->>'fila')::int = 12) LIKE '%obligatorios por protocolo institucional%',
  'La fila 12 informa que el contacto del apoderado es obligatorio'
);
SELECT is((SELECT (r->>'inscritas')::int FROM _previa), 0, 'La previsualización no inscribe a nadie');
SELECT is_empty(
  $$ SELECT 1 FROM public.inscripciones WHERE instancia_curso_id = '19a00000-0000-0000-0000-000000000001' $$,
  'La previsualización no escribe en la base'
);

CREATE TEMP TABLE _carga AS
SELECT public.importar_alumnas('19a00000-0000-0000-0000-000000000001', filas) AS r FROM _planilla;
SELECT is((SELECT (r->>'inscritas')::int FROM _carga), 28, 'Confirmar la carga inscribe las 28 filas válidas');
SELECT is(
  (SELECT count(*)::int FROM public.inscripciones WHERE instancia_curso_id = '19a00000-0000-0000-0000-000000000001' AND estado = 'preinscrita'),
  28,
  'Las 28 inscripciones quedan como preinscritas'
);
SELECT is(
  (SELECT nombres || ' ' || apellidos FROM public.alumnas WHERE rut = pg_temp.rut(25000001)),
  'María José Muñoz Ñúñez',
  'Las tildes, la diéresis y la ñ se guardan íntegras'
);
SELECT is(
  (SELECT nombres || ' ' || apellidos FROM public.alumnas WHERE rut = pg_temp.rut(25000002)),
  'Zoë Anaïs Güemes',
  'Los nombres compuestos con diéresis se guardan íntegros'
);
SELECT is(
  (SELECT rol::text || ' ' || sede_id::text FROM public.correos_autorizados WHERE correo = 'zoe.guemes@correo.cl'),
  'alumna a9000000-0000-0000-0000-00000000000a',
  'Con su correo, la alumna queda autorizada para crear su cuenta'
);

-- RUT repetido dentro del archivo: se rechazan todas sus filas
SELECT is(
  (SELECT jsonb_agg(f->>'estado') FROM jsonb_array_elements((public.importar_alumnas(
    '19a00000-0000-0000-0000-000000000001',
    jsonb_build_array(pg_temp.fila(2, pg_temp.rut(25000101)), pg_temp.fila(3, pg_temp.rut(25000102)), pg_temp.fila(4, replace(pg_temp.rut(25000101), '.', ''))),
    true
  ))->'filas') f),
  '["conflicto", "nueva", "conflicto"]'::jsonb,
  'Un RUT repetido en la planilla (con o sin puntos) se avisa como conflicto en sus filas'
);

-- Una alumna ya inscrita en el curso no se inscribe dos veces
SELECT is(
  (public.importar_alumnas('19a00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(2, pg_temp.rut(25000003))), true))->'filas'->0->>'motivo',
  'Ya está inscrita en este curso',
  'Una alumna ya inscrita en el curso se informa'
);

-- =============================================================================
-- Ficha única por RUT en otra sede (US-09, TC-05)
-- =============================================================================
SELECT is(
  (public.importar_alumnas('19b00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(2, replace(pg_temp.rut(25000003), '.', ''))), true))->'filas'->0->>'estado',
  'existente',
  'El RUT de una alumna de otra sede se reconoce como ficha existente'
);
SELECT is(
  (public.importar_alumnas('19b00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(2, replace(pg_temp.rut(25000003), '.', ''), 'Otro', 'Nombre')), true))->'filas'->0->'conflictos',
  '["ficha_distinta"]'::jsonb,
  'Si la planilla trae otros datos para esa ficha, se avisa el conflicto'
);
SELECT is(
  ((public.importar_alumnas('19b00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(2, replace(pg_temp.rut(25000003), '.', ''), 'Otro', 'Nombre') || '{"resolucion": "mantener_ficha"}')))->>'inscritas')::int,
  1,
  'Al mantener la ficha, la alumna existente se inscribe en la sede B'
);
SELECT is(
  (SELECT count(*)::int FROM public.alumnas WHERE public.normalizar_rut(rut) = public.normalizar_rut(pg_temp.rut(25000003))),
  1,
  'Sigue habiendo una sola ficha para ese RUT'
);
SELECT is(
  (SELECT count(*)::int FROM public.inscripciones i JOIN public.alumnas a ON a.id = i.alumna_id WHERE a.rut = pg_temp.rut(25000003)),
  2,
  'La ficha tiene dos inscripciones independientes'
);
SELECT is(
  (SELECT nombres FROM public.alumnas WHERE rut = pg_temp.rut(25000003)),
  'Alumna',
  'Reutilizar la ficha no sobrescribe sus datos personales'
);

-- =============================================================================
-- Permisos de la carga
-- =============================================================================
SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.importar_alumnas('19a00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(1, pg_temp.rut(25000201)))) $$,
  '42501', NULL,
  'Gestión no inscribe alumnas, ni siquiera en su sede'
);
SELECT pg_temp.actuar_como('79a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.importar_alumnas('19a00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(1, pg_temp.rut(25000201)))) $$,
  '42501', NULL,
  'Una tutora no inscribe alumnas'
);
SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ INSERT INTO public.alumnas (rut, nombres, apellidos, fecha_nacimiento, apoderado_id)
     SELECT '6.000.004-K', 'Directa', 'Sin RPC', '2011-01-01', apoderado_id FROM public.alumnas LIMIT 1 $$,
  '42501', NULL,
  'Nadie crea fichas sin pasar por la validación de la RPC'
);
SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(
  ((public.importar_alumnas('19a00000-0000-0000-0000-000000000001', jsonb_build_array(pg_temp.fila(1, pg_temp.rut(25000201), 'Individual', 'Directiva'))))->>'inscritas')::int,
  1,
  'La Directiva inscribe individualmente una alumna'
);

-- =============================================================================
-- Autorizaciones y activación de la matrícula (US-10, US-11, TC-06)
-- =============================================================================
CREATE TEMP TABLE _alumna AS SELECT id FROM public.alumnas WHERE rut = pg_temp.rut(25000003);
GRANT SELECT ON _alumna TO authenticated;

SELECT throws_ok(
  $$ UPDATE public.inscripciones SET estado = 'activa' WHERE alumna_id = (SELECT id FROM _alumna) $$,
  '22023', NULL,
  'La inscripción no pasa a activa sin el consentimiento de datos (TC-06)'
);
SELECT throws_ok(
  $$ INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
     SELECT '29a00000-0000-0000-0000-000000000002', i.id, 'presente', auth.uid()
     FROM public.inscripciones i WHERE i.alumna_id = (SELECT id FROM _alumna) AND i.instancia_curso_id = '19a00000-0000-0000-0000-000000000001' $$,
  '22023', NULL,
  'No se registra asistencia de una alumna sin consentimiento'
);
SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.registrar_autorizaciones((SELECT id FROM _alumna), 'otorgada', '{}'::jsonb, (SELECT id FROM _alumna)::text || '/firma.pdf') $$,
  '42501', NULL,
  'Gestión no registra autorizaciones'
);
SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');
SELECT throws_ok(
  $$ SELECT public.registrar_autorizaciones((SELECT id FROM _alumna), 'otorgada', '{}'::jsonb) $$,
  '22023', NULL,
  'Otorgar el tratamiento de datos exige el documento firmado'
);
SELECT throws_ok(
  $$ SELECT public.registrar_autorizaciones((SELECT id FROM _alumna), 'otorgada', '{"tiktok": true}'::jsonb, (SELECT id FROM _alumna)::text || '/firma.pdf') $$,
  '22023', NULL,
  'Un canal desconocido se rechaza'
);
SELECT throws_ok(
  $$ SELECT public.registrar_autorizaciones((SELECT id FROM _alumna), 'otorgada', '{}'::jsonb, 'otra-alumna/firma.pdf') $$,
  '22023', NULL,
  'El respaldo debe estar en la carpeta de la alumna'
);
SELECT lives_ok(
  $$ SELECT public.registrar_autorizaciones(
       (SELECT id FROM _alumna), 'otorgada',
       '{"redes_sociales": true, "prensa": true}'::jsonb,
       (SELECT id FROM _alumna)::text || '/firma.pdf', current_date - 20
     ) $$,
  'La Directiva registra las autorizaciones con su respaldo'
);
SELECT is(
  (SELECT estado::text FROM public.inscripciones WHERE alumna_id = (SELECT id FROM _alumna) AND instancia_curso_id = '19a00000-0000-0000-0000-000000000001'),
  'activa',
  'Al otorgar el tratamiento de datos la inscripción pasa sola a activa'
);
SELECT is(
  (SELECT registrado_por FROM public.autorizaciones_apoderado WHERE alumna_id = (SELECT id FROM _alumna)),
  'd9000000-0000-0000-0000-000000000001'::uuid,
  'El registro guarda a la usuaria responsable'
);
SELECT is(
  (SELECT jsonb_object_agg(canal, autorizado) FROM public.autorizaciones_imagen_canales c
   JOIN public.autorizaciones_apoderado a ON a.id = c.autorizacion_id WHERE a.alumna_id = (SELECT id FROM _alumna)),
  '{"redes_sociales": true, "sitio_web": false, "memoria_anual": false, "reporte_patrocinantes": false, "interno": false, "prensa": true}'::jsonb,
  'Los canales sin respuesta quedan no autorizados (RB-2)'
);

SELECT is(
  (SELECT estado::text FROM public.inscripciones WHERE alumna_id = (SELECT id FROM _alumna) AND instancia_curso_id = '19b00000-0000-0000-0000-000000000001'),
  'activa',
  'El consentimiento activa también su inscripción en la otra sede'
);
SELECT is(
  ((public.importar_alumnas(
    (SELECT id FROM public.instancias_curso WHERE id = '19b00000-0000-0000-0000-000000000001'),
    jsonb_build_array(pg_temp.fila(1, pg_temp.rut(25000004)))
  ))->>'inscritas')::int,
  1,
  'La Directiva inscribe otra alumna en la sede B'
);

-- =============================================================================
-- Pendientes de regularización (US-11 escenario 3)
-- =============================================================================
SELECT pg_temp.como_sistema();
-- Las inscripciones de la sede A se hicieron "hace 20 días": ya pasaron 2 sesiones
UPDATE public.inscripciones SET fecha_inscripcion = current_date - 20
WHERE instancia_curso_id = '19a00000-0000-0000-0000-000000000001';
INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
SELECT '29a00000-0000-0000-0000-000000000001', id, 'presente', '99a00000-0000-0000-0000-000000000001'
FROM public.inscripciones WHERE alumna_id = (SELECT id FROM _alumna) AND instancia_curso_id = '19a00000-0000-0000-0000-000000000001';

SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT is_empty($$ SELECT 1 FROM public.nomina_alumnas $$, 'Gestión no ve la nómina administrativa');
SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(
  (SELECT count(*)::int FROM public.nomina_alumnas WHERE regularizacion_urgente AND sede_nombre = 'Sede Nómina A'),
  28,
  'Las 28 preinscritas de la sede A figuran destacadas tras 2 sesiones sin consentimiento'
);
SELECT is(
  (SELECT clases_asistidas || '/' || clases_computables || ' ' || tratamiento_datos || ' ' || autoriza_fotos FROM public.nomina_alumnas WHERE alumna_id = (SELECT id FROM _alumna) AND sede_nombre = 'Sede Nómina A'),
  '1/2 otorgada true',
  'La nómina trae asistencia, consentimiento y aptitud para fotos'
);

-- =============================================================================
-- Revocación de imagen y aptitud de evidencias (US-12, TC-12)
-- =============================================================================
SELECT pg_temp.como_sistema();
INSERT INTO public.evidencias_fotograficas (id, clase_id, archivo_url, apta_para_evidencia, rostros_censurados, subida_por) VALUES
  ('e9000000-0000-0000-0000-000000000001', '29a00000-0000-0000-0000-000000000001', 'evidencias/1.jpg', true, false, '99a00000-0000-0000-0000-000000000001'),
  ('e9000000-0000-0000-0000-000000000002', '29a00000-0000-0000-0000-000000000002', 'evidencias/2.jpg', true, false, '99a00000-0000-0000-0000-000000000001'),
  ('e9000000-0000-0000-0000-000000000003', '29a00000-0000-0000-0000-000000000002', 'evidencias/3.jpg', true, true, '99a00000-0000-0000-0000-000000000001');
INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por)
SELECT '29a00000-0000-0000-0000-000000000002', id, 'presente', '99a00000-0000-0000-0000-000000000001'
FROM public.inscripciones WHERE alumna_id = (SELECT id FROM _alumna) AND instancia_curso_id = '19a00000-0000-0000-0000-000000000001';

SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.revocar_autorizacion_imagen((SELECT id FROM _alumna), ARRAY['prensa']::public.tipo_canal_imagen[], current_date, 'Solicitud') $$,
  '42501', NULL,
  'Gestión no revoca autorizaciones'
);
SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');
SELECT ok(
  public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000002', 'prensa'),
  'Antes de revocar, la foto es apta para prensa'
);
SELECT ok(
  NOT public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000002', 'sitio_web'),
  'Un canal que nunca se autorizó no es apto'
);
SELECT throws_ok(
  $$ SELECT public.revocar_autorizacion_imagen((SELECT id FROM _alumna), ARRAY['sitio_web']::public.tipo_canal_imagen[], current_date, 'Solicitud') $$,
  '22023', NULL,
  'No se revoca un canal que no estaba autorizado'
);
SELECT throws_ok(
  $$ SELECT public.revocar_autorizacion_imagen((SELECT id FROM _alumna), ARRAY['prensa']::public.tipo_canal_imagen[], current_date, '  ') $$,
  '22023', NULL,
  'La revocación exige un motivo'
);
SELECT throws_ok(
  $$ SELECT public.revocar_autorizacion_imagen((SELECT id FROM _alumna), ARRAY['prensa']::public.tipo_canal_imagen[], current_date + 1, 'Solicitud') $$,
  '22023', NULL,
  'La fecha de la solicitud no puede ser futura'
);
-- Revocación con fecha D = hace 10 días: entre la sesión 1 (hace 14) y la 2 (hace 7)
SELECT lives_ok(
  $$ SELECT public.revocar_autorizacion_imagen((SELECT id FROM _alumna), ARRAY['prensa']::public.tipo_canal_imagen[], current_date - 10, 'El apoderado lo solicitó por correo') $$,
  'Se registra la revocación de prensa con su fecha'
);
SELECT ok(
  NOT public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000002', 'prensa'),
  'Las fotos desde la fecha D dejan de ser aptas para prensa'
);
SELECT ok(
  public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000001', 'prensa'),
  'Las fotos anteriores a la fecha D conservan su aptitud'
);
SELECT ok(
  public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000002', 'redes_sociales'),
  'Los canales no revocados siguen aptos'
);
SELECT ok(
  public.evidencia_apta_canal('e9000000-0000-0000-0000-000000000003', 'prensa'),
  'Una foto con rostros censurados sigue apta'
);
SELECT is(
  (SELECT motivo_revocacion || ' ' || (fecha_revocacion = current_date - 10)::text FROM public.autorizaciones_imagen_canales c
   JOIN public.autorizaciones_apoderado a ON a.id = c.autorizacion_id WHERE a.alumna_id = (SELECT id FROM _alumna) AND canal = 'prensa'),
  'El apoderado lo solicitó por correo true',
  'El canal guarda la fecha y el motivo de la revocación'
);

-- =============================================================================
-- Retiro formal (US-09 escenario 3)
-- =============================================================================
CREATE TEMP TABLE _insc AS
SELECT id FROM public.inscripciones WHERE alumna_id = (SELECT id FROM _alumna) AND instancia_curso_id = '19a00000-0000-0000-0000-000000000001';
GRANT SELECT ON _insc TO authenticated;

SELECT throws_ok(
  $$ SELECT public.retirar_inscripcion((SELECT id FROM _insc), current_date, '') $$,
  '22023', NULL,
  'El retiro exige un motivo formal'
);
SELECT throws_ok(
  $$ SELECT public.retirar_inscripcion((SELECT id FROM _insc), current_date - 40, 'Cambio de colegio') $$,
  '22023', NULL,
  'La fecha de retiro no puede ser anterior a la inscripción'
);
SELECT throws_ok(
  $$ UPDATE public.inscripciones SET estado = 'retirada' WHERE id = (SELECT id FROM _insc) $$,
  '23514', NULL,
  'Un retiro sin fecha ni motivo no se guarda'
);
SELECT is(
  (SELECT estado::text || ' ' || motivo_retiro FROM public.retirar_inscripcion((SELECT id FROM _insc), current_date, 'Cambio de colegio')),
  'retirada Cambio de colegio',
  'La Directiva registra el retiro con fecha y motivo'
);
SELECT is(
  (SELECT count(*)::int FROM public.asistencia_alumnas WHERE inscripcion_id = (SELECT id FROM _insc)),
  2,
  'El retiro conserva su historial de asistencia'
);
SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.retirar_inscripcion((SELECT id FROM _insc), current_date, 'Intento de Gestión') $$,
  '42501', NULL,
  'Gestión no registra retiros'
);

-- =============================================================================
-- Respaldo firmado en el bucket privado (US-10 escenario 3)
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT public::text FROM storage.buckets WHERE id = 'autorizaciones'),
  'false',
  'El bucket de respaldos es privado'
);
CREATE TEMP TABLE _alumna_a AS SELECT id FROM public.alumnas WHERE rut = pg_temp.rut(25000005);
GRANT SELECT ON _alumna_a TO authenticated;
SELECT pg_temp.actuar_como('99a00000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ INSERT INTO storage.objects (bucket_id, name) VALUES ('autorizaciones', (SELECT id FROM _alumna_a)::text || '/ajeno.pdf') $$,
  '42501', NULL,
  'Gestión no sube respaldos de alumnas'
);
SELECT pg_temp.actuar_como('d9000000-0000-0000-0000-000000000001', 'aal2');
SELECT throws_ok(
  $$ INSERT INTO storage.objects (bucket_id, name) VALUES ('autorizaciones', 'cualquiera/firma.pdf') $$,
  '42501', NULL,
  'Un respaldo fuera de la carpeta de una alumna se rechaza'
);
SELECT lives_ok(
  $$ INSERT INTO storage.objects (bucket_id, name) VALUES ('autorizaciones', (SELECT id FROM _alumna)::text || '/firma.pdf') $$,
  'La Directiva sube el respaldo a la carpeta de la alumna'
);

SELECT * FROM finish();
ROLLBACK;
