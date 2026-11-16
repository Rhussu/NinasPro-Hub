-- =============================================================================
-- Migration: 20261101000017_podio_segun_presentes.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: El podio Kahoot se registra aunque haya menos de tres alumnas
--              presentes (US-29, ajuste de la revisión del PR 4).
--
--   - El podio lleva tantos lugares como alumnas presentes, hasta tres: con
--     dos se elige quién quedó primera y quién segunda; con una sola, queda
--     primera.
--   - Los lugares se llenan en orden (sin 3° lugar si falta el 2°), cada uno
--     con una alumna presente distinta.
--   - Reemplaza a guardar_podio_kahoot de la migración 15 con la misma firma:
--     p_segundo y p_tercero pueden ser NULL.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.guardar_podio_kahoot(
  p_clase_id uuid,
  p_primero uuid,
  p_segundo uuid,
  p_tercero uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_podio uuid[];
  v_lugares int;
  v_presentes int;
  v_esperados int;
BEGIN
  v_clase := public.clase_operable(p_clase_id);

  IF p_primero IS NULL OR (p_segundo IS NULL AND p_tercero IS NOT NULL) THEN
    RAISE EXCEPTION 'Completa los lugares del podio en orden, desde el 1° lugar.' USING ERRCODE = '22023';
  END IF;
  v_podio := array_remove(ARRAY[p_primero, p_segundo, p_tercero], NULL);
  v_lugares := cardinality(v_podio);

  IF (SELECT count(DISTINCT x) FROM unnest(v_podio) AS x) <> v_lugares THEN
    RAISE EXCEPTION 'Elige % alumnas distintas para el podio.', CASE v_lugares WHEN 2 THEN 'dos' ELSE 'tres' END
      USING ERRCODE = '22023';
  END IF;

  IF (
    SELECT count(*) FROM public.asistencia_alumnas
    WHERE clase_id = p_clase_id AND inscripcion_id = ANY (v_podio) AND estado = 'presente'
  ) <> v_lugares THEN
    RAISE EXCEPTION 'El podio solo admite alumnas presentes en la clase.' USING ERRCODE = '22023';
  END IF;

  -- Un lugar por alumna presente, hasta tres
  SELECT count(*) INTO v_presentes FROM public.asistencia_alumnas WHERE clase_id = p_clase_id AND estado = 'presente';
  v_esperados := least(v_presentes, 3);
  IF v_lugares <> v_esperados THEN
    RAISE EXCEPTION 'Con % alumnas presentes, el podio lleva % lugares.', v_presentes, v_esperados
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('participacion_clase:' || p_clase_id::text));

  UPDATE public.participacion_clase SET podio_kahoot = NULL
  WHERE clase_id = p_clase_id AND podio_kahoot IS NOT NULL AND inscripcion_id <> ALL (v_podio);

  -- Libera los lugares antes de reasignarlos para no chocar con el índice único
  UPDATE public.participacion_clase SET podio_kahoot = NULL
  WHERE clase_id = p_clase_id AND inscripcion_id = ANY (v_podio)
    AND podio_kahoot IS DISTINCT FROM array_position(v_podio, inscripcion_id);

  INSERT INTO public.participacion_clase (clase_id, inscripcion_id, podio_kahoot, registrado_por)
  SELECT p_clase_id, x.inscripcion_id, x.lugar::int, auth.uid()
  FROM unnest(v_podio) WITH ORDINALITY AS x(inscripcion_id, lugar)
  ON CONFLICT (clase_id, inscripcion_id) DO UPDATE
    SET podio_kahoot = EXCLUDED.podio_kahoot
    WHERE participacion_clase.podio_kahoot IS DISTINCT FROM EXCLUDED.podio_kahoot;
END;
$$;
