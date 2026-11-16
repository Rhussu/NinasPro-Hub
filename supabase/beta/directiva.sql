-- =============================================================================
-- Cuenta inicial de la BETA (rama premain): solo directiva@ninaspro.cl.
-- La beta NO lleva datos de seed.sql. Desde esta cuenta se crean a mano sedes,
-- cursos, tutoras y alumnas.
--
-- La aplica cd-database.yml ("Run workflow" en premain con crear_directiva=true),
-- que reemplaza __CLAVE__ por el secreto BETA_CLAVE_CUENTAS. No borra nada: si
-- la cuenta ya existe, solo actualiza su contraseña.
-- El perfil lo crea el trigger de auth.users a partir de correos_autorizados.
-- La primera vez que entra, la app le pide inscribir el segundo factor (TOTP).
-- =============================================================================

BEGIN;

INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por)
VALUES ('directiva@ninaspro.cl', 'directorio', NULL, '10.234.567-3', 'Directiva', 'Nacional', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current, reauthentication_token)
SELECT '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
  'directiva@ninaspro.cl', extensions.crypt('__CLAVE__', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '', '', ''
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'directiva@ninaspro.cl');

UPDATE auth.users
SET encrypted_password = extensions.crypt('__CLAVE__', extensions.gen_salt('bf')), updated_at = now()
WHERE email = 'directiva@ninaspro.cl'
  AND encrypted_password IS DISTINCT FROM extensions.crypt('__CLAVE__', encrypted_password);

INSERT INTO auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
SELECT gen_random_uuid(), u.id, u.id::text, 'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), now(), now(), now()
FROM auth.users u
WHERE u.email = 'directiva@ninaspro.cl'
  AND NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email');

COMMIT;
