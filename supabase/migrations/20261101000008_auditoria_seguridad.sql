-- =============================================================================
-- Migration: 20261101000008_auditoria_seguridad.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Bitácora inmutable de eventos de seguridad (RNF-S-4): registros
--              rechazados por el registro cerrado (US-04, US-05), cuentas
--              bloqueadas tras 3 intentos fallidos (US-06) y autorizaciones de
--              correo denegadas por falta de privilegios (US-04 escenario 3).
--
-- auditoria_cambios_datos exige un perfil que ejecuta la acción; estos eventos
-- pueden no tener perfil (un registro rechazado ni siquiera crea usuario), por
-- eso viven en su propia tabla. Los hooks de Auth confirman su transacción
-- aunque rechacen la operación, así que el evento queda guardado.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. BITÁCORA
-- -----------------------------------------------------------------------------
CREATE TYPE public.evento_seguridad AS ENUM (
  'registro_rechazado',
  'cuenta_bloqueada',
  'autorizacion_denegada'
);

CREATE TABLE public.auditoria_seguridad (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  evento public.evento_seguridad NOT NULL,
  -- Sin FK: el registro se conserva aunque la cuenta se elimine
  usuario_id UUID,
  correo VARCHAR(150),
  detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
  fecha_hora TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX auditoria_seguridad_fecha_idx ON public.auditoria_seguridad (fecha_hora DESC);

ALTER TABLE public.auditoria_seguridad ENABLE ROW LEVEL SECURITY;

-- Solo la Directiva la consulta; nadie la escribe ni la altera desde la API
CREATE POLICY auditoria_seguridad_select ON public.auditoria_seguridad FOR SELECT TO authenticated
  USING (public.is_directorio());

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.auditoria_seguridad FROM anon, authenticated, public;

-- Única vía de escritura: las funciones del sistema
CREATE OR REPLACE FUNCTION public.registrar_evento_seguridad(
  p_evento public.evento_seguridad,
  p_usuario uuid,
  p_correo text,
  p_detalle jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  INSERT INTO public.auditoria_seguridad (evento, usuario_id, correo, detalle)
  VALUES (p_evento, p_usuario, lower(btrim(p_correo)), coalesce(p_detalle, '{}'::jsonb));
$$;

REVOKE EXECUTE ON FUNCTION public.registrar_evento_seguridad(public.evento_seguridad, uuid, text, jsonb)
  FROM anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- 2. REGISTRO RECHAZADO (deja de ser STABLE: ahora escribe en la bitácora)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_correo text := event -> 'user' ->> 'email';
BEGIN
  IF v_correo IS NULL OR (public.autorizacion_vigente(v_correo)).id IS NULL THEN
    PERFORM public.registrar_evento_seguridad(
      'registro_rechazado',
      NULL,
      v_correo,
      jsonb_build_object('ip', event -> 'metadata' ->> 'ip_address')
    );
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'Este correo no está autorizado para crear una cuenta. Pide a tu sede que lo habilite.'
      )
    );
  END IF;
  RETURN '{}'::jsonb;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. CUENTA BLOQUEADA
--    El intento que bloquea la cuenta responde con un mensaje propio ("quedó
--    bloqueada") para que la app envíe en ese momento el código de desbloqueo.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hook_password_verification_attempt(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (event ->> 'user_id')::uuid;
  v_valida boolean := (event ->> 'valid')::boolean;
  v_intento public.intentos_login;
  v_mensaje constant text :=
    'Tu cuenta está bloqueada por 3 intentos fallidos. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
  v_mensaje_bloqueo constant text :=
    'Tu cuenta quedó bloqueada por 3 intentos fallidos. Te enviamos un código a tu correo para desbloquearla.';
BEGIN
  SELECT * INTO v_intento FROM public.intentos_login WHERE user_id = v_user;

  IF v_intento.bloqueada_en IS NOT NULL THEN
    RETURN jsonb_build_object('decision', 'reject', 'message', v_mensaje, 'should_logout_user', true);
  END IF;

  IF v_valida THEN
    DELETE FROM public.intentos_login WHERE user_id = v_user;
    DELETE FROM public.recuperaciones_pendientes WHERE user_id = v_user;
    RETURN jsonb_build_object('decision', 'continue');
  END IF;

  INSERT INTO public.intentos_login AS il (user_id, fallos_consecutivos)
  VALUES (v_user, 1)
  ON CONFLICT (user_id) DO UPDATE
    SET fallos_consecutivos = il.fallos_consecutivos + 1,
        ultimo_intento = timezone('utc'::text, now())
  RETURNING * INTO v_intento;

  IF v_intento.fallos_consecutivos >= 3 THEN
    UPDATE public.intentos_login
    SET bloqueada_en = timezone('utc'::text, now())
    WHERE user_id = v_user;

    PERFORM public.registrar_evento_seguridad(
      'cuenta_bloqueada',
      v_user,
      (SELECT u.email FROM auth.users u WHERE u.id = v_user),
      jsonb_build_object('fallos_consecutivos', v_intento.fallos_consecutivos)
    );
    RETURN jsonb_build_object('decision', 'reject', 'message', v_mensaje_bloqueo, 'should_logout_user', true);
  END IF;

  RETURN jsonb_build_object('decision', 'continue');
END;
$$;

GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_password_verification_attempt(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) FROM authenticated, anon, public;
REVOKE EXECUTE ON FUNCTION public.hook_password_verification_attempt(jsonb) FROM authenticated, anon, public;
