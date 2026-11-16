BEGIN;
SELECT plan(84);

-- =============================================================================
-- Datos de prueba: dos sedes con un curso cada una. En la sede A, Gestión y dos
-- tutoras con su ficha y asignadas al curso; en la sede B, Gestión y una
-- tutora. Una cuenta del voluntariado de la sede A aún sin ficha.
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
LANGUAGE sql AS $$ SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000001', 'aal2'); $$;

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

-- Fila de una planilla de voluntariado
CREATE OR REPLACE FUNCTION pg_temp.fila(p_fila int, p_rut text, p_correo text, p_rol text DEFAULT 'Tutora')
RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_build_object(
    'fila', p_fila, 'rut', p_rut, 'nombres', 'Voluntaria', 'apellidos', 'Fila ' || p_fila,
    'correo', p_correo, 'telefono', '+56 9 5555 00' || lpad(p_fila::text, 2, '0'),
    'institucion', 'Universidad de Prueba', 'rol', p_rol, 'fecha_ingreso', ''
  );
$$;

-- Resultado de una fila en la respuesta de importar_voluntarias
CREATE OR REPLACE FUNCTION pg_temp.fila_resultado(p_respuesta jsonb, p_fila int) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT f FROM jsonb_array_elements(p_respuesta->'filas') AS f WHERE (f->>'fila')::int = p_fila;
$$;

CREATE OR REPLACE FUNCTION pg_temp.ficha(p_rut text) RETURNS public.voluntarios_detalle
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.voluntarios_detalle WHERE public.normalizar_rut(rut) = public.normalizar_rut(p_rut);
$$;

CREATE OR REPLACE FUNCTION pg_temp.roles_de(p_clase uuid, p_tutor uuid) RETURNS bigint
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT count(*) FROM public.tareas_semanales_tutores WHERE clase_id = p_clase AND tutor_id = p_tutor;
$$;

CREATE OR REPLACE FUNCTION pg_temp.tarea(p_clase uuid, p_tutor uuid, p_rol uuid) RETURNS public.tareas_semanales_tutores
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.tareas_semanales_tutores
  WHERE clase_id = p_clase AND tutor_id = p_tutor AND rol_tarea_tutor_id = p_rol;
$$;

CREATE TEMP TABLE resultado (clave text PRIMARY KEY, valor jsonb);
GRANT ALL ON resultado TO authenticated;

INSERT INTO public.sedes (id, nombre) VALUES
  ('f2a00000-0000-0000-0000-00000000000a', 'Sede Voluntariado A'),
  ('f2b00000-0000-0000-0000-00000000000b', 'Sede Voluntariado B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('f2c00000-0000-0000-0000-000000000001', 'Curso Voluntariado', 'VOL');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('f2100000-0000-0000-0000-00000000000a', 'f2c00000-0000-0000-0000-000000000001', 'f2a00000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60),
  ('f2100000-0000-0000-0000-00000000000b', 'f2c00000-0000-0000-0000-000000000001', 'f2b00000-0000-0000-0000-00000000000b', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado, motivo_suspension) VALUES
  ('f2200000-0000-0000-0000-000000000001', 'f2100000-0000-0000-0000-00000000000a', 1, public.hoy_chile() - 7, 'realizada', NULL),
  ('f2200000-0000-0000-0000-000000000002', 'f2100000-0000-0000-0000-00000000000a', 2, public.hoy_chile(), 'programada', NULL),
  ('f2200000-0000-0000-0000-000000000003', 'f2100000-0000-0000-0000-00000000000a', 3, public.hoy_chile() + 7, 'programada', NULL),
  ('f2200000-0000-0000-0000-000000000004', 'f2100000-0000-0000-0000-00000000000a', 4, public.hoy_chile() - 14, 'suspendida', 'Paro');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('vol.directiva@ninaspro.cl', 'directorio', NULL, '21.190.001-6', 'Directiva', 'Voluntariado', NULL),
  ('vol.gestion.a@ninaspro.cl', 'equipo_gestion', 'f2a00000-0000-0000-0000-00000000000a', '21.190.002-4', 'Gestión', 'A', NULL),
  ('vol.gestion.b@ninaspro.cl', 'equipo_gestion', 'f2b00000-0000-0000-0000-00000000000b', '21.190.003-2', 'Gestión', 'B', NULL),
  ('vol.tutora.a1@ninaspro.cl', 'tutora', 'f2a00000-0000-0000-0000-00000000000a', '21.190.004-0', 'Tutora', 'A1', NULL),
  ('vol.tutora.a2@ninaspro.cl', 'tutora', 'f2a00000-0000-0000-0000-00000000000a', '21.190.005-9', 'Tutora', 'A2', NULL),
  ('vol.tutora.b@ninaspro.cl', 'tutora', 'f2b00000-0000-0000-0000-00000000000b', '21.190.006-7', 'Tutora', 'B', NULL),
  ('vol.sinficha@ninaspro.cl', 'tutora', 'f2a00000-0000-0000-0000-00000000000a', '21.190.007-5', 'Cuenta', 'Sin Ficha', NULL);
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000001', 'vol.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000002', 'vol.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000003', 'vol.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000004', 'vol.tutora.a1@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000005', 'vol.tutora.a2@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000006', 'vol.tutora.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000007', 'vol.sinficha@ninaspro.cl');

-- Fichas creadas solo con la cuenta: el resto de los datos sale del perfil
INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada) VALUES
  ('f1000000-0000-0000-0000-000000000002', '2025-03-01', true),
  ('f1000000-0000-0000-0000-000000000003', '2025-03-01', true),
  ('f1000000-0000-0000-0000-000000000004', '2025-03-01', true),
  ('f1000000-0000-0000-0000-000000000005', '2025-03-01', true),
  ('f1000000-0000-0000-0000-000000000006', '2025-03-01', true);
INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
  ('f2100000-0000-0000-0000-00000000000a', 'f1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001'),
  ('f2100000-0000-0000-0000-00000000000a', 'f1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001'),
  ('f2100000-0000-0000-0000-00000000000a', 'f1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001'),
  ('f2100000-0000-0000-0000-00000000000b', 'f1000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000001');

INSERT INTO public.rol_tarea_tutor (id, codigo, nombre, es_requerido) VALUES
  ('f2300000-0000-0000-0000-000000000001', 'vol_presentar', 'Vol Presentar', true),
  ('f2300000-0000-0000-0000-000000000002', 'vol_kahoot', 'Vol Kahoot', false);
INSERT INTO public.rol_tarea_tutor (id, codigo, nombre, activo) VALUES
  ('f2300000-0000-0000-0000-000000000003', 'vol_antiguo', 'Vol Antiguo', false);

-- =============================================================================
-- 1. Ficha independiente de la cuenta (US-30)
-- =============================================================================
SELECT is(
  (SELECT row(rut, nombres, apellidos, correo, rol::text, sede_id)::text FROM pg_temp.ficha('21.190.002-4')),
  row('21.190.002-4', 'Gestión', 'A', 'vol.gestion.a@ninaspro.cl', 'equipo_gestion', 'f2a00000-0000-0000-0000-00000000000a'::uuid)::text,
  'La ficha creada con la cuenta toma el RUT, nombre, correo, rol y sede del perfil'
);

-- =============================================================================
-- 2. Carga masiva: solo la Directiva, vista previa y filas rechazadas (US-30 E1)
-- =============================================================================
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT throws_ok(
  $$ SELECT public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', jsonb_build_array(pg_temp.fila(2, '21.190.008-3', 'vol.n8@ninaspro.cl'))) $$,
  '42501', 'Solo la Directiva carga fichas de voluntariado.',
  'Gestión no carga fichas de voluntariado'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000001', 'aal1');
SELECT throws_ok(
  $$ SELECT public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', jsonb_build_array(pg_temp.fila(2, '21.190.008-3', 'vol.n8@ninaspro.cl'))) $$,
  '42501', NULL,
  'La Directiva sin su segundo factor no carga fichas'
);

-- Planilla de 8 filas con 2 RUT inválidos (TC-18)
SELECT pg_temp.como_directiva();
INSERT INTO resultado VALUES ('planilla', jsonb_build_array(
  pg_temp.fila(2, '21.190.008-3', 'vol.n8@ninaspro.cl'),
  pg_temp.fila(3, '21.190.009-1', 'vol.n9@ninaspro.cl', 'Equipo de Gestión'),
  pg_temp.fila(4, '21.190.010-5', 'vol.n10@ninaspro.cl'),
  pg_temp.fila(5, '21.190.014-1', 'vol.malo1@ninaspro.cl'),
  pg_temp.fila(6, '21.190.011-3', 'VOL.N11@ninaspro.cl '),
  pg_temp.fila(7, '12.345.678-0', 'vol.malo2@ninaspro.cl'),
  pg_temp.fila(8, '21.190.012-1', 'vol.n12@ninaspro.cl', 'tutor'),
  pg_temp.fila(9, '21190013K', 'vol.n13@ninaspro.cl')
));
INSERT INTO resultado
SELECT 'vista_previa', public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', valor, true)
FROM resultado WHERE clave = 'planilla';
SELECT is(
  (SELECT jsonb_build_array(valor->'creadas', valor->'rechazadas') FROM resultado WHERE clave = 'vista_previa'),
  '[6, 2]'::jsonb,
  'La vista previa cuenta 6 fichas nuevas y 2 filas rechazadas'
);
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT count(*) FROM public.voluntarios_detalle WHERE correo LIKE 'vol.n%@ninaspro.cl'),
  0::bigint,
  'La vista previa no escribe fichas'
);

SELECT pg_temp.como_directiva();
INSERT INTO resultado
SELECT 'carga', public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', valor)
FROM resultado WHERE clave = 'planilla';
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT count(*) FROM public.voluntarios_detalle WHERE correo LIKE 'vol.n%@ninaspro.cl' AND sede_id = 'f2a00000-0000-0000-0000-00000000000a'),
  6::bigint,
  'La carga crea las 6 fichas válidas en la sede de destino'
);
SELECT is(
  (SELECT count(*) FROM public.correos_autorizados WHERE correo LIKE 'vol.n%@ninaspro.cl' AND usado_en IS NULL AND sede_id = 'f2a00000-0000-0000-0000-00000000000a'),
  6::bigint,
  'Cada ficha nueva deja autorizado su correo para crear la cuenta'
);
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 5)->>'motivo' FROM resultado WHERE clave = 'carga'),
  'RUT inválido (dígito verificador)',
  'La fila rechazada informa su motivo para el reporte'
);
SELECT is(
  (SELECT jsonb_build_array(pg_temp.fila_resultado(valor, 7)->>'estado', pg_temp.fila_resultado(valor, 2)->>'estado') FROM resultado WHERE clave = 'carga'),
  '["invalida", "nueva"]'::jsonb,
  'Las filas quedan marcadas como inválidas o nuevas'
);
SELECT is(
  (SELECT row(rol::text, rut, correo)::text FROM pg_temp.ficha('21.190.009-1')),
  row('equipo_gestion', '21.190.009-1', 'vol.n9@ninaspro.cl')::text,
  'El rol "Equipo de Gestión" de la planilla se reconoce'
);
SELECT is(
  (SELECT row(rut, correo, rol::text)::text FROM pg_temp.ficha('21.190.013-K')),
  row('21.190.013-K', 'vol.n13@ninaspro.cl', 'tutora')::text,
  'El RUT se guarda con formato y el correo en minúsculas'
);
SELECT is(
  (SELECT correo FROM pg_temp.ficha('21.190.011-3')),
  'vol.n11@ninaspro.cl',
  'El correo se normaliza sin espacios ni mayúsculas'
);
SELECT is(
  (SELECT row(declaracion_adhesion_firmada, perfil_id IS NULL, fecha_ingreso = public.hoy_chile())::text FROM pg_temp.ficha('21.190.008-3')),
  row(false, true, true)::text,
  'La ficha nueva queda sin adhesión, sin cuenta y con ingreso hoy'
);

-- =============================================================================
-- 3. Validaciones de cada fila
-- =============================================================================
SELECT pg_temp.como_directiva();
INSERT INTO resultado
SELECT 'validaciones', public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', jsonb_build_array(
  pg_temp.fila(2, '21.190.015-6', 'vol.n15@gmail.com'),
  pg_temp.fila(3, '21.190.016-4', 'vol.dup@ninaspro.cl'),
  pg_temp.fila(4, '21.190.016-4', 'vol.dup2@ninaspro.cl'),
  pg_temp.fila(5, '21.190.017-2', 'vol.n8@ninaspro.cl'),
  pg_temp.fila(6, '21.190.018-0', 'vol.n18@ninaspro.cl', 'Coordinadora'),
  pg_temp.fila(7, '21.190.008-3', 'vol.otro@ninaspro.cl'),
  pg_temp.fila(8, '21.190.019-9', 'vol.n19@ninaspro.cl') || '{"fecha_ingreso": "2999-01-01"}'
), true);
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 2)->>'motivo' FROM resultado WHERE clave = 'validaciones'),
  'El voluntariado usa su correo institucional @ninaspro.cl',
  'Se rechaza un correo que no es institucional'
);
SELECT ok(
  (SELECT pg_temp.fila_resultado(valor, 3)->>'motivo' LIKE 'RUT repetido en la planilla (filas 3, 4)%'
      AND pg_temp.fila_resultado(valor, 4)->>'estado' = 'invalida'
   FROM resultado WHERE clave = 'validaciones'),
  'Un RUT repetido en la planilla rechaza ambas filas'
);
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 5)->>'motivo' FROM resultado WHERE clave = 'validaciones'),
  'El correo ya lo usa otra persona',
  'Se rechaza el correo de otra persona'
);
SELECT ok(
  (SELECT pg_temp.fila_resultado(valor, 6)->>'motivo' LIKE 'Rol desconocido "Coordinadora"%' FROM resultado WHERE clave = 'validaciones'),
  'Se rechaza un rol que no es Tutora ni Equipo de Gestión'
);
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 7)->>'motivo' FROM resultado WHERE clave = 'validaciones'),
  'Este RUT ya tiene ficha con el correo vol.n8@ninaspro.cl',
  'Un RUT con ficha no cambia de correo desde la planilla'
);
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 8)->>'motivo' FROM resultado WHERE clave = 'validaciones'),
  'La fecha de ingreso no puede ser futura',
  'La fecha de ingreso no puede ser futura'
);

-- =============================================================================
-- 4. Ficha única por RUT en varias sedes y cuentas sin ficha (US-30 E2 y E3)
-- =============================================================================
SELECT pg_temp.como_directiva();
INSERT INTO resultado
SELECT 'otra_sede', public.importar_voluntarias('f2b00000-0000-0000-0000-00000000000b', jsonb_build_array(
  pg_temp.fila(2, '21.190.004-0', 'vol.tutora.a1@ninaspro.cl'),
  pg_temp.fila(3, '21.190.007-5', 'vol.sinficha@ninaspro.cl')
));
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT pg_temp.fila_resultado(valor, 2)->>'estado' FROM resultado WHERE clave = 'otra_sede'),
  'existente',
  'Un RUT que ya tiene ficha se informa como existente'
);
SELECT is(
  (SELECT count(*) FROM public.voluntarios_detalle WHERE public.normalizar_rut(rut) = '211900040'),
  1::bigint,
  'La ficha sigue siendo una sola por RUT'
);
SELECT ok(
  EXISTS (SELECT 1 FROM public.usuarios_sedes WHERE perfil_id = 'f1000000-0000-0000-0000-000000000004' AND sede_id = 'f2b00000-0000-0000-0000-00000000000b')
  AND EXISTS (SELECT 1 FROM public.usuarios_sedes WHERE perfil_id = 'f1000000-0000-0000-0000-000000000004' AND sede_id = 'f2a00000-0000-0000-0000-00000000000a'),
  'La cuenta suma la nueva sede sin perder la anterior'
);
SELECT is(
  (SELECT row(perfil_id, sede_id, fecha_ingreso = public.hoy_chile())::text FROM pg_temp.ficha('21.190.007-5')),
  row('f1000000-0000-0000-0000-000000000007'::uuid, 'f2b00000-0000-0000-0000-00000000000b'::uuid, true)::text,
  'Una cuenta del voluntariado sin ficha recibe su ficha vinculada a la cuenta'
);

-- Alta individual: la misma RPC con una fila (US-30 E3)
SELECT pg_temp.como_directiva();
INSERT INTO resultado
SELECT 'alta', public.importar_voluntarias('f2a00000-0000-0000-0000-00000000000a', jsonb_build_array(pg_temp.fila(1, '21.190.020-2', 'vol.alta@ninaspro.cl')));
SELECT is(
  (SELECT jsonb_build_array(valor->'creadas', pg_temp.fila_resultado(valor, 1)->>'ficha_id' IS NOT NULL) FROM resultado WHERE clave = 'alta'),
  '[1, true]'::jsonb,
  'El alta individual crea la ficha y devuelve su id'
);

-- =============================================================================
-- 5. La cuenta creada después queda vinculada a la ficha
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT pg_temp.crear_usuario('f1000000-0000-0000-0000-000000000008', 'vol.n8@ninaspro.cl');
SELECT is(
  (SELECT perfil_id FROM pg_temp.ficha('21.190.008-3')),
  'f1000000-0000-0000-0000-000000000008'::uuid,
  'Al crear su cuenta, la ficha queda vinculada por el RUT'
);
SELECT is(
  (SELECT row(p.rol::text, p.telefono, us.sede_id)::text FROM public.perfiles p JOIN public.usuarios_sedes us ON us.perfil_id = p.id
   WHERE p.id = 'f1000000-0000-0000-0000-000000000008'),
  row('tutora', '+56 9 5555 0002', 'f2a00000-0000-0000-0000-00000000000a'::uuid)::text,
  'La cuenta toma el rol, el teléfono y la sede de la ficha'
);

-- =============================================================================
-- 6. Declaración de adhesión y rol (US-31 E2)
-- =============================================================================
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT throws_ok(
  format($$ SELECT public.registrar_adhesion_voluntaria(%L, true, public.hoy_chile()) $$, (pg_temp.ficha('21.190.008-3')).id),
  '42501', 'Solo la Directiva registra la declaración de adhesión.',
  'Gestión no registra la adhesión'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.registrar_adhesion_voluntaria(%L, true) $$, (pg_temp.ficha('21.190.008-3')).id),
  '22023', 'Indica la fecha en que firmó la declaración.',
  'La adhesión firmada lleva su fecha'
);
SELECT throws_ok(
  format($$ SELECT public.registrar_adhesion_voluntaria(%L, true, public.hoy_chile() + 1) $$, (pg_temp.ficha('21.190.008-3')).id),
  '22023', 'La fecha de firma no puede ser futura.',
  'La fecha de firma no puede ser futura'
);
SELECT lives_ok(
  format($$ SELECT public.registrar_adhesion_voluntaria(%L, true, public.hoy_chile() - 2) $$, (pg_temp.ficha('21.190.008-3')).id),
  'La Directiva registra la adhesión con su fecha'
);
SELECT is(
  (SELECT row(declaracion_adhesion_firmada, fecha_firma_declaracion::date = public.hoy_chile() - 2)::text FROM pg_temp.ficha('21.190.008-3')),
  row(true, true)::text,
  'La ficha queda con la adhesión firmada y su fecha'
);

SELECT lives_ok(
  format($$ SELECT public.cambiar_rol_voluntaria(%L, 'equipo_gestion') $$, (pg_temp.ficha('21.190.008-3')).id),
  'La Directiva pasa a una tutora al Equipo de Gestión'
);
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT row(v.rol::text, p.rol::text)::text FROM public.voluntarios_detalle v JOIN public.perfiles p ON p.id = v.perfil_id
   WHERE v.perfil_id = 'f1000000-0000-0000-0000-000000000008'),
  row('equipo_gestion', 'equipo_gestion')::text,
  'El cambio de rol se aplica a la ficha y a la cuenta'
);
SELECT pg_temp.como_directiva();
SELECT public.cambiar_rol_voluntaria((pg_temp.ficha('21.190.010-5')).id, 'equipo_gestion');
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT rol::text FROM public.correos_autorizados WHERE correo = 'vol.n10@ninaspro.cl' AND usado_en IS NULL),
  'equipo_gestion',
  'Sin cuenta, el cambio de rol se aplica a su autorización pendiente'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.cambiar_rol_voluntaria(%L, 'directorio') $$, (pg_temp.ficha('21.190.010-5')).id),
  '22023', 'El voluntariado es Tutora o Equipo de Gestión.',
  'El voluntariado no pasa a la Directiva desde su ficha'
);

-- =============================================================================
-- 7. Asignación a cursos: solo la Directiva (US-31 E1 y E3)
-- =============================================================================
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT throws_ok(
  $$ INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por)
     VALUES ('f2100000-0000-0000-0000-00000000000a', 'f1000000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000002') $$,
  '42501', NULL,
  'Gestión no asigna tutoras a los cursos directamente'
);
SELECT throws_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000a') $$, (pg_temp.ficha('21.190.008-3')).id),
  '42501', 'Solo la Directiva asigna tutoras a los cursos.',
  'Gestión no asigna tutoras a los cursos con la RPC'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000a') $$, (pg_temp.ficha('21.190.011-3')).id),
  '22023', 'Para asignarla a un curso, la voluntaria debe tener firmada la declaración de adhesión.',
  'No se asigna a un curso a quien no firmó la adhesión'
);
SELECT public.registrar_adhesion_voluntaria((pg_temp.ficha('21.190.011-3')).id, true, public.hoy_chile());
SELECT throws_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000a') $$, (pg_temp.ficha('21.190.011-3')).id),
  '22023', 'Aún no crea su cuenta con vol.n11@ninaspro.cl: podrás asignarla cuando entre por primera vez.',
  'No se asigna a un curso a quien aún no crea su cuenta'
);
SELECT lives_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000b') $$, (pg_temp.ficha('21.190.008-3')).id),
  'La Directiva asigna a una voluntaria habilitada a un curso de otra sede'
);
SELECT pg_temp.como_sistema();
SELECT ok(
  EXISTS (SELECT 1 FROM public.tutores_instancia WHERE instancia_curso_id = 'f2100000-0000-0000-0000-00000000000b' AND tutor_id = 'f1000000-0000-0000-0000-000000000008')
  AND EXISTS (SELECT 1 FROM public.usuarios_sedes WHERE perfil_id = 'f1000000-0000-0000-0000-000000000008' AND sede_id = 'f2b00000-0000-0000-0000-00000000000b'),
  'La asignación queda en tutores_instancia y su cuenta suma la sede del curso'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000b') $$, (pg_temp.ficha('21.190.008-3')).id),
  '22023', 'Ya está asignada a este curso.',
  'No se asigna dos veces al mismo curso'
);
SELECT lives_ok(
  format($$ SELECT public.quitar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000b') $$, (pg_temp.ficha('21.190.008-3')).id),
  'Se quita una asignación hecha por error si aún no tiene clases'
);
SELECT throws_ok(
  format($$ SELECT public.quitar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000b') $$, (pg_temp.ficha('21.190.002-4')).id),
  '22023', 'No está asignada a este curso.',
  'Quitar exige que esté asignada'
);

-- =============================================================================
-- 8. Directorio del voluntariado (US-32 E1)
-- =============================================================================
SELECT pg_temp.como_directiva();
SELECT is(
  (SELECT count(*) FROM public.voluntariado WHERE correo LIKE 'vol.%@ninaspro.cl'),
  13::bigint,
  'La Directiva ve todas las fichas, con o sin cuenta'
);
SELECT is(
  (SELECT row(estado, cuenta, jsonb_array_length(cursos))::text FROM public.voluntariado WHERE correo = 'vol.tutora.a1@ninaspro.cl'),
  row('activa', 'activa', 1)::text,
  'El directorio muestra el estado, la cuenta y los cursos de cada voluntaria'
);
SELECT is(
  (SELECT cuenta FROM public.voluntariado WHERE correo = 'vol.n9@ninaspro.cl'),
  'autorizada',
  'Una ficha sin cuenta figura con su correo autorizado'
);
SELECT ok(
  (SELECT sede_ids @> ARRAY['f2a00000-0000-0000-0000-00000000000a'::uuid, 'f2b00000-0000-0000-0000-00000000000b'::uuid]
   FROM public.voluntariado WHERE correo = 'vol.tutora.a1@ninaspro.cl'),
  'El filtro por sede considera todas las sedes de la voluntaria'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000003');
SELECT is(
  (SELECT count(*) FROM public.voluntariado WHERE sede_id = 'f2a00000-0000-0000-0000-00000000000a' AND perfil_id IS NULL),
  0::bigint,
  'Gestión de otra sede no ve las fichas sin cuenta de la sede A'
);
SELECT throws_ok(
  $$ UPDATE public.voluntarios_detalle SET declaracion_adhesion_firmada = true $$,
  '42501', NULL,
  'Nadie edita las fichas directamente'
);

-- =============================================================================
-- 9. Catálogo de roles (US-43 E1)
-- =============================================================================
SELECT pg_temp.como_directiva();
SELECT lives_ok(
  $$ INSERT INTO public.rol_tarea_tutor (id, nombre, descripcion, color_hex) VALUES ('f2300000-0000-0000-0000-000000000004', 'Logística', 'Mesas y equipos', '#1D5CA5') $$,
  'La Directiva crea un rol sin indicar el código'
);
SELECT ok(
  (SELECT codigo LIKE 'rol_%' FROM public.rol_tarea_tutor WHERE id = 'f2300000-0000-0000-0000-000000000004'),
  'El código del rol se genera solo'
);
SELECT throws_ok(
  $$ INSERT INTO public.rol_tarea_tutor (nombre) VALUES ('  logistica ') $$,
  '23505', NULL,
  'No se repite un nombre de rol aunque cambien tildes, mayúsculas o espacios'
);
SELECT throws_ok(
  $$ UPDATE public.rol_tarea_tutor SET codigo = 'otro' WHERE id = 'f2300000-0000-0000-0000-000000000004' $$,
  '22023', 'El código del rol no se cambia.',
  'El código de un rol no cambia'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT throws_ok(
  $$ INSERT INTO public.rol_tarea_tutor (nombre) VALUES ('Rol de Gestión') $$,
  '42501', NULL,
  'Gestión no administra el catálogo de roles'
);

-- =============================================================================
-- 10. Roles de cada clase: varios por tutora (US-43 E2 y E3)
-- =============================================================================
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT lives_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004',
       ARRAY['f2300000-0000-0000-0000-000000000001', 'f2300000-0000-0000-0000-000000000002']::uuid[]) $$,
  'Gestión de la sede asigna dos roles a una tutora en la misma clase'
);
SELECT is(
  pg_temp.roles_de('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004'),
  2::bigint,
  'La tutora queda con sus dos roles en la clase'
);

-- La tutora marca uno de sus roles (US-44 E2)
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000004');
SELECT lives_ok(
  format($$ SELECT public.marcar_rol_cumplido(%L, true) $$,
    (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000001')).id),
  'La tutora marca como cumplido uno de sus roles'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000005');
SELECT throws_ok(
  format($$ SELECT public.marcar_rol_cumplido(%L, false) $$,
    (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000001')).id),
  '42501', 'Solo la tutora o el Equipo de Gestión de la sede marcan este rol.',
  'Una compañera no marca los roles de otra'
);
-- Las compañeras ven el cumplimiento (US-44 E3)
SELECT is(
  (SELECT tareas FROM public.roles_clase('f2200000-0000-0000-0000-000000000002') WHERE tutor_id = 'f1000000-0000-0000-0000-000000000004'),
  jsonb_build_array(
    jsonb_build_object('id', (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000001')).id,
                       'rol_id', 'f2300000-0000-0000-0000-000000000001', 'completada', true),
    jsonb_build_object('id', (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000002')).id,
                       'rol_id', 'f2300000-0000-0000-0000-000000000002', 'completada', false)
  ),
  'Una compañera ve los roles de la tutora y cuál está cumplido'
);
SELECT is(
  (SELECT count(*) FROM public.roles_clase('f2200000-0000-0000-0000-000000000002')),
  3::bigint,
  'La clase muestra a todo el equipo del curso, con o sin roles'
);

-- Reasignar: se conserva el cumplimiento de los roles que siguen
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004',
  ARRAY['f2300000-0000-0000-0000-000000000001']::uuid[]);
SELECT is(
  (SELECT row(pg_temp.roles_de('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004'),
              (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000001')).completada)::text),
  row(1::bigint, true)::text,
  'Al quitarle un rol, el que sigue conserva su cumplimiento'
);
SELECT lives_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000005',
       ARRAY['f2300000-0000-0000-0000-000000000002']::uuid[]) $$,
  'Gestión pasa un rol a otra tutora ante un imprevisto'
);
SELECT lives_ok(
  format($$ SELECT public.marcar_rol_cumplido(%L, true) $$,
    (pg_temp.tarea('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000005', 'f2300000-0000-0000-0000-000000000002')).id),
  'Gestión de la sede marca el cumplimiento de cualquier tutora'
);
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000006',
       ARRAY['f2300000-0000-0000-0000-000000000001']::uuid[]) $$,
  '22023', 'La tutora no está asignada al curso de esta clase.',
  'Solo se asignan roles a tutoras del curso de la clase'
);
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000004',
       ARRAY['f2300000-0000-0000-0000-000000000001']::uuid[]) $$,
  '22023', 'La clase está suspendida: no se asignan roles.',
  'No se asignan roles en una clase suspendida'
);
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004',
       ARRAY['f2300000-0000-0000-0000-000000000003']::uuid[]) $$,
  '22023', 'Uno de los roles no existe o ya no está activo en el catálogo.',
  'No se asigna un rol inactivo del catálogo'
);
SELECT throws_ok(
  $$ INSERT INTO public.tareas_semanales_tutores (clase_id, tutor_id, rol_tarea_tutor_id)
     VALUES ('f2200000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004', 'f2300000-0000-0000-0000-000000000001') $$,
  '42501', NULL,
  'Los roles de la clase no se escriben directamente'
);

SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000003');
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', '{}'::uuid[]) $$,
  '42501', 'Solo el Equipo de Gestión de la sede asigna los roles de la clase.',
  'Gestión de otra sede no asigna roles'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000006');
SELECT is(
  (SELECT count(*) FROM public.roles_clase('f2200000-0000-0000-0000-000000000002')),
  0::bigint,
  'Una tutora de otra sede no ve los roles de la clase'
);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000004');
SELECT throws_ok(
  $$ SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004',
       ARRAY['f2300000-0000-0000-0000-000000000001']::uuid[]) $$,
  '42501', NULL,
  'Una tutora no se asigna roles'
);

-- Roles futuros para probar la salida
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000002');
SELECT public.guardar_roles_tutora('f2200000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000005',
  ARRAY['f2300000-0000-0000-0000-000000000001', 'f2300000-0000-0000-0000-000000000002']::uuid[]);
SELECT pg_temp.actuar_como('f1000000-0000-0000-0000-000000000005');
SELECT is(
  (SELECT count(*) FROM public.mis_roles_curso('f2100000-0000-0000-0000-00000000000a')),
  3::bigint,
  'La tutora ve sus roles en cada clase de su curso'
);

-- =============================================================================
-- 11. Salida, reincorporación y autorización (US-32 E2)
-- =============================================================================
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.registrar_salida_voluntaria(%L, '2025-02-01') $$, (pg_temp.ficha('21.190.005-9')).id),
  '22023', 'La fecha de salida no puede ser anterior al ingreso (01/03/2025).',
  'La salida no puede ser anterior al ingreso'
);
SELECT throws_ok(
  format($$ SELECT public.registrar_salida_voluntaria(%L, public.hoy_chile() + 1) $$, (pg_temp.ficha('21.190.005-9')).id),
  '22023', 'La fecha de salida no puede ser futura: regístrala el día que se retira.',
  'La salida no puede ser futura'
);
SELECT lives_ok(
  format($$ SELECT public.registrar_salida_voluntaria(%L, public.hoy_chile()) $$, (pg_temp.ficha('21.190.005-9')).id),
  'La Directiva registra la salida de una tutora'
);
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT row(
     (SELECT estado FROM public.voluntariado WHERE correo = 'vol.tutora.a2@ninaspro.cl'),
     (SELECT activo FROM public.perfiles WHERE id = 'f1000000-0000-0000-0000-000000000005'),
     pg_temp.roles_de('f2200000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000005'),
     pg_temp.roles_de('f2200000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000005'),
     (SELECT count(*) FROM public.tutores_instancia WHERE tutor_id = 'f1000000-0000-0000-0000-000000000005')
   )::text),
  row('retirada', false, 0::bigint, 1::bigint, 1::bigint)::text,
  'Al salir queda retirada, sin acceso, sin roles en clases posteriores y con su trayectoria'
);
SELECT is(
  (SELECT count(*) FROM public.lista_asistencia_tutores('f2200000-0000-0000-0000-000000000003') WHERE tutor_id = 'f1000000-0000-0000-0000-000000000005'),
  0::bigint,
  'Quien salió no aparece en el pase de lista de tutoras de clases posteriores'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.asignar_voluntaria_curso(%L, 'f2100000-0000-0000-0000-00000000000b') $$, (pg_temp.ficha('21.190.005-9')).id),
  '22023', 'La voluntaria ya no participa del voluntariado: no se asigna a cursos.',
  'No se asigna a un curso a quien salió'
);
SELECT lives_ok(
  format($$ SELECT public.reincorporar_voluntaria(%L) $$, (pg_temp.ficha('21.190.005-9')).id),
  'La Directiva reincorpora a una voluntaria'
);
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT row(v.fecha_salida IS NULL, p.activo)::text FROM public.voluntarios_detalle v JOIN public.perfiles p ON p.id = v.perfil_id
   WHERE v.perfil_id = 'f1000000-0000-0000-0000-000000000005'),
  row(true, true)::text,
  'Al reincorporarse vuelve a tener acceso'
);

-- Sin cuenta: la salida anula la autorización y la renovación la vuelve a crear
SELECT pg_temp.como_directiva();
SELECT public.registrar_salida_voluntaria((pg_temp.ficha('21.190.012-1')).id, public.hoy_chile());
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT count(*) FROM public.correos_autorizados WHERE correo = 'vol.n12@ninaspro.cl' AND usado_en IS NULL),
  0::bigint,
  'La salida de quien no tiene cuenta anula su autorización pendiente'
);
SELECT pg_temp.como_directiva();
SELECT throws_ok(
  format($$ SELECT public.renovar_autorizacion_voluntaria(%L) $$, (pg_temp.ficha('21.190.012-1')).id),
  '22023', 'La voluntaria está retirada: reincorpórala para autorizar su correo.',
  'No se autoriza el correo de una voluntaria retirada'
);
SELECT pg_temp.como_sistema();
UPDATE public.correos_autorizados SET expira_en = now() - interval '1 day' WHERE correo = 'vol.n13@ninaspro.cl';
SELECT pg_temp.como_directiva();
SELECT ok(
  public.renovar_autorizacion_voluntaria((pg_temp.ficha('21.190.013-K')).id) > now() + interval '29 days',
  'La Directiva renueva por 30 días la autorización vencida de una ficha sin cuenta'
);

-- =============================================================================
-- 12. Auditoría (US-23)
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT ok(
  (SELECT count(*) FROM public.auditoria_cambios_datos WHERE tabla_afectada = 'tareas_semanales_tutores'
     AND ejecutado_por = 'f1000000-0000-0000-0000-000000000004' AND accion = 'update') = 1
  AND EXISTS (SELECT 1 FROM public.auditoria_cambios_datos WHERE tabla_afectada = 'voluntarios_detalle'
     AND ejecutado_por = 'f1000000-0000-0000-0000-000000000001' AND accion = 'update')
  AND EXISTS (SELECT 1 FROM public.auditoria_cambios_datos WHERE tabla_afectada = 'tutores_instancia'
     AND ejecutado_por = 'f1000000-0000-0000-0000-000000000001' AND accion = 'delete'),
  'Los cambios de fichas, asignaciones y roles quedan auditados con quién los hizo'
);

SELECT * FROM finish();
ROLLBACK;
