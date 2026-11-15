-- =============================================================================
-- Migration: 20261101000007_sesion_recuperacion.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Una sesión obtenida con el enlace de recuperación no da acceso a
--              datos hasta que se define una contraseña nueva, y una cuenta
--              bloqueada por intentos fallidos pierde el acceso aunque tenga una
--              sesión abierta (US-05, US-06).
--
-- El JWT de una recuperación trae amr = 'otp', igual que otras verificaciones
-- por correo, así que el estado se lleva en la base: Auth limpia
-- auth.users.recovery_token al canjear el enlace sin cambiar la contraseña.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RECUPERACIONES PENDIENTES
-- -----------------------------------------------------------------------------
CREATE TABLE public.recuperaciones_pendientes (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  canjeada_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Sin políticas: solo la leen las funciones del sistema
ALTER TABLE public.recuperaciones_pendientes ENABLE ROW LEVEL SECURITY;

-- Canje del enlace: recovery_token pasa a vacío y la contraseña no cambia.
-- Cambio de contraseña: la recuperación termina (y el trigger de la migración
-- 06 ya desbloquea la cuenta).
CREATE OR REPLACE FUNCTION public.seguir_recuperacion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    DELETE FROM public.recuperaciones_pendientes WHERE user_id = NEW.id;
  ELSIF coalesce(OLD.recovery_token, '') <> '' AND coalesce(NEW.recovery_token, '') = '' THEN
    INSERT INTO public.recuperaciones_pendientes (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO UPDATE SET canjeada_en = excluded.canjeada_en;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_recovery
  AFTER UPDATE OF recovery_token, encrypted_password ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.seguir_recuperacion();

-- Ingresar con la contraseña correcta también cierra una recuperación a medias
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
    RETURN jsonb_build_object('decision', 'reject', 'message', v_mensaje, 'should_logout_user', true);
  END IF;

  RETURN jsonb_build_object('decision', 'continue');
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. SIN ROL (Y SIN DATOS) DURANTE LA RECUPERACIÓN O CON LA CUENTA BLOQUEADA
--    Todas las políticas RLS dependen de current_user_role().
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.rol_usuario
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT p.rol FROM public.perfiles p
  WHERE p.id = auth.uid()
    AND p.activo
    AND NOT EXISTS (SELECT 1 FROM public.recuperaciones_pendientes r WHERE r.user_id = p.id)
    AND NOT EXISTS (SELECT 1 FROM public.intentos_login il WHERE il.user_id = p.id AND il.bloqueada_en IS NOT NULL);
$$;

-- La ficha propia de la alumna tampoco se entrega sin rol vigente
CREATE OR REPLACE FUNCTION public.alumna_actual_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT a.id FROM public.alumnas a
  WHERE a.perfil_usuario_id = auth.uid() AND public.current_user_role() = 'alumna';
$$;

-- Perfil propio: visible solo con la cuenta en regla
DROP POLICY perfiles_select ON public.perfiles;
CREATE POLICY perfiles_select ON public.perfiles FOR SELECT TO authenticated
  USING ((id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.perfil_en_mis_sedes(id));

DROP POLICY voluntarios_select ON public.voluntarios_detalle;
CREATE POLICY voluntarios_select ON public.voluntarios_detalle FOR SELECT TO authenticated
  USING ((perfil_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.perfil_en_mis_sedes(perfil_id));

DROP POLICY usuarios_sedes_select ON public.usuarios_sedes;
CREATE POLICY usuarios_sedes_select ON public.usuarios_sedes FOR SELECT TO authenticated
  USING ((perfil_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.es_staff_sede(sede_id));

DROP POLICY tutores_instancia_select ON public.tutores_instancia;
CREATE POLICY tutores_instancia_select ON public.tutores_instancia FOR SELECT TO authenticated
  USING ((tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.es_staff_sede(public.sede_instancia(instancia_curso_id)));

DROP POLICY tareas_select ON public.tareas_semanales_tutores;
CREATE POLICY tareas_select ON public.tareas_semanales_tutores FOR SELECT TO authenticated
  USING ((tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.es_staff_sede(public.sede_clase(clase_id)));

DROP POLICY tareas_update ON public.tareas_semanales_tutores;
CREATE POLICY tareas_update ON public.tareas_semanales_tutores FOR UPDATE TO authenticated
  USING ((tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.gestiona_sede(public.sede_clase(clase_id)))
  WITH CHECK ((tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.gestiona_sede(public.sede_clase(clase_id)));

DROP POLICY asistencia_tutores_select ON public.asistencia_tutores;
CREATE POLICY asistencia_tutores_select ON public.asistencia_tutores FOR SELECT TO authenticated
  USING ((tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL) OR public.es_staff_sede(public.sede_clase(clase_id)));

-- -----------------------------------------------------------------------------
-- 3. ESTADO DE LA CUENTA PARA LA APP
-- -----------------------------------------------------------------------------
-- La app lo consulta al abrir una sesión: si hay una recuperación pendiente debe
-- pedir la contraseña nueva en vez de entrar
CREATE OR REPLACE FUNCTION public.estado_mi_cuenta()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'recuperacion_pendiente', EXISTS (SELECT 1 FROM public.recuperaciones_pendientes WHERE user_id = auth.uid()),
    'bloqueada', EXISTS (SELECT 1 FROM public.intentos_login WHERE user_id = auth.uid() AND bloqueada_en IS NOT NULL)
  );
$$;

REVOKE EXECUTE ON FUNCTION public.estado_mi_cuenta() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.estado_mi_cuenta() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.seguir_recuperacion() FROM anon, authenticated, public;
