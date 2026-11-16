-- =============================================================================
-- Migration: 20261101000018_justificativos_evidencias.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Justificativos de inasistencia y evidencia fotográfica de la
--              clase (US-16..20, US-35..38).
--
-- Justificativos:
--   - Se vinculan a la clase y a la inscripción, no a la fila de asistencia:
--     así se justifica por adelantado una clase futura (US-16 escenario 2,
--     US-35) y, al pasar lista, la alumna aparece justificada.
--   - La alumna los envía desde su portal y quedan pendientes. El Equipo de
--     Gestión de la sede los aprueba o rechaza (con observación), o los
--     registra ya aceptados cuando avisa la apoderada. Las tutoras solo ven el
--     estado y el motivo general en el pase de lista (US-38).
--   - Un justificativo aceptado deja la asistencia en justificada. Si se
--     elimina, vuelve a ausente (US-16 escenario 3).
--   - Un pendiente o aceptado por clase y alumna; tras un rechazo se puede
--     enviar otro (US-35 escenario 4).
--   - Minimización (RB-8): motivos tipificados y una explicación breve en
--     texto; no hay campo de diagnóstico. Por ahora no se adjuntan archivos
--     (archivo_adjunto_url queda sin uso).
--
-- Evidencias:
--   - La foto se sube comprimida al bucket privado evidencias y luego se
--     registra. El tamaño se toma del archivo subido, no del que informa la app.
--   - Solo se marca apta si todas las presentes tienen autorización de imagen,
--     o si se declara que las que no la tienen no son reconocibles (US-19).
--   - evidencias_pendientes: clases realizadas hace más de 48 horas sin foto,
--     según la RLS de quien consulta (US-20).
--
-- La auditoría (migración 16) se extiende a justificativos y evidencias.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. MOTIVOS TIPIFICADOS (US-35 escenario 2)
-- -----------------------------------------------------------------------------
-- Salud, Académico / Pruebas (escolar), Familiar / Personal, Transporte / Clima, Otro
ALTER TYPE public.motivo_justificativo ADD VALUE IF NOT EXISTS 'transporte' BEFORE 'otro';

-- -----------------------------------------------------------------------------
-- 2. JUSTIFICATIVOS POR CLASE E INSCRIPCIÓN
-- -----------------------------------------------------------------------------
DROP POLICY justificativos_select ON public.justificativos_inasistencia;
DROP POLICY justificativos_insert ON public.justificativos_inasistencia;
DROP POLICY justificativos_update ON public.justificativos_inasistencia;

ALTER TABLE public.justificativos_inasistencia
  ADD COLUMN clase_id uuid REFERENCES public.clases(id) ON DELETE CASCADE,
  ADD COLUMN inscripcion_id uuid REFERENCES public.inscripciones(id) ON DELETE CASCADE;

UPDATE public.justificativos_inasistencia j
SET clase_id = aa.clase_id, inscripcion_id = aa.inscripcion_id
FROM public.asistencia_alumnas aa
WHERE aa.id = j.asistencia_alumna_id;

ALTER TABLE public.justificativos_inasistencia
  DROP COLUMN asistencia_alumna_id,
  ALTER COLUMN clase_id SET NOT NULL,
  ALTER COLUMN inscripcion_id SET NOT NULL,
  ADD CONSTRAINT justificativos_explicacion CHECK (nullif(btrim(explicacion), '') IS NOT NULL),
  ADD CONSTRAINT justificativos_explicacion_breve CHECK (char_length(explicacion) <= 500),
  ADD CONSTRAINT justificativos_rechazo_observado CHECK (
    estado <> 'rechazado' OR nullif(btrim(observacion_resolucion), '') IS NOT NULL
  ),
  ADD CONSTRAINT justificativos_resolucion_completa CHECK (
    estado = 'pendiente' OR (resuelto_por IS NOT NULL AND fecha_resolucion IS NOT NULL)
  );

-- Un pendiente o aceptado por clase y alumna (US-35 escenario 4)
CREATE UNIQUE INDEX justificativos_vigente_unico
  ON public.justificativos_inasistencia (clase_id, inscripcion_id)
  WHERE estado IN ('pendiente', 'aceptado');
CREATE INDEX justificativos_inscripcion_idx ON public.justificativos_inasistencia (inscripcion_id);

COMMENT ON TABLE public.justificativos_inasistencia IS
  'Justificativos de inasistencia por clase e inscripción. Por minimización (RB-8) no hay campo de diagnóstico: solo el motivo tipificado y una explicación breve en texto.';
COMMENT ON COLUMN public.justificativos_inasistencia.archivo_adjunto_url IS
  'Sin uso por ahora: los justificativos no llevan archivos adjuntos.';

-- La alumna lee los suyos; Gestión de la sede y la Directiva, todos los de la
-- sede. Las tutoras no leen la tabla: ven estado y motivo en el pase de lista.
CREATE POLICY justificativos_select ON public.justificativos_inasistencia FOR SELECT TO authenticated
  USING (public.gestiona_sede(public.sede_clase(clase_id)) OR public.inscripcion_propia(inscripcion_id));

-- Las escrituras pasan por las RPC de la sección 5
REVOKE INSERT, UPDATE, DELETE ON public.justificativos_inasistencia FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.justificativo_aceptado(p_clase uuid, p_inscripcion uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.justificativos_inasistencia
    WHERE clase_id = p_clase AND inscripcion_id = p_inscripcion AND estado = 'aceptado'
  );
$$;

-- Estado y motivo del justificativo de la alumna en la clase, para el staff de
-- la sede (sin la explicación). Prioriza el vigente.
CREATE OR REPLACE FUNCTION public.resumen_justificativo(p_clase uuid, p_inscripcion uuid)
RETURNS TABLE (estado public.estado_justificativo, motivo public.motivo_justificativo)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT j.estado, j.motivo
  FROM public.justificativos_inasistencia j
  WHERE j.clase_id = p_clase AND j.inscripcion_id = p_inscripcion
    AND public.es_staff_sede(public.sede_clase(p_clase))
  ORDER BY j.estado = 'rechazado', j.created_at DESC
  LIMIT 1;
$$;

-- -----------------------------------------------------------------------------
-- 3. EL JUSTIFICATIVO ACEPTADO DEJA LA ASISTENCIA EN JUSTIFICADA (US-16, US-37)
-- -----------------------------------------------------------------------------
-- La sincronización no pasa por las reglas del pase de lista (la clase puede
-- estar cerrada o ser de otra semana): la marca ninaspro.sincronizar_justificativo
-- le avisa al trigger de asistencia que el cambio lo hace el sistema.
CREATE OR REPLACE FUNCTION public.sincronizar_justificativo()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM set_config('ninaspro.sincronizar_justificativo', 'on', true);

  IF TG_OP <> 'DELETE' AND NEW.estado = 'aceptado' AND (TG_OP = 'INSERT' OR OLD.estado <> 'aceptado') THEN
    UPDATE public.asistencia_alumnas SET estado = 'justificada'
    WHERE clase_id = NEW.clase_id AND inscripcion_id = NEW.inscripcion_id AND estado <> 'justificada';
  ELSIF TG_OP <> 'INSERT' AND OLD.estado = 'aceptado' AND (TG_OP = 'DELETE' OR NEW.estado <> 'aceptado') THEN
    UPDATE public.asistencia_alumnas SET estado = 'ausente'
    WHERE clase_id = OLD.clase_id AND inscripcion_id = OLD.inscripcion_id AND estado = 'justificada';
  END IF;

  PERFORM set_config('ninaspro.sincronizar_justificativo', '', true);
  RETURN NULL;
END;
$$;

CREATE TRIGGER justificativos_sincronizar_asistencia
  AFTER INSERT OR UPDATE OF estado OR DELETE ON public.justificativos_inasistencia
  FOR EACH ROW EXECUTE FUNCTION public.sincronizar_justificativo();

CREATE OR REPLACE FUNCTION public.justificativos_actualizado()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE TRIGGER justificativos_updated_at
  BEFORE UPDATE ON public.justificativos_inasistencia
  FOR EACH ROW EXECUTE FUNCTION public.justificativos_actualizado();

-- Reemplaza el trigger de la migración 15:
--   - Con un justificativo aceptado, la alumna entra al pase de lista como
--     justificada (precarga, US-16 escenario 2) y no se cambia a mano: se
--     elimina el justificativo.
--   - Los cambios de la sincronización de justificativos pasan sin las reglas
--     del pase de lista, pero quedan con su autora para la auditoría.
CREATE OR REPLACE FUNCTION public.validar_asistencia_alumna()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_insc public.inscripciones;
  v_aceptado boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
  END IF;

  IF current_setting('ninaspro.sincronizar_justificativo', true) = 'on' THEN
    NEW.registrado_por := coalesce(auth.uid(), NEW.registrado_por);
    RETURN NEW;
  END IF;

  -- Operaciones del sistema (seed, service role) no tienen auth.uid()
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_clase FROM public.clases WHERE id = NEW.clase_id;
  SELECT * INTO v_insc FROM public.inscripciones WHERE id = NEW.inscripcion_id;

  IF v_insc.id IS NULL OR v_insc.instancia_curso_id IS DISTINCT FROM v_clase.instancia_curso_id THEN
    RAISE EXCEPTION 'La alumna no está inscrita en el curso de esta clase.' USING ERRCODE = '22023';
  END IF;
  PERFORM public.validar_clase_registrable(v_clase);

  -- RB-1: solo alumnas con matrícula activa entran al pase de lista
  IF TG_OP = 'INSERT' AND v_insc.estado <> 'activa' THEN
    RAISE EXCEPTION 'Solo las alumnas con matrícula activa entran al pase de lista.' USING ERRCODE = '22023';
  END IF;

  v_aceptado := public.justificativo_aceptado(NEW.clase_id, NEW.inscripcion_id);
  IF v_aceptado THEN
    IF TG_OP = 'INSERT' THEN
      NEW.estado := 'justificada';
    ELSIF NEW.estado <> 'justificada' AND OLD.estado = 'justificada' THEN
      RAISE EXCEPTION 'La inasistencia tiene un justificativo aceptado: para cambiarla, elimina el justificativo.'
        USING ERRCODE = '22023';
    END IF;
  ELSIF (NEW.estado = 'justificada' OR (TG_OP = 'UPDATE' AND OLD.estado = 'justificada' AND NEW.estado <> OLD.estado))
    AND NOT public.gestiona_sede(public.sede_instancia(v_clase.instancia_curso_id))
  THEN
    RAISE EXCEPTION 'Las inasistencias justificadas las gestiona el Equipo de Gestión.' USING ERRCODE = '42501';
  END IF;

  -- Autoría del último cambio; la versión anterior queda en la auditoría
  NEW.registrado_por := auth.uid();
  RETURN NEW;
END;
$$;

-- Reemplaza la RPC de la migración 15 con la misma firma. Además de sus
-- reglas, una alumna con justificativo aceptado queda justificada: si la lista
-- la trae con otro estado, se conserva justificada y se informa.
CREATE OR REPLACE FUNCTION public.guardar_asistencia_clase(
  p_clase_id uuid,
  p_registros jsonb,
  p_guardado_en timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_gestion boolean;
  v_momento timestamptz := public.momento_guardado(p_guardado_en);
  v_fila record;
  v_actual public.asistencia_alumnas;
  v_estado_insc public.estado_inscripcion;
  v_aceptado boolean;
  v_guardados int := 0;
  v_sin_cambios int := 0;
  v_justificadas int := 0;
  v_posteriores int := 0;
  v_omitidas int := 0;
BEGIN
  v_clase := public.clase_operable(p_clase_id);
  v_gestion := public.gestiona_sede(public.sede_instancia(v_clase.instancia_curso_id));

  IF jsonb_typeof(p_registros) IS DISTINCT FROM 'array' OR jsonb_array_length(p_registros) = 0 THEN
    RAISE EXCEPTION 'La lista de asistencia está vacía.' USING ERRCODE = '22023';
  END IF;

  -- Dos guardados simultáneos de la misma clase se aplican uno después del otro
  PERFORM pg_advisory_xact_lock(hashtext('asistencia_alumnas:' || p_clase_id::text));

  FOR v_fila IN
    SELECT (e->>'inscripcion_id')::uuid AS inscripcion_id, (e->>'estado')::public.estado_asistencia AS estado
    FROM jsonb_array_elements(p_registros) AS e
  LOOP
    IF v_fila.inscripcion_id IS NULL OR v_fila.estado IS NULL THEN
      RAISE EXCEPTION 'Cada registro necesita la inscripción y el estado.' USING ERRCODE = '22023';
    END IF;

    SELECT estado INTO v_estado_insc
    FROM public.inscripciones
    WHERE id = v_fila.inscripcion_id AND instancia_curso_id = v_clase.instancia_curso_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'La alumna no está inscrita en el curso de esta clase.' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_actual FROM public.asistencia_alumnas
    WHERE clase_id = p_clase_id AND inscripcion_id = v_fila.inscripcion_id
    FOR UPDATE;
    v_aceptado := public.justificativo_aceptado(p_clase_id, v_fila.inscripcion_id);

    IF v_actual.id IS NULL THEN
      IF v_estado_insc <> 'activa' THEN
        v_omitidas := v_omitidas + 1;
      ELSIF v_aceptado THEN
        -- El trigger la deja justificada
        INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por, registrado_en, updated_at)
        VALUES (p_clase_id, v_fila.inscripcion_id, 'justificada', auth.uid(), now(), now());
        IF v_fila.estado = 'justificada' THEN
          v_guardados := v_guardados + 1;
        ELSE
          v_justificadas := v_justificadas + 1;
        END IF;
      ELSIF v_fila.estado = 'justificada' AND NOT v_gestion THEN
        v_justificadas := v_justificadas + 1;
      ELSE
        INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por, registrado_en, updated_at)
        VALUES (p_clase_id, v_fila.inscripcion_id, v_fila.estado, auth.uid(), now(), now());
        v_guardados := v_guardados + 1;
      END IF;
    ELSIF v_actual.estado = v_fila.estado THEN
      v_sin_cambios := v_sin_cambios + 1;
    ELSIF v_aceptado AND v_actual.estado = 'justificada' THEN
      v_justificadas := v_justificadas + 1;
    ELSIF v_actual.updated_at > v_momento THEN
      v_posteriores := v_posteriores + 1;
    ELSIF (v_actual.estado = 'justificada' OR v_fila.estado = 'justificada') AND NOT v_gestion AND NOT v_aceptado THEN
      v_justificadas := v_justificadas + 1;
    ELSE
      UPDATE public.asistencia_alumnas
      SET estado = CASE WHEN v_aceptado THEN 'justificada' ELSE v_fila.estado END
      WHERE id = v_actual.id;
      v_guardados := v_guardados + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'guardados', v_guardados,
    'sin_cambios', v_sin_cambios,
    'justificadas_conservadas', v_justificadas,
    'conservados_por_edicion_posterior', v_posteriores,
    'omitidas', v_omitidas
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. PASE DE LISTA CON EL ESTADO DEL JUSTIFICATIVO (US-38)
-- -----------------------------------------------------------------------------
-- Cambia las columnas de la migración 15: agrega el estado y el motivo del
-- justificativo de cada alumna (sin la explicación).
DROP FUNCTION public.lista_asistencia_clase(uuid);
CREATE FUNCTION public.lista_asistencia_clase(p_clase_id uuid)
RETURNS TABLE (
  inscripcion_id uuid,
  alumna_id uuid,
  nombres text,
  apellidos text,
  rut text,
  autoriza_imagen boolean,
  estado public.estado_asistencia,
  registrado_por_nombre text,
  actualizado_en timestamptz,
  ejercicios int,
  participo_activa boolean,
  podio_kahoot int,
  justificativo_estado public.estado_justificativo,
  justificativo_motivo public.motivo_justificativo
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT
    i.id,
    a.id,
    a.nombres::text,
    a.apellidos::text,
    a.rut::text,
    coalesce(au.autoriza_tratamiento_datos = 'otorgada' AND au.autoriza_uso_imagen_general = 'otorgada', false),
    aa.estado,
    nullif(btrim(concat_ws(' ', p.nombres, p.apellidos)), ''),
    aa.updated_at,
    pc.ejercicios_completados,
    pc.participo_activa,
    pc.podio_kahoot,
    j.estado,
    j.motivo
  FROM public.clases c
  JOIN public.inscripciones i ON i.instancia_curso_id = c.instancia_curso_id
  JOIN public.alumnas a ON a.id = i.alumna_id
  LEFT JOIN public.autorizaciones_apoderado au ON au.alumna_id = a.id
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = i.id
  LEFT JOIN public.perfiles p ON p.id = aa.registrado_por
  LEFT JOIN public.participacion_clase pc ON pc.clase_id = c.id AND pc.inscripcion_id = i.id
  LEFT JOIN LATERAL public.resumen_justificativo(c.id, i.id) j ON true
  WHERE c.id = p_clase_id AND (i.estado = 'activa' OR aa.id IS NOT NULL)
  ORDER BY a.apellidos, a.nombres;
$$;

-- -----------------------------------------------------------------------------
-- 5. RPC DE JUSTIFICATIVOS
-- -----------------------------------------------------------------------------
-- Clase y alumna admiten un justificativo: la clase no está suspendida, la
-- alumna no figura presente ni ya justificada, y no hay otro vigente.
CREATE OR REPLACE FUNCTION public.validar_justificable(p_clase public.clases, p_inscripcion uuid)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_asistencia public.estado_asistencia;
  v_vigente public.estado_justificativo;
BEGIN
  IF p_clase.estado = 'suspendida' THEN
    RAISE EXCEPTION 'La clase está suspendida: no hay inasistencia que justificar.' USING ERRCODE = '22023';
  END IF;

  SELECT estado INTO v_asistencia FROM public.asistencia_alumnas
  WHERE clase_id = p_clase.id AND inscripcion_id = p_inscripcion;
  IF v_asistencia = 'presente' THEN
    RAISE EXCEPTION 'La alumna figura presente en esa clase: no hay inasistencia que justificar.' USING ERRCODE = '22023';
  END IF;

  SELECT estado INTO v_vigente FROM public.justificativos_inasistencia
  WHERE clase_id = p_clase.id AND inscripcion_id = p_inscripcion AND estado IN ('pendiente', 'aceptado');
  IF v_vigente = 'pendiente' THEN
    RAISE EXCEPTION 'Ya hay un justificativo pendiente para esa clase.' USING ERRCODE = '23505';
  ELSIF v_vigente = 'aceptado' OR v_asistencia = 'justificada' THEN
    RAISE EXCEPTION 'La inasistencia de esa clase ya está justificada.' USING ERRCODE = '23505';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_explicacion_justificativo(p_explicacion text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $$
DECLARE
  v_texto text := nullif(btrim(p_explicacion), '');
BEGIN
  IF v_texto IS NULL THEN
    RAISE EXCEPTION 'Escribe la explicación de la inasistencia.' USING ERRCODE = '22023';
  END IF;
  IF char_length(v_texto) > 500 THEN
    RAISE EXCEPTION 'La explicación admite hasta 500 caracteres.' USING ERRCODE = '22023';
  END IF;
  RETURN v_texto;
END;
$$;

-- La alumna justifica una clase de su curso: queda pendiente para Gestión (US-35)
CREATE OR REPLACE FUNCTION public.enviar_justificativo(
  p_clase_id uuid,
  p_motivo public.motivo_justificativo,
  p_explicacion text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_alumna uuid := public.alumna_actual_id();
  v_clase public.clases;
  v_inscripcion uuid;
  v_fila public.justificativos_inasistencia;
BEGIN
  IF v_alumna IS NULL THEN
    RAISE EXCEPTION 'Solo la alumna envía su justificativo desde su portal.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_clase FROM public.clases WHERE id = p_clase_id;
  SELECT id INTO v_inscripcion FROM public.inscripciones
  WHERE alumna_id = v_alumna AND instancia_curso_id = v_clase.instancia_curso_id AND estado = 'activa';
  IF v_clase.id IS NULL OR v_inscripcion IS NULL THEN
    RAISE EXCEPTION 'Esa clase no es de un curso en el que estés inscrita.' USING ERRCODE = '42501';
  END IF;
  IF p_motivo IS NULL THEN
    RAISE EXCEPTION 'Elige el motivo de la inasistencia.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('justificativo:' || p_clase_id::text || ':' || v_inscripcion::text));
  PERFORM public.validar_justificable(v_clase, v_inscripcion);

  INSERT INTO public.justificativos_inasistencia (clase_id, inscripcion_id, motivo, explicacion, subido_por)
  VALUES (p_clase_id, v_inscripcion, p_motivo, public.validar_explicacion_justificativo(p_explicacion), auth.uid())
  RETURNING * INTO v_fila;
  RETURN to_jsonb(v_fila);
END;
$$;

-- Gestión de la sede registra el aviso de la apoderada: queda aceptado (US-16)
CREATE OR REPLACE FUNCTION public.registrar_justificativo(
  p_clase_id uuid,
  p_inscripcion_id uuid,
  p_motivo public.motivo_justificativo,
  p_explicacion text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_fila public.justificativos_inasistencia;
BEGIN
  SELECT * INTO v_clase FROM public.clases WHERE id = p_clase_id;
  IF v_clase.id IS NULL OR NOT public.gestiona_sede(public.sede_instancia(v_clase.instancia_curso_id)) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede registra justificativos.' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.inscripciones
    WHERE id = p_inscripcion_id AND instancia_curso_id = v_clase.instancia_curso_id AND estado = 'activa'
  ) THEN
    RAISE EXCEPTION 'La alumna no tiene matrícula activa en el curso de esta clase.' USING ERRCODE = '22023';
  END IF;
  IF p_motivo IS NULL THEN
    RAISE EXCEPTION 'Elige el motivo de la inasistencia.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('justificativo:' || p_clase_id::text || ':' || p_inscripcion_id::text));
  PERFORM public.validar_justificable(v_clase, p_inscripcion_id);

  INSERT INTO public.justificativos_inasistencia (
    clase_id, inscripcion_id, motivo, explicacion, estado, subido_por, resuelto_por, fecha_resolucion
  )
  VALUES (
    p_clase_id, p_inscripcion_id, p_motivo, public.validar_explicacion_justificativo(p_explicacion),
    'aceptado', auth.uid(), auth.uid(), timezone('utc'::text, now())
  )
  RETURNING * INTO v_fila;
  RETURN to_jsonb(v_fila);
END;
$$;

-- Gestión de la sede aprueba o rechaza un pendiente; el rechazo lleva observación (US-37)
CREATE OR REPLACE FUNCTION public.resolver_justificativo(p_id uuid, p_aprobar boolean, p_observacion text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_fila public.justificativos_inasistencia;
  v_observacion text := nullif(btrim(p_observacion), '');
BEGIN
  SELECT * INTO v_fila FROM public.justificativos_inasistencia WHERE id = p_id FOR UPDATE;
  IF v_fila.id IS NULL OR NOT public.gestiona_sede(public.sede_clase(v_fila.clase_id)) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede resuelve justificativos.' USING ERRCODE = '42501';
  END IF;
  IF v_fila.estado <> 'pendiente' THEN
    RAISE EXCEPTION 'El justificativo ya fue resuelto.' USING ERRCODE = '22023';
  END IF;
  IF p_aprobar IS NULL THEN
    RAISE EXCEPTION 'Indica si apruebas o rechazas el justificativo.' USING ERRCODE = '22023';
  END IF;
  IF NOT p_aprobar AND v_observacion IS NULL THEN
    RAISE EXCEPTION 'Indica el motivo del rechazo para que la alumna lo sepa.' USING ERRCODE = '22023';
  END IF;
  IF p_aprobar AND EXISTS (
    SELECT 1 FROM public.asistencia_alumnas
    WHERE clase_id = v_fila.clase_id AND inscripcion_id = v_fila.inscripcion_id AND estado = 'presente'
  ) THEN
    RAISE EXCEPTION 'La alumna figura presente en esa clase: rechaza el justificativo o corrige la asistencia.'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.justificativos_inasistencia
  SET estado = CASE WHEN p_aprobar THEN 'aceptado' ELSE 'rechazado' END::public.estado_justificativo,
      observacion_resolucion = v_observacion,
      resuelto_por = auth.uid(),
      fecha_resolucion = timezone('utc'::text, now())
  WHERE id = p_id
  RETURNING * INTO v_fila;
  RETURN to_jsonb(v_fila);
END;
$$;

-- Gestión de la sede elimina un justificativo vinculado por error; si estaba
-- aceptado, la asistencia vuelve a ausente (US-16 escenario 3).
CREATE OR REPLACE FUNCTION public.eliminar_justificativo(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_fila public.justificativos_inasistencia;
BEGIN
  SELECT * INTO v_fila FROM public.justificativos_inasistencia WHERE id = p_id FOR UPDATE;
  IF v_fila.id IS NULL OR NOT public.gestiona_sede(public.sede_clase(v_fila.clase_id)) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede elimina justificativos.' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.justificativos_inasistencia WHERE id = p_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. LECTURA DE JUSTIFICATIVOS
-- -----------------------------------------------------------------------------
-- Bandeja de Gestión y lista de la alumna. security_invoker: cada rol ve solo
-- lo que su RLS le permite (la alumna, los suyos).
CREATE VIEW public.justificativos_detalle WITH (security_invoker = true) AS
SELECT
  j.id,
  j.clase_id,
  j.inscripcion_id,
  i.alumna_id,
  a.nombres AS alumna_nombres,
  a.apellidos AS alumna_apellidos,
  a.rut AS alumna_rut,
  c.numero_sesion,
  c.fecha AS clase_fecha,
  pl.tema_titulo AS clase_tema,
  ic.id AS instancia_curso_id,
  ic.sede_id,
  s.nombre AS sede_nombre,
  cu.nombre AS curso_nombre,
  j.motivo,
  j.explicacion,
  j.estado,
  j.observacion_resolucion,
  j.fecha_resolucion,
  nullif(btrim(concat_ws(' ', r.nombres, r.apellidos)), '') AS resuelto_por_nombre,
  j.subido_por IS NOT DISTINCT FROM a.perfil_usuario_id AS enviado_por_alumna,
  j.created_at
FROM public.justificativos_inasistencia j
JOIN public.clases c ON c.id = j.clase_id
JOIN public.inscripciones i ON i.id = j.inscripcion_id
JOIN public.alumnas a ON a.id = i.alumna_id
JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
JOIN public.sedes s ON s.id = ic.sede_id
JOIN public.cursos cu ON cu.id = ic.curso_id
LEFT JOIN public.planificacion_clases pl ON pl.clase_id = c.id
LEFT JOIN public.perfiles r ON r.id = j.resuelto_por;

REVOKE ALL ON public.justificativos_detalle FROM anon, public;
GRANT SELECT ON public.justificativos_detalle TO authenticated;

-- Clases que la alumna autenticada puede justificar: las de sus cursos con
-- matrícula activa que no están suspendidas y donde no figura presente, con el
-- estado del justificativo vigente si lo hay (US-35 escenario 1).
CREATE OR REPLACE FUNCTION public.clases_para_justificar()
RETURNS TABLE (
  clase_id uuid,
  inscripcion_id uuid,
  numero_sesion int,
  fecha date,
  tema text,
  curso_nombre text,
  asistencia public.estado_asistencia,
  justificativo_estado public.estado_justificativo
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT c.id, i.id, c.numero_sesion, c.fecha, pl.tema_titulo::text, cu.nombre::text, aa.estado, j.estado
  FROM public.inscripciones i
  JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
  JOIN public.cursos cu ON cu.id = ic.curso_id
  JOIN public.clases c ON c.instancia_curso_id = i.instancia_curso_id
  LEFT JOIN public.planificacion_clases pl ON pl.clase_id = c.id AND pl.publicado_para_alumnas
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = i.id
  LEFT JOIN public.justificativos_inasistencia j
    ON j.clase_id = c.id AND j.inscripcion_id = i.id AND j.estado IN ('pendiente', 'aceptado')
  WHERE i.alumna_id = public.alumna_actual_id()
    AND i.estado = 'activa'
    AND c.estado <> 'suspendida'
    AND aa.estado IS DISTINCT FROM 'presente'
  ORDER BY c.fecha, c.numero_sesion;
$$;

-- -----------------------------------------------------------------------------
-- 7. EVIDENCIA FOTOGRÁFICA (US-18, US-19)
-- -----------------------------------------------------------------------------
-- Ruta: <clase_id>/<archivo>. Fotos comprimidas en el celular antes de subir.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('evidencias', 'evidencias', false, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- Uuid del segmento n de una ruta del bucket, o NULL si no es un uuid
CREATE OR REPLACE FUNCTION public.uuid_de_ruta(p_nombre text, p_segmento int DEFAULT 1)
RETURNS uuid
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $$
BEGIN
  RETURN split_part(p_nombre, '/', p_segmento)::uuid;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- Alumnas presentes en la clase sin autorización de imagen (tratamiento de
-- datos e imagen otorgados), en el orden del pase de lista
CREATE OR REPLACE FUNCTION public.presentes_sin_autorizacion_imagen(p_clase uuid)
RETURNS TABLE (inscripcion_id uuid, nombres text, apellidos text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT i.id, a.nombres::text, a.apellidos::text
  FROM public.asistencia_alumnas aa
  JOIN public.inscripciones i ON i.id = aa.inscripcion_id
  JOIN public.alumnas a ON a.id = i.alumna_id
  LEFT JOIN public.autorizaciones_apoderado au ON au.alumna_id = a.id
  WHERE aa.clase_id = p_clase
    AND aa.estado = 'presente'
    AND NOT coalesce(au.autoriza_tratamiento_datos = 'otorgada' AND au.autoriza_uso_imagen_general = 'otorgada', false)
    AND public.es_staff_sede(public.sede_clase(p_clase))
  ORDER BY a.apellidos, a.nombres;
$$;

CREATE OR REPLACE FUNCTION public.validar_evidencia()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_tamano bigint;
  v_sin_autorizacion boolean;
BEGIN
  -- Operaciones del sistema (seed, service role) no tienen auth.uid()
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.clase_id <> OLD.clase_id OR NEW.archivo_url <> OLD.archivo_url
    OR NEW.subida_por <> OLD.subida_por OR NEW.subida_en <> OLD.subida_en
    OR NEW.tamano_bytes IS DISTINCT FROM OLD.tamano_bytes
  ) THEN
    RAISE EXCEPTION 'La foto, su clase y su autoría no se modifican: sube una nueva.' USING ERRCODE = '22023';
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT * INTO v_clase FROM public.clases WHERE id = NEW.clase_id;
    IF v_clase.estado IS DISTINCT FROM 'realizada' THEN
      RAISE EXCEPTION 'La foto de evidencia se sube después de pasar lista en la clase.' USING ERRCODE = '22023';
    END IF;

    SELECT (o.metadata ->> 'size')::bigint INTO v_tamano
    FROM storage.objects o
    WHERE o.bucket_id = 'evidencias' AND o.name = NEW.archivo_url
      AND public.uuid_de_ruta(o.name, 1) = NEW.clase_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'No encontramos la foto subida: vuelve a subirla.' USING ERRCODE = '22023';
    END IF;

    -- Fecha, hora, tamaño y autora los pone el sistema (US-18 escenario 3)
    NEW.subida_por := auth.uid();
    NEW.subida_en := timezone('utc'::text, now());
    NEW.tamano_bytes := v_tamano;
  END IF;

  v_sin_autorizacion := EXISTS (SELECT 1 FROM public.presentes_sin_autorizacion_imagen(NEW.clase_id));
  NEW.declaracion_consentimiento_completo := NOT v_sin_autorizacion;

  -- US-19 escenario 2: apta solo si todas tienen autorización o se declara la censura
  IF NEW.apta_para_evidencia AND v_sin_autorizacion AND NOT NEW.rostros_censurados THEN
    RAISE EXCEPTION 'Para marcarla apta, confirma que las alumnas sin autorización no son reconocibles o sus rostros fueron cubiertos.'
      USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER evidencias_validar
  BEFORE INSERT OR UPDATE ON public.evidencias_fotograficas
  FOR EACH ROW EXECUTE FUNCTION public.validar_evidencia();

CREATE UNIQUE INDEX evidencias_archivo_unico ON public.evidencias_fotograficas (archivo_url);
CREATE INDEX evidencias_clase_idx ON public.evidencias_fotograficas (clase_id);

-- La foto se lee por su registro: staff de la sede o Comunicación si es apta
CREATE OR REPLACE FUNCTION public.accede_foto_evidencia(p_nombre text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.es_staff_sede(public.sede_clase(public.uuid_de_ruta(p_nombre, 1)))
    OR (
      public.current_user_role() = 'comunicacion'
      AND EXISTS (SELECT 1 FROM public.evidencias_fotograficas WHERE archivo_url = p_nombre AND apta_para_evidencia)
    );
$$;

CREATE OR REPLACE FUNCTION public.foto_sin_evidencia(p_nombre text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.evidencias_fotograficas WHERE archivo_url = p_nombre);
$$;

CREATE POLICY evidencias_foto_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'evidencias' AND public.accede_foto_evidencia(name));
CREATE POLICY evidencias_foto_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'evidencias' AND public.es_staff_sede(public.sede_clase(public.uuid_de_ruta(name, 1))));
-- Solo se borra una foto que no llegó a registrarse (RB-10: las registradas se conservan)
CREATE POLICY evidencias_foto_delete ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'evidencias' AND owner_id = auth.uid()::text AND public.foto_sin_evidencia(name)
    AND public.es_staff_sede(public.sede_clase(public.uuid_de_ruta(name, 1)))
  );

-- Las fotos registradas se conservan (RB-10): nadie borra el registro
DROP POLICY evidencias_delete ON public.evidencias_fotograficas;
REVOKE DELETE ON public.evidencias_fotograficas FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 8. CLASES CON EVIDENCIA PENDIENTE TRAS 48 HORAS (US-20)
-- -----------------------------------------------------------------------------
-- Clases realizadas sin foto cuyo término (hora de Chile) fue hace más de 48
-- horas. security_invoker: Gestión ve solo las de su sede.
CREATE VIEW public.evidencias_pendientes WITH (security_invoker = true) AS
SELECT
  c.id AS clase_id,
  c.instancia_curso_id,
  ic.sede_id,
  s.nombre AS sede_nombre,
  cu.nombre AS curso_nombre,
  ic.seccion,
  c.numero_sesion,
  c.fecha,
  pl.tema_titulo AS clase_tema,
  t.termino,
  floor(extract(epoch FROM now() - t.termino) / 3600)::int AS horas_sin_foto,
  (
    SELECT string_agg(nullif(btrim(concat_ws(' ', p.nombres, p.apellidos)), ''), ', ' ORDER BY p.nombres, p.apellidos)
    FROM public.tutores_instancia ti JOIN public.perfiles p ON p.id = ti.tutor_id
    WHERE ti.instancia_curso_id = c.instancia_curso_id
  ) AS tutoras
FROM public.clases c
JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
JOIN public.sedes s ON s.id = ic.sede_id
JOIN public.cursos cu ON cu.id = ic.curso_id
LEFT JOIN public.planificacion_clases pl ON pl.clase_id = c.id
CROSS JOIN LATERAL (
  SELECT (c.fecha + coalesce(c.hora_fin, time '23:59')) AT TIME ZONE 'America/Santiago' AS termino
) t
WHERE c.estado = 'realizada'
  AND t.termino < now() - interval '48 hours'
  AND NOT EXISTS (SELECT 1 FROM public.evidencias_fotograficas e WHERE e.clase_id = c.id);

REVOKE ALL ON public.evidencias_pendientes FROM anon, public;
GRANT SELECT ON public.evidencias_pendientes TO authenticated;

-- -----------------------------------------------------------------------------
-- 9. AUDITORÍA (US-37 escenario 4)
-- -----------------------------------------------------------------------------
CREATE TRIGGER justificativos_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.justificativos_inasistencia
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER evidencias_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.evidencias_fotograficas
  FOR EACH ROW EXECUTE FUNCTION public.auditar();

-- -----------------------------------------------------------------------------
-- 10. PERMISOS DE LAS FUNCIONES
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.justificativo_aceptado(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resumen_justificativo(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sincronizar_justificativo() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.justificativos_actualizado() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validar_justificable(public.clases, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validar_explicacion_justificativo(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validar_evidencia() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.uuid_de_ruta(text, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accede_foto_evidencia(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.foto_sin_evidencia(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lista_asistencia_clase(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.enviar_justificativo(uuid, public.motivo_justificativo, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_justificativo(uuid, uuid, public.motivo_justificativo, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.resolver_justificativo(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.eliminar_justificativo(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.clases_para_justificar() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.presentes_sin_autorizacion_imagen(uuid) FROM PUBLIC, anon;
-- Las políticas de Storage y lista_asistencia_clase se evalúan con el rol de la usuaria
GRANT EXECUTE ON FUNCTION public.resumen_justificativo(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.uuid_de_ruta(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accede_foto_evidencia(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.foto_sin_evidencia(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lista_asistencia_clase(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_justificativo(uuid, public.motivo_justificativo, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_justificativo(uuid, uuid, public.motivo_justificativo, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_justificativo(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_justificativo(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clases_para_justificar() TO authenticated;
GRANT EXECUTE ON FUNCTION public.presentes_sin_autorizacion_imagen(uuid) TO authenticated;
