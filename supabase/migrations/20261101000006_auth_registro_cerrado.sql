-- =============================================================================
-- Migration: 20261101000006_auth_registro_cerrado.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Registro cerrado por correos autorizados (US-04, US-05) y bloqueo
--              de cuenta tras 3 contraseñas erróneas consecutivas (US-06).
--
-- Flujo:
--   1. Directiva (o Gestión, solo para alumnas de su sede) autoriza un correo
--      con su rol y sede en correos_autorizados.
--   2. La persona crea su cuenta con ese correo. El hook before_user_created
--      rechaza cualquier correo no autorizado o con autorización vencida.
--   3. Al confirmar el correo (enlace de un solo uso) la cuenta queda activa; el
--      trigger on_auth_user_created ya creó su perfil, su sede y, si es alumna,
--      la vinculó con su ficha.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CORREOS AUTORIZADOS
-- -----------------------------------------------------------------------------
CREATE TABLE public.correos_autorizados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correo VARCHAR(150) NOT NULL CHECK (correo = lower(btrim(correo)) AND correo LIKE '%_@_%'),
  rol public.rol_usuario NOT NULL,
  sede_id UUID REFERENCES public.sedes(id) ON DELETE CASCADE,
  alumna_id UUID REFERENCES public.alumnas(id) ON DELETE CASCADE,
  rut VARCHAR(12),
  nombres VARCHAR(100),
  apellidos VARCHAR(100),
  -- NULL solo para autorizaciones creadas por el sistema (arranque de la Directiva)
  autorizado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL DEFAULT auth.uid(),
  expira_en TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + interval '30 days'),
  usado_en TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  -- La alumna toma sus datos de su ficha; el resto de los roles los declara aquí
  CONSTRAINT correos_autorizados_datos_por_rol CHECK (
    (rol = 'alumna' AND alumna_id IS NOT NULL)
    OR (rol <> 'alumna' AND alumna_id IS NULL AND rut IS NOT NULL AND nombres IS NOT NULL AND apellidos IS NOT NULL)
  ),
  -- Solo la Directiva tiene alcance nacional; los demás roles se asignan a una sede
  CONSTRAINT correos_autorizados_sede_por_rol CHECK (rol = 'directorio' OR sede_id IS NOT NULL),
  -- Las cuentas del voluntariado usan correo institucional (US-04)
  CONSTRAINT correos_autorizados_dominio_institucional CHECK (rol = 'alumna' OR correo LIKE '%@ninaspro.cl')
);

-- Un correo solo puede tener una autorización pendiente a la vez
CREATE UNIQUE INDEX correos_autorizados_pendiente_unico
  ON public.correos_autorizados (correo)
  WHERE usado_en IS NULL;

ALTER TABLE public.correos_autorizados ENABLE ROW LEVEL SECURITY;

CREATE POLICY correos_autorizados_select ON public.correos_autorizados FOR SELECT TO authenticated
  USING (public.is_directorio() OR (sede_id IS NOT NULL AND public.gestiona_sede(sede_id)));

-- Directiva autoriza cualquier rol. Gestión solo alumnas inscritas en su sede (US-04 escenario 3)
CREATE POLICY correos_autorizados_insert ON public.correos_autorizados FOR INSERT TO authenticated
  WITH CHECK (
    usado_en IS NULL
    AND autorizado_por = auth.uid()
    AND (
      public.is_directorio()
      OR (rol = 'alumna' AND public.gestiona_sede(sede_id) AND public.gestiona_alumna(alumna_id))
    )
  );

-- Revocar una autorización que aún no se usa
CREATE POLICY correos_autorizados_delete ON public.correos_autorizados FOR DELETE TO authenticated
  USING (
    usado_en IS NULL
    AND (public.is_directorio() OR (rol = 'alumna' AND public.gestiona_sede(sede_id)))
  );

-- Autorización vigente para un correo (uso interno de auth)
CREATE OR REPLACE FUNCTION public.autorizacion_vigente(p_correo text)
RETURNS public.correos_autorizados
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT ca.* FROM public.correos_autorizados ca
  WHERE ca.correo = lower(btrim(p_correo))
    AND ca.usado_en IS NULL
    AND ca.expira_en > timezone('utc'::text, now())
  LIMIT 1;
$$;

-- -----------------------------------------------------------------------------
-- 2. HOOK before_user_created: rechaza registros sin correo autorizado
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_correo text := event -> 'user' ->> 'email';
BEGIN
  IF v_correo IS NULL OR (public.autorizacion_vigente(v_correo)).id IS NULL THEN
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
-- 3. CREACIÓN DEL PERFIL AL REGISTRARSE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_perfil_desde_autorizacion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_aut public.correos_autorizados;
  v_alumna public.alumnas;
BEGIN
  v_aut := public.autorizacion_vigente(NEW.email);

  -- Defensa en profundidad: el hook ya debió rechazar este registro
  IF v_aut.id IS NULL THEN
    RAISE EXCEPTION 'El correo % no tiene una autorización vigente', NEW.email
      USING ERRCODE = '42501';
  END IF;

  IF v_aut.rol = 'alumna' THEN
    SELECT * INTO v_alumna FROM public.alumnas WHERE id = v_aut.alumna_id;

    INSERT INTO public.perfiles (id, rut, nombres, apellidos, correo, rol)
    VALUES (NEW.id, v_alumna.rut, v_alumna.nombres, v_alumna.apellidos, v_aut.correo, 'alumna');

    UPDATE public.alumnas
    SET perfil_usuario_id = NEW.id,
        correo = coalesce(correo, v_aut.correo),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_aut.alumna_id;
  ELSE
    INSERT INTO public.perfiles (id, rut, nombres, apellidos, correo, rol)
    VALUES (NEW.id, v_aut.rut, v_aut.nombres, v_aut.apellidos, v_aut.correo, v_aut.rol);
  END IF;

  IF v_aut.sede_id IS NOT NULL THEN
    INSERT INTO public.usuarios_sedes (perfil_id, sede_id)
    VALUES (NEW.id, v_aut.sede_id)
    ON CONFLICT (perfil_id, sede_id) DO NOTHING;
  END IF;

  UPDATE public.correos_autorizados
  SET usado_en = timezone('utc'::text, now())
  WHERE id = v_aut.id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.crear_perfil_desde_autorizacion();

-- -----------------------------------------------------------------------------
-- 4. BLOQUEO TRAS 3 INTENTOS FALLIDOS (US-06)
--    Se desbloquea al restablecer la contraseña desde "¿Olvidaste tu contraseña?"
-- -----------------------------------------------------------------------------
CREATE TABLE public.intentos_login (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fallos_consecutivos INTEGER NOT NULL DEFAULT 0,
  bloqueada_en TIMESTAMPTZ,
  ultimo_intento TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Sin políticas: solo el hook y los triggers del sistema la leen o escriben
ALTER TABLE public.intentos_login ENABLE ROW LEVEL SECURITY;

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
BEGIN
  SELECT * INTO v_intento FROM public.intentos_login WHERE user_id = v_user;

  IF v_intento.bloqueada_en IS NOT NULL THEN
    RETURN jsonb_build_object('decision', 'reject', 'message', v_mensaje, 'should_logout_user', true);
  END IF;

  IF v_valida THEN
    DELETE FROM public.intentos_login WHERE user_id = v_user;
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
    RETURN jsonb_build_object('decision', 'reject', 'message', v_mensaje, 'should_logout_user', true);
  END IF;

  RETURN jsonb_build_object('decision', 'continue');
END;
$$;

-- Restablecer la contraseña desbloquea la cuenta
CREATE OR REPLACE FUNCTION public.desbloquear_al_cambiar_contrasena()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    DELETE FROM public.intentos_login WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_password_changed
  AFTER UPDATE OF encrypted_password ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.desbloquear_al_cambiar_contrasena();

-- -----------------------------------------------------------------------------
-- 5. PERMISOS DE LOS HOOKS: solo los ejecuta el servicio de Auth
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_password_verification_attempt(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) FROM authenticated, anon, public;
REVOKE EXECUTE ON FUNCTION public.hook_password_verification_attempt(jsonb) FROM authenticated, anon, public;
REVOKE EXECUTE ON FUNCTION public.autorizacion_vigente(text) FROM authenticated, anon, public;
