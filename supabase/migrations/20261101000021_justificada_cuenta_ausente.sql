-- =============================================================================
-- Migration: 20261101000021_justificada_cuenta_ausente.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Una clase justificada sigue contando como ausente (decidido el
--              2026-11-16 al revisar el PR 7).
--
-- El justificativo aceptado no suma a la asistencia: solo baja la meta para
-- certificar al 70 %, una vez, tenga uno o varios (US-25, US-37 E2). La única
-- forma de que una justificada cuente como presente es recuperarla con
-- ejercicios (portal_alumna, migración 20).
--
-- La nómina de la Directiva (vista nomina_alumnas) y asistencia_inscripcion()
-- contaban la justificada como asistida; ahora cuentan solo las presentes,
-- igual que el portal y el dashboard.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. NÓMINA DE LA DIRECTIVA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.nomina_alumnas WITH (security_invoker = true) AS
SELECT
  i.id AS inscripcion_id,
  i.alumna_id,
  a.rut,
  a.nombres,
  a.apellidos,
  i.instancia_curso_id,
  ic.sede_id,
  s.nombre AS sede_nombre,
  c.codigo AS curso_codigo,
  c.nombre AS curso_nombre,
  ic.periodo_academico,
  ic.seccion,
  ic.fecha_inicio,
  i.estado,
  i.fecha_inscripcion,
  i.fecha_retiro,
  i.motivo_retiro,
  coalesce(au.autoriza_tratamiento_datos, 'pendiente') AS tratamiento_datos,
  coalesce(au.autoriza_tratamiento_datos = 'otorgada' AND au.autoriza_uso_imagen_general = 'otorgada', false)
    AS autoriza_fotos,
  asis.clases_computables,
  asis.clases_asistidas,
  ses.sesiones_transcurridas,
  (i.estado = 'preinscrita' AND ses.sesiones_transcurridas >= 2) AS regularizacion_urgente
FROM public.inscripciones i
JOIN public.alumnas a ON a.id = i.alumna_id
JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
JOIN public.sedes s ON s.id = ic.sede_id
JOIN public.cursos c ON c.id = ic.curso_id
LEFT JOIN public.autorizaciones_apoderado au ON au.alumna_id = i.alumna_id
LEFT JOIN LATERAL (
  SELECT
    count(*)::int AS clases_computables,
    count(*) FILTER (WHERE aa.estado = 'presente')::int AS clases_asistidas
  FROM public.clases cl
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = cl.id AND aa.inscripcion_id = i.id
  WHERE cl.instancia_curso_id = i.instancia_curso_id AND cl.estado = 'realizada'
) asis ON true
LEFT JOIN LATERAL (
  SELECT count(*)::int AS sesiones_transcurridas
  FROM public.clases cl
  WHERE cl.instancia_curso_id = i.instancia_curso_id
    AND cl.estado <> 'suspendida'
    AND cl.fecha >= i.fecha_inscripcion
    AND cl.fecha <= current_date
) ses ON true
WHERE public.is_directorio();

-- -----------------------------------------------------------------------------
-- 2. PORCENTAJE DE ASISTENCIA DE UNA INSCRIPCIÓN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.asistencia_inscripcion(p_inscripcion_id uuid)
RETURNS TABLE (clases_computables int, clases_asistidas int, porcentaje numeric)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT
    count(*)::int,
    count(*) FILTER (WHERE a.estado = 'presente')::int,
    CASE WHEN count(*) = 0 THEN NULL
      ELSE round(100.0 * count(*) FILTER (WHERE a.estado = 'presente') / count(*), 1)
    END
  FROM public.inscripciones i
  JOIN public.clases c ON c.instancia_curso_id = i.instancia_curso_id AND c.estado = 'realizada'
  LEFT JOIN public.asistencia_alumnas a ON a.clase_id = c.id AND a.inscripcion_id = i.id
  WHERE i.id = p_inscripcion_id;
$$;
