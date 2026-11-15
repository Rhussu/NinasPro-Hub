-- =============================================================================
-- Migration: 20261101000010_mfa_directiva.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: La Directiva accede a los datos solo con el segundo factor TOTP
--              verificado en la sesión (RNF-S-1, US-05, US-06).
--
-- El JWT de Supabase Auth trae aal = 'aal2' cuando la sesión verificó un factor
-- MFA. Sin eso, current_user_role() devuelve NULL para la Directiva y todas las
-- políticas RLS le niegan el acceso. La app consulta estado_mi_cuenta() para
-- saber si debe pedir el código o inscribir el autenticador por primera vez.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sesion_con_mfa()
RETURNS boolean
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.rol_usuario
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT p.rol FROM public.perfiles p
  WHERE p.id = auth.uid()
    AND p.activo
    AND (p.rol <> 'directorio' OR public.sesion_con_mfa())
    AND NOT EXISTS (SELECT 1 FROM public.recuperaciones_pendientes r WHERE r.user_id = p.id)
    AND NOT EXISTS (SELECT 1 FROM public.intentos_login il WHERE il.user_id = p.id AND il.bloqueada_en IS NOT NULL);
$$;

CREATE OR REPLACE FUNCTION public.estado_mi_cuenta()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'recuperacion_pendiente', EXISTS (SELECT 1 FROM public.recuperaciones_pendientes WHERE user_id = auth.uid()),
    'bloqueada', EXISTS (SELECT 1 FROM public.intentos_login WHERE user_id = auth.uid() AND bloqueada_en IS NOT NULL),
    -- La Directiva debe verificar su segundo factor en esta sesión
    'mfa_requerida', EXISTS (
      SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'directorio' AND activo
    ) AND NOT public.sesion_con_mfa(),
    -- Ya tiene un autenticador inscrito (si no, la app la guía a inscribirlo)
    'mfa_inscrita', EXISTS (
      SELECT 1 FROM auth.mfa_factors
      WHERE user_id = auth.uid() AND factor_type = 'totp' AND status = 'verified'
    )
  );
$$;

REVOKE EXECUTE ON FUNCTION public.sesion_con_mfa() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.sesion_con_mfa() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.estado_mi_cuenta() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.estado_mi_cuenta() TO authenticated;
