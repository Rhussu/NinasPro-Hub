-- =============================================================================
-- Migration: 20261101000016_auditoria.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Bitácora automática e inmutable de cambios de datos (US-15,
--              base de US-23 y US-24).
--
--   - auditar(): trigger genérico que guarda en auditoria_cambios_datos la
--     acción, la tabla, el registro, el valor anterior y el nuevo (JSONB), la
--     autora, la IP y el navegador de la petición.
--   - Se activa en las tablas de la clase (asistencia de alumnas y de tutoras,
--     participación y podio). El PR de auditoría lo extiende a las demás.
--   - Las operaciones del sistema (seed, service role) quedan con autora NULL.
--   - Nadie escribe en las bitácoras directamente: solo los triggers y RPC del
--     sistema. Sin UPDATE ni DELETE, la historia no se puede reescribir.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. BITÁCORA DE CAMBIOS
-- -----------------------------------------------------------------------------
ALTER TABLE public.auditoria_cambios_datos
  ALTER COLUMN ejecutado_por DROP NOT NULL;

COMMENT ON COLUMN public.auditoria_cambios_datos.ejecutado_por IS
  'Perfil que hizo el cambio; NULL si lo hizo el sistema (seed, service role o un proceso interno).';

CREATE INDEX auditoria_cambios_registro_idx
  ON public.auditoria_cambios_datos (tabla_afectada, registro_id, fecha_hora DESC);
CREATE INDEX auditoria_cambios_fecha_idx
  ON public.auditoria_cambios_datos (fecha_hora DESC);

-- Encabezado de la petición HTTP actual (PostgREST); NULL fuera de una petición
CREATE OR REPLACE FUNCTION public.encabezado_peticion(p_nombre text)
RETURNS text
LANGUAGE plpgsql STABLE SET search_path = ''
AS $$
BEGIN
  RETURN nullif(current_setting('request.headers', true), '')::json ->> p_nombre;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.auditar()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_anterior jsonb := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END;
  v_nuevo jsonb := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END;
BEGIN
  -- Un UPDATE que solo toca la marca de tiempo no es un cambio de datos
  IF TG_OP = 'UPDATE' AND (v_anterior - 'updated_at') = (v_nuevo - 'updated_at') THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.auditoria_cambios_datos (
    tabla_afectada, registro_id, accion, valor_anterior, valor_nuevo, ejecutado_por, ip_address, user_agent
  )
  VALUES (
    TG_TABLE_NAME,
    (coalesce(v_nuevo, v_anterior) ->> 'id')::uuid,
    lower(TG_OP)::public.tipo_accion_auditoria,
    v_anterior,
    v_nuevo,
    (SELECT p.id FROM public.perfiles p WHERE p.id = auth.uid()),
    left(split_part(public.encabezado_peticion('x-forwarded-for'), ',', 1), 45),
    public.encabezado_peticion('user-agent')
  );
  RETURN NULL;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. TABLAS AUDITADAS: LA CLASE (US-15, US-33, US-34)
-- -----------------------------------------------------------------------------
CREATE TRIGGER asistencia_alumnas_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER asistencia_tutores_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.asistencia_tutores
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER participacion_clase_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.participacion_clase
  FOR EACH ROW EXECUTE FUNCTION public.auditar();

-- -----------------------------------------------------------------------------
-- 3. INMUTABILIDAD
-- -----------------------------------------------------------------------------
-- Las políticas de la migración 02 dejaban insertar a cualquier usuaria
-- autenticada (podía inventar eventos). Ahora solo escribe el sistema.
DROP POLICY "Registro de auditoría de cambios por usuarios autenticados" ON public.auditoria_cambios_datos;
DROP POLICY "Registro de auditoría de descargas por usuarios autenticados" ON public.auditoria_accesos_descargas;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.auditoria_cambios_datos, public.auditoria_accesos_descargas
  FROM anon, authenticated, public;

REVOKE ALL ON FUNCTION public.auditar() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.encabezado_peticion(text) FROM PUBLIC, anon, authenticated;
