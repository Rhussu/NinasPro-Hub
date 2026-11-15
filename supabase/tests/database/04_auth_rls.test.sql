BEGIN;
SELECT plan(26);

-- =============================================================================
-- Datos de prueba: sede A y sede B, una instancia por sede, staff y alumnas
-- =============================================================================
CREATE OR REPLACE FUNCTION pg_temp.actuar_como(p_user uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
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

-- Registra una cuenta tal como lo haría Auth tras pasar el hook
CREATE OR REPLACE FUNCTION pg_temp.crear_usuario(p_id uuid, p_correo text) RETURNS void
LANGUAGE sql AS $$
  INSERT INTO auth.users (instance_id, id, aud, role, email)
  VALUES ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_correo);
$$;

INSERT INTO public.sedes (id, nombre) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'Sede A'),
  ('b0000000-0000-0000-0000-00000000000b', 'Sede B');
INSERT INTO public.cursos (id, nombre, codigo) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Programación', 'TEST-PCB');
INSERT INTO public.instancias_curso (id, curso_id, sede_id, periodo_academico, fecha_inicio, fecha_termino) VALUES
  ('1a000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', '2026-1', '2026-04-04', '2026-06-06'),
  ('1b000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b', '2026-1', '2026-04-04', '2026-06-06');

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('test.directiva@ninaspro.cl', 'directorio', NULL, '11.111.111-1', 'Directiva', 'Nacional', NULL),
  ('test.gestion.a@ninaspro.cl', 'equipo_gestion', 'a0000000-0000-0000-0000-00000000000a', '12.222.222-2', 'Gestión', 'A', NULL),
  ('test.tutora.a@ninaspro.cl', 'tutora', 'a0000000-0000-0000-0000-00000000000a', '13.333.333-3', 'Tutora', 'A', NULL),
  ('test.tutora.b@ninaspro.cl', 'tutora', 'b0000000-0000-0000-0000-00000000000b', '14.444.444-4', 'Tutora', 'B', NULL);

SELECT pg_temp.crear_usuario('d0000000-0000-0000-0000-000000000001', 'test.directiva@ninaspro.cl');
SELECT pg_temp.crear_usuario('9a000000-0000-0000-0000-000000000001', 'test.gestion.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('7a000000-0000-0000-0000-000000000001', 'test.tutora.a@ninaspro.cl');
SELECT pg_temp.crear_usuario('7b000000-0000-0000-0000-000000000001', 'test.tutora.b@ninaspro.cl');

INSERT INTO public.apoderados (id, nombres, apellidos, correo, telefono) VALUES
  ('ab000000-0000-0000-0000-000000000001', 'Marcela', 'Morales', 'marcela@correo.cl', '+56987654321');
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('aa000000-0000-0000-0000-00000000000a', '30.000.001-1', 'Valentina', 'Soto', '2011-05-10', 'ab000000-0000-0000-0000-000000000001'),
  ('aa000000-0000-0000-0000-00000000000b', '30.000.002-2', 'Josefa', 'Rojas', '2011-08-21', 'ab000000-0000-0000-0000-000000000001');
INSERT INTO public.inscripciones (alumna_id, instancia_curso_id, estado) VALUES
  ('aa000000-0000-0000-0000-00000000000a', '1a000000-0000-0000-0000-000000000001', 'activa'),
  ('aa000000-0000-0000-0000-00000000000b', '1b000000-0000-0000-0000-000000000001', 'activa');

-- =============================================================================
-- 1. Registro cerrado (US-04, US-05)
-- =============================================================================
SELECT is(
  public.hook_before_user_created('{"user": {"email": "intrusa@gmail.com"}}'::jsonb) -> 'error' ->> 'http_code',
  '403',
  'El hook rechaza correos sin autorización'
);

INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por) VALUES
  ('valentina@gmail.com', 'alumna', 'a0000000-0000-0000-0000-00000000000a', 'aa000000-0000-0000-0000-00000000000a', NULL);

SELECT is(
  public.hook_before_user_created('{"user": {"email": "Valentina@Gmail.com "}}'::jsonb),
  '{}'::jsonb,
  'El hook acepta un correo autorizado sin importar mayúsculas ni espacios'
);

SELECT pg_temp.crear_usuario('aa100000-0000-0000-0000-00000000000a', 'valentina@gmail.com');

SELECT is(
  (SELECT rol::text FROM public.perfiles WHERE id = 'aa100000-0000-0000-0000-00000000000a'),
  'alumna',
  'Al registrarse se crea el perfil con el rol autorizado'
);
SELECT is(
  (SELECT perfil_usuario_id FROM public.alumnas WHERE id = 'aa000000-0000-0000-0000-00000000000a'),
  'aa100000-0000-0000-0000-00000000000a'::uuid,
  'La cuenta queda vinculada con la ficha de la alumna'
);
SELECT ok(
  EXISTS (SELECT 1 FROM public.usuarios_sedes WHERE perfil_id = '7a000000-0000-0000-0000-000000000001' AND sede_id = 'a0000000-0000-0000-0000-00000000000a'),
  'La cuenta queda asignada a la sede autorizada'
);
SELECT ok(
  (SELECT usado_en IS NOT NULL FROM public.correos_autorizados WHERE correo = 'valentina@gmail.com'),
  'La autorización queda consumida (un solo uso)'
);
SELECT throws_ok(
  $$ SELECT pg_temp.crear_usuario(gen_random_uuid(), 'otra@gmail.com') $$,
  '42501',
  NULL,
  'Crear una cuenta sin autorización falla aunque se salte el hook'
);
SELECT throws_ok(
  $$ INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos)
     VALUES ('voluntaria@gmail.com', 'tutora', 'a0000000-0000-0000-0000-00000000000a', '15.555.555-5', 'Ana', 'Pérez') $$,
  '23514',
  NULL,
  'El voluntariado debe usar correo institucional @ninaspro.cl'
);

-- =============================================================================
-- 2. Aislamiento territorial (US-06) y sin recursión en perfiles
-- =============================================================================
SELECT pg_temp.actuar_como('7a000000-0000-0000-0000-000000000001');

SELECT lives_ok($$ SELECT count(*) FROM public.perfiles $$, 'Consultar perfiles no produce recursión infinita');
SELECT set_eq(
  $$ SELECT correo::text FROM public.perfiles WHERE rol <> 'alumna' $$,
  ARRAY['test.tutora.a@ninaspro.cl', 'test.gestion.a@ninaspro.cl'],
  'La tutora de la sede A solo ve al staff de su sede'
);
SELECT set_eq(
  $$ SELECT nombres::text FROM public.alumnas $$,
  ARRAY['Valentina'],
  'La tutora de la sede A solo ve alumnas de su sede'
);
SELECT is_empty($$ SELECT 1 FROM public.apoderados $$, 'Las tutoras no ven datos de apoderados');
SELECT is_empty(
  $$ SELECT 1 FROM public.instancias_curso WHERE sede_id = 'b0000000-0000-0000-0000-00000000000b' $$,
  'La tutora de la sede A no ve instancias de la sede B'
);

SELECT pg_temp.como_sistema();
SELECT pg_temp.actuar_como('9a000000-0000-0000-0000-000000000001');

SELECT set_eq($$ SELECT nombres::text FROM public.alumnas $$, ARRAY['Valentina'], 'Gestión de la sede A solo ve alumnas de su sede');
SELECT isnt_empty($$ SELECT 1 FROM public.apoderados $$, 'Gestión ve el contacto del apoderado de sus alumnas');
SELECT is_empty(
  $$ UPDATE public.alumnas SET curso_escolar = '8° básico' WHERE id = 'aa000000-0000-0000-0000-00000000000b' RETURNING 1 $$,
  'Gestión no puede modificar alumnas de otra sede'
);

-- =============================================================================
-- 3. Escalamiento de privilegios (US-04 escenario 3)
-- =============================================================================
SELECT throws_ok(
  $$ UPDATE public.perfiles SET rol = 'equipo_gestion' WHERE id = '7a000000-0000-0000-0000-000000000001' $$,
  '42501',
  NULL,
  'Gestión no puede cambiar el rol de una tutora'
);
SELECT throws_ok(
  $$ INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por)
     VALUES ('nueva@ninaspro.cl', 'tutora', 'a0000000-0000-0000-0000-00000000000a', '16.666.666-6', 'Nueva', 'Tutora', auth.uid()) $$,
  '42501',
  NULL,
  'Gestión no puede autorizar cuentas de voluntariado'
);
SELECT throws_ok(
  $$ INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por)
     VALUES ('josefa@gmail.com', 'alumna', 'b0000000-0000-0000-0000-00000000000b', 'aa000000-0000-0000-0000-00000000000b', auth.uid()) $$,
  '42501',
  NULL,
  'Gestión no puede autorizar alumnas de otra sede'
);

SELECT pg_temp.como_sistema();
INSERT INTO public.alumnas (id, rut, nombres, apellidos, fecha_nacimiento, apoderado_id) VALUES
  ('aa000000-0000-0000-0000-0000000000a2', '30.000.003-3', 'Florencia', 'Muñoz', '2011-02-02', 'ab000000-0000-0000-0000-000000000001');
INSERT INTO public.inscripciones (alumna_id, instancia_curso_id) VALUES
  ('aa000000-0000-0000-0000-0000000000a2', '1a000000-0000-0000-0000-000000000001');
SELECT pg_temp.actuar_como('9a000000-0000-0000-0000-000000000001');

SELECT lives_ok(
  $$ SELECT public.autorizar_correo('florencia@gmail.com', 'alumna', 'a0000000-0000-0000-0000-00000000000a', 'aa000000-0000-0000-0000-0000000000a2') $$,
  'Gestión autoriza el correo de una alumna inscrita en su sede'
);

-- =============================================================================
-- 4. Portal de la alumna aislado (US-27)
-- =============================================================================
SELECT pg_temp.como_sistema();
SELECT pg_temp.actuar_como('aa100000-0000-0000-0000-00000000000a');

SELECT set_eq($$ SELECT nombres::text FROM public.alumnas $$, ARRAY['Valentina'], 'La alumna solo ve su propia ficha');
SELECT is_empty($$ SELECT 1 FROM public.autorizaciones_apoderado $$, 'La alumna no ve registros de autorizaciones');
SELECT is_empty($$ SELECT 1 FROM public.correos_autorizados $$, 'La alumna no ve autorizaciones de correos');

-- =============================================================================
-- 5. Bloqueo tras 3 intentos fallidos (US-06 escenario 3)
-- =============================================================================
SELECT pg_temp.como_sistema();

SELECT public.hook_password_verification_attempt('{"user_id": "7a000000-0000-0000-0000-000000000001", "valid": false}');
SELECT public.hook_password_verification_attempt('{"user_id": "7a000000-0000-0000-0000-000000000001", "valid": false}');
SELECT is(
  public.hook_password_verification_attempt('{"user_id": "7a000000-0000-0000-0000-000000000001", "valid": false}') ->> 'decision',
  'reject',
  'El tercer fallo consecutivo bloquea la cuenta'
);
SELECT is(
  public.hook_password_verification_attempt('{"user_id": "7a000000-0000-0000-0000-000000000001", "valid": true}') ->> 'decision',
  'reject',
  'Una cuenta bloqueada rechaza incluso la contraseña correcta'
);

UPDATE auth.users SET encrypted_password = 'nueva' WHERE id = '7a000000-0000-0000-0000-000000000001';
SELECT is(
  public.hook_password_verification_attempt('{"user_id": "7a000000-0000-0000-0000-000000000001", "valid": true}') ->> 'decision',
  'continue',
  'Restablecer la contraseña desbloquea la cuenta'
);

SELECT * FROM finish();
ROLLBACK;
