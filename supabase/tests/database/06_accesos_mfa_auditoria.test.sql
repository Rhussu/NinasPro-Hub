BEGIN;
SELECT plan(33);

-- =============================================================================
-- Datos de prueba: Directiva, Gestión de la sede A y alumnas en las sedes A y B
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

-- Eventos de seguridad de esta prueba (la bitácora puede traer eventos de otras pruebas manuales)
CREATE OR REPLACE FUNCTION pg_temp.eventos(p_evento text, p_correo text) RETURNS bigint
LANGUAGE sql AS $$
  SELECT count(*) FROM public.auditoria_seguridad WHERE evento::text = p_evento AND correo = p_correo;
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('a6000000-0000-0000-0000-00000000000a', 'Sede Accesos A'),
  ('b6000000-0000-0000-0000-00000000000b', 'Sede Accesos B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES
  ('c6000000-0000-0000-0000-000000000001', 'Programación', 'TEST-ACC');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('16a00000-0000-0000-0000-000000000001', 'c6000000-0000-0000-0000-000000000001', 'a6000000-0000-0000-0000-00000000000a', '2026-1', '2026-04-04', '2026-06-06'),
  ('16b00000-0000-0000-0000-000000000001', 'c6000000-0000-0000-0000-000000000001', 'b6000000-0000-0000-0000-00000000000b', '2026-1', '2026-04-04', '2026-06-06');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('acc.directiva@ninaspro.cl', 'directorio', NULL, '21.111.111-1', 'Directiva', 'Accesos', NULL),
  ('acc.gestion.a@ninaspro.cl', 'equipo_gestion', 'a6000000-0000-0000-0000-00000000000a', '22.222.222-2', 'Gestión', 'Accesos', NULL);
SELECT pg_temp.crear_usuario('d6000000-0000-0000-0000-000000000001', 'acc.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('96000000-0000-0000-0000-000000000001', 'acc.gestion.a@ninaspro.cl');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('a6b00000-0000-0000-0000-000000000001', 'Marcela', 'Morales', 'marcela.acc@correo.cl', '+56987654321');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('a6a00000-0000-0000-0000-00000000000a', '31.000.001-1', 'Amanda', 'Sede A', '2011-05-10', 'a6b00000-0000-0000-0000-000000000001'),
  ('a6a00000-0000-0000-0000-00000000000b', '31.000.002-2', 'Bárbara', 'Sede B', '2011-08-21', 'a6b00000-0000-0000-0000-000000000001');
INSERT INTO public.inscripciones (alumna_id, instancia_curso_id, estado) VALUES
  ('a6a00000-0000-0000-0000-00000000000a', '16a00000-0000-0000-0000-000000000001', 'activa'),
  ('a6a00000-0000-0000-0000-00000000000b', '16b00000-0000-0000-0000-000000000001', 'activa');

-- =============================================================================
-- 1. MFA de la Directiva (RNF-S-1)
-- =============================================================================
SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal1');
SELECT is(public.current_user_role(), NULL, 'Sin el segundo factor la Directiva no tiene rol');
SELECT is_empty($$ SELECT 1 FROM public.alumnas $$, 'Sin el segundo factor la Directiva no ve fichas de alumnas');
SELECT is(public.estado_mi_cuenta() ->> 'mfa_requerida', 'true', 'La app sabe que debe pedir el segundo factor');
SELECT is(public.estado_mi_cuenta() ->> 'mfa_inscrita', 'false', 'La app sabe que aún no inscribe un autenticador');
SELECT is(
  public.autorizar_correo('acc.sin.mfa@ninaspro.cl', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '23.333.333-3', 'Sin', 'MFA') ->> 'code',
  '42501',
  'Sin el segundo factor la Directiva no puede autorizar correos'
);

SELECT pg_temp.como_sistema();
INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
VALUES (gen_random_uuid(), 'd6000000-0000-0000-0000-000000000001', 'NiñasPro Hub', 'totp', 'verified', now(), now());
SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal1');
SELECT is(public.estado_mi_cuenta() ->> 'mfa_inscrita', 'true', 'Con un autenticador verificado la app pide el código');

SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(public.current_user_role()::text, 'directorio', 'Con el segundo factor verificado vuelve el rol');
SELECT is(public.estado_mi_cuenta() ->> 'mfa_requerida', 'false', 'Con aal2 no se vuelve a pedir el código');

SELECT pg_temp.actuar_como('96000000-0000-0000-0000-000000000001', 'aal1');
SELECT is(public.current_user_role()::text, 'equipo_gestion', 'El resto de los roles no necesita segundo factor');
SELECT is(public.estado_mi_cuenta() ->> 'mfa_requerida', 'false', 'A Gestión no se le pide segundo factor');

-- =============================================================================
-- 2. Autorizar correos desde la app (US-04)
-- =============================================================================
SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal2');
SELECT is(
  public.autorizar_correo(' Acc.Nueva.Tutora@NinasPro.cl ', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '24.444.444-4', 'Nueva', 'Tutora') ->> 'correo',
  'acc.nueva.tutora@ninaspro.cl',
  'La Directiva autoriza a una tutora y el correo se normaliza'
);
SELECT is(
  (SELECT autorizado_por FROM public.correos_autorizados WHERE correo = 'acc.nueva.tutora@ninaspro.cl'),
  'd6000000-0000-0000-0000-000000000001'::uuid,
  'La autorización registra quién la dio'
);
SELECT lives_ok(
  $$ SELECT public.autorizar_correo('acc.lider.a@ninaspro.cl', 'equipo_gestion', 'a6000000-0000-0000-0000-00000000000a', NULL, '25.555.555-5', 'Líder', 'Sede', true) $$,
  'La Directiva autoriza a una líder de sede'
);
SELECT throws_ok(
  $$ SELECT public.autorizar_correo('acc.voluntaria@gmail.com', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '26.666.666-6', 'Ana', 'Pérez') $$,
  'P0001',
  'El voluntariado usa su correo institucional @ninaspro.cl.',
  'El voluntariado debe usar correo institucional'
);
SELECT throws_ok(
  $$ SELECT public.autorizar_correo('acc.nueva.tutora@ninaspro.cl', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '27.777.777-7', 'Otra', 'Vez') $$,
  'P0001',
  'El correo acc.nueva.tutora@ninaspro.cl ya tiene una autorización pendiente.',
  'Un correo no puede tener dos autorizaciones pendientes'
);
SELECT throws_ok(
  $$ SELECT public.autorizar_correo('acc.gestion.a@ninaspro.cl', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '28.888.888-8', 'Ya', 'Existe') $$,
  'P0001',
  'Ya existe una cuenta con el correo acc.gestion.a@ninaspro.cl.',
  'No se autoriza un correo que ya tiene cuenta'
);
SELECT throws_ok(
  $$ INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por)
     VALUES ('acc.directo@ninaspro.cl', 'tutora', 'a6000000-0000-0000-0000-00000000000a', '29.999.999-9', 'Directo', 'Insert', auth.uid()) $$,
  '42501',
  NULL,
  'Nadie inserta autorizaciones sin pasar por la RPC auditada'
);

SELECT pg_temp.como_sistema();
SELECT pg_temp.crear_usuario('26000000-0000-0000-0000-000000000001', 'acc.lider.a@ninaspro.cl');
SELECT ok(
  (SELECT es_lider_sede FROM public.usuarios_sedes WHERE perfil_id = '26000000-0000-0000-0000-000000000001'),
  'La líder de sede queda marcada como tal al crear su cuenta'
);

-- La Directiva autoriza a las alumnas (las gestiona ella, no el Equipo de Gestión)
SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal2');
SELECT set_eq(
  $$ SELECT nombres::text FROM public.alumnas_para_autorizar() WHERE rut LIKE '31.000.00%' $$,
  ARRAY['Amanda', 'Bárbara'],
  'La Directiva ve para autorizar las alumnas sin cuenta de todas las sedes'
);
SELECT is(
  public.autorizar_correo('acc.amanda@gmail.com', 'alumna', 'a6000000-0000-0000-0000-00000000000a', 'a6a00000-0000-0000-0000-00000000000a') ->> 'rol',
  'alumna',
  'La Directiva autoriza a una alumna inscrita en la sede (US-04 escenario 2)'
);
SELECT set_eq(
  $$ SELECT nombres::text FROM public.alumnas_para_autorizar() WHERE rut LIKE '31.000.00%' $$,
  ARRAY['Bárbara'],
  'Una alumna con autorización pendiente ya no aparece para autorizar'
);

-- Gestión de la sede A
SELECT pg_temp.actuar_como('96000000-0000-0000-0000-000000000001');
SELECT is_empty(
  $$ SELECT 1 FROM public.alumnas_para_autorizar() $$,
  'Gestión no ve alumnas para autorizar'
);
SELECT is_empty($$ SELECT 1 FROM public.correos_autorizados $$, 'Gestión no ve los correos autorizados');
SELECT is(
  public.autorizar_correo('acc.intrusa@ninaspro.cl', 'tutora', 'a6000000-0000-0000-0000-00000000000a', NULL, '30.111.111-1', 'Intrusa', 'Tutora') ->> 'code',
  '42501',
  'Gestión no puede autorizar cuentas de voluntariado (US-04 escenario 3)'
);
SELECT is(
  public.autorizar_correo('acc.barbara@gmail.com', 'alumna', 'a6000000-0000-0000-0000-00000000000a', 'a6a00000-0000-0000-0000-00000000000a') ->> 'code',
  '42501',
  'Gestión no autoriza alumnas, ni siquiera de su sede'
);
SELECT is_empty($$ SELECT 1 FROM public.auditoria_seguridad $$, 'Gestión no ve la bitácora de seguridad');

-- =============================================================================
-- 3. Bitácora de seguridad (RNF-S-4)
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT is(pg_temp.eventos('autorizacion_denegada', 'acc.intrusa@ninaspro.cl'), 1::bigint, 'El intento de Gestión queda en la auditoría');
SELECT is(
  (SELECT usuario_id FROM public.auditoria_seguridad WHERE correo = 'acc.intrusa@ninaspro.cl'),
  '96000000-0000-0000-0000-000000000001'::uuid,
  'La auditoría indica qué cuenta hizo el intento'
);

-- Registro de un correo no autorizado
SELECT is(
  public.hook_before_user_created('{"user": {"email": "Acc.Desconocida@Gmail.com"}, "metadata": {"ip_address": "10.0.0.1"}}') -> 'error' ->> 'http_code',
  '403',
  'El registro de un correo no autorizado se rechaza'
);
SELECT is(pg_temp.eventos('registro_rechazado', 'acc.desconocida@gmail.com'), 1::bigint, 'El registro rechazado queda en la auditoría');

-- Bloqueo tras 3 intentos fallidos
SELECT public.hook_password_verification_attempt('{"user_id": "96000000-0000-0000-0000-000000000001", "valid": false}');
SELECT public.hook_password_verification_attempt('{"user_id": "96000000-0000-0000-0000-000000000001", "valid": false}');
SELECT matches(
  public.hook_password_verification_attempt('{"user_id": "96000000-0000-0000-0000-000000000001", "valid": false}') ->> 'message',
  'quedó bloqueada',
  'El intento que bloquea la cuenta avisa que se enviará el código de desbloqueo'
);
SELECT is(pg_temp.eventos('cuenta_bloqueada', 'acc.gestion.a@ninaspro.cl'), 1::bigint, 'El bloqueo queda en la auditoría');

-- La Directiva consulta la bitácora, pero nadie puede alterarla
SELECT pg_temp.actuar_como('d6000000-0000-0000-0000-000000000001', 'aal2');
SELECT throws_ok(
  $$ DELETE FROM public.auditoria_seguridad $$,
  '42501',
  NULL,
  'Ni la Directiva puede borrar la bitácora de seguridad'
);

SELECT * FROM finish();
ROLLBACK;
