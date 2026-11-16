BEGIN;
SELECT plan(56);

-- =============================================================================
-- Datos de prueba: un curso de la sede A con una tutora, tres alumnas (Ana y
-- Berta con cuenta; Carla sin autorización de imagen) y un curso de la sede B
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

-- Clase N de la sede A
CREATE OR REPLACE FUNCTION pg_temp.clase(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('e4200000-0000-0000-0000-00000000000' || p_n)::uuid; $$;

-- Inscripción de la alumna N
CREATE OR REPLACE FUNCTION pg_temp.insc(p_n int) RETURNS uuid
LANGUAGE sql AS $$ SELECT ('e4300000-0000-0000-0000-00000000000' || p_n)::uuid; $$;

CREATE OR REPLACE FUNCTION pg_temp.asistencia(p_clase int, p_alumna int) RETURNS text
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT estado::text FROM public.asistencia_alumnas
  WHERE clase_id = pg_temp.clase(p_clase) AND inscripcion_id = pg_temp.insc(p_alumna);
$$;

CREATE OR REPLACE FUNCTION pg_temp.justificativo(p_clase int, p_alumna int) RETURNS uuid
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT id FROM public.justificativos_inasistencia
  WHERE clase_id = pg_temp.clase(p_clase) AND inscripcion_id = pg_temp.insc(p_alumna)
  ORDER BY created_at DESC, estado = 'rechazado' LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION pg_temp.lista(p_pares text[]) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_agg(jsonb_build_object('inscripcion_id', pg_temp.insc(p[1]::int), 'estado', p[2]))
  FROM (SELECT string_to_array(x, ':') AS p FROM unnest(p_pares) AS x) AS pares;
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('e4a00000-0000-0000-0000-00000000000a', 'Sede Justificativos A'),
  ('e4b00000-0000-0000-0000-00000000000b', 'Sede Justificativos B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES ('e4c00000-0000-0000-0000-000000000001', 'Curso Justificativos', 'JUS');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('e4100000-0000-0000-0000-00000000000a', 'e4c00000-0000-0000-0000-000000000001', 'e4a00000-0000-0000-0000-00000000000a', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60),
  ('e4100000-0000-0000-0000-00000000000b', 'e4c00000-0000-0000-0000-000000000001', 'e4b00000-0000-0000-0000-00000000000b', '2026-2', public.hoy_chile() - 30, public.hoy_chile() + 60);

-- Sede A: clase de hace una semana, la de hoy, una futura y una suspendida. Sede B: hace una semana
INSERT INTO public.clases (id, instancia_curso_id, numero_sesion, fecha, estado, motivo_suspension) VALUES
  ('e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-00000000000a', 1, public.hoy_chile() - 7, 'programada', NULL),
  ('e4200000-0000-0000-0000-000000000002', 'e4100000-0000-0000-0000-00000000000a', 2, public.hoy_chile(), 'programada', NULL),
  ('e4200000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-00000000000a', 3, public.hoy_chile() + 7, 'programada', NULL),
  ('e4200000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-00000000000a', 4, public.hoy_chile() - 14, 'suspendida', 'Paro'),
  ('e4200000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-00000000000b', 1, public.hoy_chile() - 7, 'realizada', NULL);

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('jus.gestion.a@ninaspro.cl', 'equipo_gestion', 'e4a00000-0000-0000-0000-00000000000a', '21.140.001-3', 'Gestión', 'A', NULL),
  ('jus.gestion.b@ninaspro.cl', 'equipo_gestion', 'e4b00000-0000-0000-0000-00000000000b', '21.140.002-1', 'Gestión', 'B', NULL),
  ('jus.tutora.a@ninaspro.cl', 'tutora', 'e4a00000-0000-0000-0000-00000000000a', '21.140.003-K', 'Tutora', 'A', NULL),
  ('jus.tutora.b@ninaspro.cl', 'tutora', 'e4b00000-0000-0000-0000-00000000000b', '21.140.004-8', 'Tutora', 'B', NULL);
SELECT pg_temp.crear_usuario('9e400000-0000-0000-0000-00000000000a', 'jus.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('9e400000-0000-0000-0000-00000000000b', 'jus.gestion.b@ninaspro.cl');
SELECT pg_temp.crear_usuario('7e400000-0000-0000-0000-000000000001', 'jus.tutora.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('7e400000-0000-0000-0000-000000000002', 'jus.tutora.b@ninaspro.cl');
INSERT INTO public.voluntarios_detalle (perfil_id, fecha_ingreso, declaracion_adhesion_firmada) VALUES
  ('7e400000-0000-0000-0000-000000000001', '2025-03-01', true);
INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por) VALUES
  ('e4100000-0000-0000-0000-00000000000a', '7e400000-0000-0000-0000-000000000001', '9e400000-0000-0000-0000-00000000000a');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('e4d00000-0000-0000-0000-000000000001', 'Apoderada', 'Justificativos', 'apoderada.jus@correo.cl', '+56 9 2222 2222');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a4000000-0000-0000-0000-000000000001', '27.140.001-2', 'Ana', 'Uno', '2011-01-01', 'e4d00000-0000-0000-0000-000000000001'),
  ('a4000000-0000-0000-0000-000000000002', '27.140.002-0', 'Berta', 'Dos', '2011-01-01', 'e4d00000-0000-0000-0000-000000000001'),
  ('a4000000-0000-0000-0000-000000000003', '27.140.003-9', 'Carla', 'Tres', '2011-01-01', 'e4d00000-0000-0000-0000-000000000001'),
  ('a4000000-0000-0000-0000-000000000004', '27.140.004-7', 'Dana', 'Otra Sede', '2011-01-01', 'e4d00000-0000-0000-0000-000000000001');
INSERT INTO public.autorizaciones_apoderado (alumna_id, apoderado_id, autoriza_tratamiento_datos, autoriza_uso_imagen_general, registrado_por)
SELECT id, 'e4d00000-0000-0000-0000-000000000001', 'otorgada',
       CASE WHEN id = 'a4000000-0000-0000-0000-000000000003' THEN 'no_otorgada' ELSE 'otorgada' END::public.estado_autorizacion,
       '9e400000-0000-0000-0000-00000000000a'
FROM public.alumnas WHERE id::text LIKE 'a4000000-%';
INSERT INTO public.inscripciones (id, alumna_id, instancia_curso_id, estado) VALUES
  ('e4300000-0000-0000-0000-000000000001', 'a4000000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-00000000000a', 'activa'),
  ('e4300000-0000-0000-0000-000000000002', 'a4000000-0000-0000-0000-000000000002', 'e4100000-0000-0000-0000-00000000000a', 'activa'),
  ('e4300000-0000-0000-0000-000000000003', 'a4000000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-00000000000a', 'activa'),
  ('e4300000-0000-0000-0000-000000000004', 'a4000000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-00000000000b', 'activa');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por) VALUES
  ('ana.jus@correo.cl', 'alumna', 'e4a00000-0000-0000-0000-00000000000a', 'a4000000-0000-0000-0000-000000000001', NULL),
  ('berta.jus@correo.cl', 'alumna', 'e4a00000-0000-0000-0000-00000000000a', 'a4000000-0000-0000-0000-000000000002', NULL);
SELECT pg_temp.crear_usuario('5e400000-0000-0000-0000-000000000001', 'ana.jus@correo.cl');
SELECT pg_temp.crear_usuario('5e400000-0000-0000-0000-000000000002', 'berta.jus@correo.cl');

-- Pase de lista de hace una semana: Ana y Berta ausentes, Carla presente
SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000001');
SELECT public.guardar_asistencia_clase(pg_temp.clase(1), pg_temp.lista(ARRAY['1:ausente', '2:ausente', '3:presente']));

-- =============================================================================
-- 1. Bucket privado de evidencias y justificativos solo en texto (US-17, RB-8)
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT is(
  (SELECT public::text || ':' || file_size_limit || ':' || array_to_string(allowed_mime_types, ',') FROM storage.buckets WHERE id = 'evidencias'),
  'false:5242880:image/jpeg,image/png',
  'El bucket de evidencias es privado y admite fotos JPG o PNG de hasta 5 MB'
);
SELECT ok(
  NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'justificativos'),
  'Los justificativos no llevan archivos adjuntos: no hay bucket de respaldos'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'justificativos_inasistencia' AND column_name ILIKE '%diagn%'
  ),
  'El justificativo no tiene campo de diagnóstico (RB-8)'
);

-- =============================================================================
-- 2. La alumna envía su justificativo (US-35)
-- =============================================================================
SELECT pg_temp.actuar_como('5e400000-0000-0000-0000-000000000001');
SELECT is(
  public.enviar_justificativo(pg_temp.clase(3), 'salud', 'Tengo control médico ese sábado') ->> 'estado',
  'pendiente',
  'La alumna justifica por adelantado una clase futura y queda pendiente'
);
SELECT throws_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(3), 'familiar', 'Otra vez') $$,
  '23505', 'Ya hay un justificativo pendiente para esa clase.',
  'No se envía un segundo justificativo para la misma clase (US-35 escenario 4)'
);
SELECT throws_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(4), 'salud', 'Suspendida') $$,
  '22023', 'La clase está suspendida: no hay inasistencia que justificar.',
  'No se justifica una clase suspendida'
);
SELECT throws_ok(
  $$ SELECT public.enviar_justificativo('e4200000-0000-0000-0000-000000000009', 'salud', 'Otra sede') $$,
  '42501', 'Esa clase no es de un curso en el que estés inscrita.',
  'La alumna no justifica clases de cursos en los que no está inscrita'
);
SELECT throws_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(1), 'otro', '   ') $$,
  '22023', 'Escribe la explicación de la inasistencia.',
  'El justificativo lleva una explicación en texto'
);
SELECT throws_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(1), 'otro', repeat('x', 501)) $$,
  '22023', 'La explicación admite hasta 500 caracteres.',
  'La explicación es breve (RB-8)'
);
SELECT is(
  public.enviar_justificativo(pg_temp.clase(1), 'escolar', '  Tenía prueba  ') ->> 'explicacion',
  'Tenía prueba',
  'La alumna justifica una inasistencia previa con su explicación'
);
SELECT throws_ok(
  $$ INSERT INTO public.justificativos_inasistencia (clase_id, inscripcion_id, motivo, explicacion, subido_por)
     VALUES (pg_temp.clase(2), pg_temp.insc(1), 'otro', 'Directo', auth.uid()) $$,
  '42501', NULL,
  'Nadie escribe en la tabla de justificativos sin pasar por las RPC'
);
SELECT is(
  (SELECT string_agg(numero_sesion::text || ':' || coalesce(justificativo_estado::text, '-'), ' ' ORDER BY numero_sesion) FROM public.clases_para_justificar()),
  '1:pendiente 2:- 3:pendiente',
  'La alumna elige entre sus clases no suspendidas, con el estado de sus justificativos (US-35 escenario 1)'
);

-- Berta: la clase de hoy por adelantado y la de hace una semana
SELECT pg_temp.actuar_como('5e400000-0000-0000-0000-000000000002');
SELECT lives_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(2), 'transporte', 'No hay micro por el paro') $$,
  'Berta justifica la clase de hoy antes del pase de lista'
);
SELECT lives_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(1), 'familiar', 'Viaje familiar') $$,
  'Berta justifica la clase de hace una semana'
);
SELECT is(
  (SELECT count(*)::int FROM public.justificativos_detalle),
  2,
  'La alumna solo ve sus propios justificativos (US-17 escenario 2)'
);

-- =============================================================================
-- 3. Tutoras: solo lectura del estado y el motivo (US-38)
-- =============================================================================
SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.resolver_justificativo(pg_temp.justificativo(1, 1), true, NULL) $$,
  '42501', 'Solo el Equipo de Gestión de la sede resuelve justificativos.',
  'La tutora no aprueba justificativos (403)'
);
SELECT throws_ok(
  $$ SELECT public.registrar_justificativo(pg_temp.clase(1), pg_temp.insc(3), 'salud', 'Aviso') $$,
  '42501', 'Solo el Equipo de Gestión de la sede registra justificativos.',
  'La tutora no registra justificativos'
);
SELECT is_empty(
  $$ SELECT 1 FROM public.justificativos_inasistencia $$,
  'La tutora no lee la explicación de los justificativos'
);
SELECT is(
  (SELECT string_agg(nombres || ':' || coalesce(justificativo_estado::text || '/' || justificativo_motivo::text, '-'), ' ' ORDER BY nombres)
   FROM public.lista_asistencia_clase(pg_temp.clase(1))),
  'Ana:pendiente/escolar Berta:pendiente/familiar Carla:-',
  'En el pase de lista, la tutora ve el estado y el motivo del justificativo'
);

-- =============================================================================
-- 4. Gestión de la sede resuelve (US-37)
-- =============================================================================
SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000b');
SELECT throws_ok(
  $$ SELECT public.resolver_justificativo(pg_temp.justificativo(1, 1), true, NULL) $$,
  '42501', 'Solo el Equipo de Gestión de la sede resuelve justificativos.',
  'Gestión de otra sede no resuelve justificativos'
);
SELECT is_empty($$ SELECT 1 FROM public.justificativos_detalle $$, 'Gestión de otra sede no ve los justificativos');

SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT count(*)::int FROM public.justificativos_detalle WHERE estado = 'pendiente'),
  4,
  'Gestión de la sede ve la bandeja de pendientes'
);
SELECT throws_ok(
  $$ SELECT public.resolver_justificativo(pg_temp.justificativo(1, 2), false, '  ') $$,
  '22023', 'Indica el motivo del rechazo para que la alumna lo sepa.',
  'El rechazo exige una observación'
);
SELECT is(
  public.resolver_justificativo(pg_temp.justificativo(1, 2), false, 'Falta la constancia') ->> 'estado',
  'rechazado',
  'Gestión rechaza con observación'
);
SELECT is(pg_temp.asistencia(1, 2), 'ausente', 'Tras el rechazo, la inasistencia sigue ausente (US-37 escenario 3)');
SELECT is(
  public.resolver_justificativo(pg_temp.justificativo(1, 1), true, NULL) ->> 'estado',
  'aceptado',
  'Gestión aprueba el justificativo'
);
SELECT is(pg_temp.asistencia(1, 1), 'justificada', 'Al aprobarlo, la asistencia pasa a justificada (US-16 escenario 1)');
SELECT throws_ok(
  $$ SELECT public.resolver_justificativo(pg_temp.justificativo(1, 1), false, 'Cambio de opinión') $$,
  '22023', 'El justificativo ya fue resuelto.',
  'Un justificativo resuelto no se vuelve a resolver'
);
SELECT lives_ok(
  $$ SELECT public.resolver_justificativo(pg_temp.justificativo(2, 2), true, NULL) $$,
  'Gestión aprueba por adelantado la clase de hoy de Berta'
);
SELECT pg_temp.como_sistema();
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.auditoria_cambios_datos
    WHERE tabla_afectada = 'justificativos_inasistencia' AND registro_id = pg_temp.justificativo(1, 1)
      AND valor_nuevo ->> 'estado' = 'aceptado' AND ejecutado_por = '9e400000-0000-0000-0000-00000000000a'
  ),
  'La resolución queda en la auditoría con su responsable (US-37 escenario 4)'
);

-- Tras el rechazo, Berta puede volver a enviar
SELECT pg_temp.actuar_como('5e400000-0000-0000-0000-000000000002');
SELECT lives_ok(
  $$ SELECT public.enviar_justificativo(pg_temp.clase(1), 'familiar', 'Ahora con el detalle del viaje') $$,
  'Tras un rechazo, la alumna puede enviar un nuevo justificativo'
);
SELECT is(
  (SELECT observacion_resolucion FROM public.justificativos_detalle WHERE estado = 'rechazado'),
  'Falta la constancia',
  'La alumna lee la observación del rechazo'
);

-- =============================================================================
-- 5. Precarga en el pase de lista y bloqueo para las tutoras (US-16, US-37)
-- =============================================================================
SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000001');
SELECT is(
  public.guardar_asistencia_clase(pg_temp.clase(2), pg_temp.lista(ARRAY['1:presente', '2:presente', '3:presente'])) ->> 'justificadas_conservadas',
  '1',
  'El pase de lista informa que la alumna con justificativo aceptado se mantuvo justificada'
);
SELECT is(pg_temp.asistencia(2, 2), 'justificada', 'La alumna justificada por adelantado entra justificada (US-16 escenario 2)');
SELECT is(
  public.guardar_asistencia_clase(pg_temp.clase(1), pg_temp.lista(ARRAY['1:presente'])) ->> 'justificadas_conservadas',
  '1',
  'La tutora no cambia una inasistencia justificada'
);
SELECT is(pg_temp.asistencia(1, 1), 'justificada', 'La asistencia justificada se conserva');

-- =============================================================================
-- 6. Gestión registra el aviso de la apoderada y elimina por error (US-16)
-- =============================================================================
SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ SELECT public.registrar_justificativo(pg_temp.clase(1), pg_temp.insc(3), 'salud', 'Aviso') $$,
  '22023', 'La alumna figura presente en esa clase: no hay inasistencia que justificar.',
  'No se justifica a una alumna presente'
);
SELECT throws_ok(
  $$ SELECT public.registrar_justificativo(pg_temp.clase(1), pg_temp.insc(2), 'familiar', 'La apoderada avisó por teléfono') $$,
  '23505', 'Ya hay un justificativo pendiente para esa clase.',
  'Si la alumna ya envió uno, Gestión lo resuelve en la bandeja en vez de duplicarlo'
);
SELECT is(
  public.registrar_justificativo(pg_temp.clase(3), pg_temp.insc(3), 'salud', 'La apoderada avisó por teléfono') ->> 'estado',
  'aceptado',
  'Gestión registra el aviso de la apoderada para la próxima clase y queda aceptado'
);
SELECT is(
  (SELECT justificativo_estado::text FROM public.lista_asistencia_clase(pg_temp.clase(3)) WHERE nombres = 'Carla'),
  'aceptado',
  'El pase de lista de la próxima clase ya la muestra justificada'
);
SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000001');
SELECT throws_ok(
  $$ SELECT public.eliminar_justificativo(pg_temp.justificativo(1, 1)) $$,
  '42501', 'Solo el Equipo de Gestión de la sede elimina justificativos.',
  'La tutora no elimina justificativos'
);
SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000a');
SELECT lives_ok(
  $$ SELECT public.eliminar_justificativo(pg_temp.justificativo(1, 1)) $$,
  'Gestión elimina un justificativo vinculado por error'
);
SELECT is(pg_temp.asistencia(1, 1), 'ausente', 'Al eliminar el justificativo, la asistencia vuelve a ausente (US-16 escenario 3)');

-- =============================================================================
-- 7. Evidencia fotográfica (US-18, US-19)
-- =============================================================================
SELECT pg_temp.como_sistema();
INSERT INTO storage.objects (bucket_id, name, metadata) VALUES
  ('evidencias', 'e4200000-0000-0000-0000-000000000001/foto-1.jpg', '{"size": 812345}'),
  ('evidencias', 'e4200000-0000-0000-0000-000000000001/foto-2.jpg', '{"size": 700000}'),
  ('evidencias', 'e4200000-0000-0000-0000-000000000003/foto-futura.jpg', '{"size": 700000}');

SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000002');
SELECT throws_ok(
  $$ INSERT INTO storage.objects (bucket_id, name) VALUES ('evidencias', 'e4200000-0000-0000-0000-000000000001/intrusa.jpg') $$,
  '42501', NULL,
  'Una tutora de otra sede no sube fotos a la clase'
);

SELECT pg_temp.actuar_como('7e400000-0000-0000-0000-000000000001');
SELECT is(
  (SELECT string_agg(nombres, ', ') FROM public.presentes_sin_autorizacion_imagen(pg_temp.clase(1))),
  'Carla',
  'Se listan las presentes sin autorización de imagen (US-19 escenario 1)'
);
SELECT throws_ok(
  $$ INSERT INTO public.evidencias_fotograficas (clase_id, archivo_url, apta_para_evidencia)
     VALUES (pg_temp.clase(3), 'e4200000-0000-0000-0000-000000000003/foto-futura.jpg', false) $$,
  '22023', 'La foto de evidencia se sube después de pasar lista en la clase.',
  'No se registra la foto de una clase sin pase de lista'
);
SELECT throws_ok(
  $$ INSERT INTO public.evidencias_fotograficas (clase_id, archivo_url, apta_para_evidencia)
     VALUES (pg_temp.clase(1), 'e4200000-0000-0000-0000-000000000001/no-subida.jpg', false) $$,
  '22023', 'No encontramos la foto subida: vuelve a subirla.',
  'No se registra una foto que no está en el bucket'
);
SELECT throws_ok(
  $$ INSERT INTO public.evidencias_fotograficas (clase_id, archivo_url, apta_para_evidencia, rostros_censurados)
     VALUES (pg_temp.clase(1), 'e4200000-0000-0000-0000-000000000001/foto-1.jpg', true, false) $$,
  '22023', 'Para marcarla apta, confirma que las alumnas sin autorización no son reconocibles o sus rostros fueron cubiertos.',
  'Sin la declaración de censura, la foto no se marca apta (US-19 escenario 2)'
);
SELECT lives_ok(
  $$ INSERT INTO public.evidencias_fotograficas (clase_id, archivo_url, tamano_bytes, apta_para_evidencia, rostros_censurados)
     VALUES (pg_temp.clase(1), 'e4200000-0000-0000-0000-000000000001/foto-1.jpg', 1, true, true) $$,
  'Con la declaración de censura, la foto se marca apta'
);
SELECT is(
  (SELECT tamano_bytes || ' ' || apta_para_evidencia || ' ' || rostros_censurados || ' ' || declaracion_consentimiento_completo || ' ' || (subida_por = auth.uid())
   FROM public.evidencias_fotograficas WHERE archivo_url = 'e4200000-0000-0000-0000-000000000001/foto-1.jpg'),
  '812345 true true false true',
  'La foto guarda el tamaño real del archivo, la autora y que no todas tenían autorización (US-18 escenario 3)'
);
SELECT lives_ok(
  $$ INSERT INTO public.evidencias_fotograficas (clase_id, archivo_url, apta_para_evidencia)
     VALUES (pg_temp.clase(1), 'e4200000-0000-0000-0000-000000000001/foto-2.jpg', false) $$,
  'Sin la declaración, la foto se guarda como respaldo interno no apta (US-19 escenario 3)'
);
SELECT throws_ok(
  $$ UPDATE public.evidencias_fotograficas SET archivo_url = 'e4200000-0000-0000-0000-000000000001/otra.jpg'
     WHERE archivo_url = 'e4200000-0000-0000-0000-000000000001/foto-2.jpg' $$,
  '22023', 'La foto, su clase y su autoría no se modifican: sube una nueva.',
  'El archivo y la autoría de la foto no se modifican'
);

SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000a');
SELECT throws_ok(
  $$ DELETE FROM public.evidencias_fotograficas $$,
  '42501', NULL,
  'Las fotos registradas se conservan: ni Gestión las borra (RB-10)'
);

-- =============================================================================
-- 8. Clases con evidencia pendiente tras 48 horas (US-20)
-- =============================================================================
SELECT is(
  (SELECT string_agg(numero_sesion::text, ' ' ORDER BY numero_sesion) FROM public.evidencias_pendientes WHERE sede_nombre = 'Sede Justificativos A'),
  NULL,
  'Una clase con foto no figura pendiente (US-20 escenario 2)'
);
SELECT pg_temp.como_sistema();
UPDATE public.clases SET estado = 'realizada', motivo_suspension = NULL WHERE id = pg_temp.clase(4);
SELECT pg_temp.actuar_como('9e400000-0000-0000-0000-00000000000a');
SELECT is(
  (SELECT numero_sesion || ' ' || (horas_sin_foto > 48) || ' ' || tutoras FROM public.evidencias_pendientes WHERE sede_nombre = 'Sede Justificativos A'),
  '4 true Tutora A',
  'Una clase realizada hace más de 48 horas sin foto figura pendiente, con sus tutoras (US-20 escenario 1)'
);
SELECT is(
  (SELECT count(*)::int FROM public.evidencias_pendientes WHERE sede_nombre = 'Sede Justificativos B'),
  0,
  'Gestión no ve las evidencias pendientes de otra sede (US-20 escenario 3)'
);

SELECT * FROM finish();
ROLLBACK;
