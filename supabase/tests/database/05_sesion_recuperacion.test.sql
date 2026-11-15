BEGIN;
SELECT plan(10);

-- Tutora de prueba con su sede
INSERT INTO public.sedes (id, nombre) VALUES ('5e000000-0000-0000-0000-000000000001', 'Sede Recuperación');
INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por) VALUES
  ('test.recupera@ninaspro.cl', 'tutora', '5e000000-0000-0000-0000-000000000001', '17.171.717-1', 'Rita', 'Recupera', NULL);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, recovery_token)
VALUES ('00000000-0000-0000-0000-000000000000', '5e000000-0000-0000-0000-0000000000aa', 'authenticated', 'authenticated',
        'test.recupera@ninaspro.cl', 'clave-original', '');

CREATE OR REPLACE FUNCTION pg_temp.como_rita() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', '{"sub": "5e000000-0000-0000-0000-0000000000aa", "role": "authenticated"}', true);
  EXECUTE 'SET LOCAL role authenticated';
END;
$$;
CREATE OR REPLACE FUNCTION pg_temp.como_sistema() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE 'RESET role';
END;
$$;

-- 1. Cuenta en regla
SELECT pg_temp.como_rita();
SELECT is(public.current_user_role()::text, 'tutora', 'Con la cuenta en regla la tutora tiene su rol');
SELECT pg_temp.como_sistema();

-- 2. Pide el enlace y lo canjea: Auth guarda y luego limpia recovery_token
UPDATE auth.users SET recovery_token = 'hash-del-enlace' WHERE id = '5e000000-0000-0000-0000-0000000000aa';
SELECT is_empty(
  $$ SELECT 1 FROM public.recuperaciones_pendientes WHERE user_id = '5e000000-0000-0000-0000-0000000000aa' $$,
  'Pedir el enlace no deja una recuperación pendiente'
);
UPDATE auth.users SET recovery_token = '' WHERE id = '5e000000-0000-0000-0000-0000000000aa';

SELECT pg_temp.como_rita();
SELECT is(public.current_user_role(), NULL, 'Con el enlace canjeado y sin contraseña nueva no hay rol');
SELECT is_empty($$ SELECT 1 FROM public.perfiles $$, 'La sesión de recuperación no ve ni su propio perfil');
SELECT is(
  public.estado_mi_cuenta() ->> 'recuperacion_pendiente',
  'true',
  'La app sabe que debe pedir la contraseña nueva'
);
SELECT pg_temp.como_sistema();

-- 3. Define la contraseña nueva: recupera el acceso
UPDATE auth.users SET encrypted_password = 'clave-nueva' WHERE id = '5e000000-0000-0000-0000-0000000000aa';
SELECT pg_temp.como_rita();
SELECT is(public.current_user_role()::text, 'tutora', 'Tras la contraseña nueva vuelve el rol');
SELECT isnt_empty($$ SELECT 1 FROM public.perfiles WHERE id = auth.uid() $$, 'Y vuelve a ver su perfil');
SELECT pg_temp.como_sistema();

-- 4. Ingresar con la contraseña correcta también cierra una recuperación a medias
UPDATE auth.users SET recovery_token = 'otro-enlace' WHERE id = '5e000000-0000-0000-0000-0000000000aa';
UPDATE auth.users SET recovery_token = '' WHERE id = '5e000000-0000-0000-0000-0000000000aa';
SELECT public.hook_password_verification_attempt('{"user_id": "5e000000-0000-0000-0000-0000000000aa", "valid": true}');
SELECT is_empty($$ SELECT 1 FROM public.recuperaciones_pendientes WHERE user_id = '5e000000-0000-0000-0000-0000000000aa' $$, 'Un ingreso con contraseña válida cierra la recuperación');

-- 5. Una cuenta bloqueada pierde el acceso aunque tenga una sesión abierta
INSERT INTO public.intentos_login (user_id, fallos_consecutivos, bloqueada_en)
VALUES ('5e000000-0000-0000-0000-0000000000aa', 3, now());
SELECT pg_temp.como_rita();
SELECT is(public.current_user_role(), NULL, 'Con la cuenta bloqueada no hay rol');
SELECT is(public.estado_mi_cuenta() ->> 'bloqueada', 'true', 'La app sabe que la cuenta está bloqueada');

SELECT * FROM finish();
ROLLBACK;
