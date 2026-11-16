-- =============================================================================
-- Migration: 20261101000015_reglas_clase.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Reglas de la clase en el aula: pase de lista de alumnas y de
--              tutoras, participación, podio Kahoot y guardado sin conexión
--              (US-13, US-14, US-15, US-28, US-29, US-31, US-33, US-34).
--
--   - Las escrituras se hacen solo con las RPC guardar_*: validan los permisos,
--     escriben toda la lista en una transacción y son idempotentes, así que la
--     app puede reenviar la misma lista tras un corte de conexión sin duplicar.
--   - Concurrencia: cada fila conserva la versión guardada más tarde, según el
--     momento en que se guardó en el dispositivo (p_guardado_en). Una lista que
--     llega tarde por falta de conexión no pisa una corrección posterior.
--   - La tutora solo alterna Presente y Ausente: la Justificada la gestiona el
--     Equipo de Gestión de la sede y la tutora no la cambia.
--   - El primer pase de lista marca la clase como realizada.
--   - La participación y el podio son solo de alumnas presentes. Si una alumna
--     pasa a ausente, sus registros de participación de esa clase se borran.
--   - Solo se asigna a un curso a una voluntaria con la adhesión firmada.
--   - (La salida del voluntariado posterior al ingreso ya la exige la
--     migración 04: voluntarios_detalle_fechas_validas.)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FECHA LOCAL Y CLASES QUE ADMITEN REGISTROS
-- -----------------------------------------------------------------------------
-- La base corre en UTC; las clases se programan en fechas de Chile
CREATE OR REPLACE FUNCTION public.hoy_chile()
RETURNS date
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT (now() AT TIME ZONE 'America/Santiago')::date;
$$;

-- Una clase admite registros si existe, no está suspendida ni cerrada y ya llegó su fecha
CREATE OR REPLACE FUNCTION public.validar_clase_registrable(p_clase public.clases)
RETURNS void
LANGUAGE plpgsql STABLE SET search_path = ''
AS $$
BEGIN
  IF p_clase.id IS NULL THEN
    RAISE EXCEPTION 'La clase no existe.' USING ERRCODE = '22023';
  END IF;
  IF p_clase.estado = 'suspendida' THEN
    RAISE EXCEPTION 'La clase está suspendida: no se registra asistencia ni participación.' USING ERRCODE = '22023';
  END IF;
  IF p_clase.cerrada_para_edicion THEN
    RAISE EXCEPTION 'La clase ya está cerrada para edición.' USING ERRCODE = '22023';
  END IF;
  IF p_clase.fecha > public.hoy_chile() THEN
    RAISE EXCEPTION 'La clase del % aún no se realiza.', to_char(p_clase.fecha, 'DD-MM-YYYY') USING ERRCODE = '22023';
  END IF;
END;
$$;

-- Clase que opera la usuaria: staff de la sede (Gestión o tutora) o la Directiva
CREATE OR REPLACE FUNCTION public.clase_operable(p_clase_id uuid)
RETURNS public.clases
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
BEGIN
  SELECT * INTO v_clase FROM public.clases WHERE id = p_clase_id;
  IF v_clase.id IS NULL OR NOT public.es_staff_sede(public.sede_instancia(v_clase.instancia_curso_id)) THEN
    RAISE EXCEPTION 'Solo las tutoras y el Equipo de Gestión de la sede registran la clase.' USING ERRCODE = '42501';
  END IF;
  PERFORM public.validar_clase_registrable(v_clase);
  RETURN v_clase;
END;
$$;

-- Momento de un guardado: el del dispositivo, nunca en el futuro
CREATE OR REPLACE FUNCTION public.momento_guardado(p_guardado_en timestamptz)
RETURNS timestamptz
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT least(coalesce(p_guardado_en, now()), now());
$$;

-- -----------------------------------------------------------------------------
-- 2. ASISTENCIA DE ALUMNAS (US-13, US-15)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_asistencia_alumna()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_insc public.inscripciones;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
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

  IF (NEW.estado = 'justificada' OR (TG_OP = 'UPDATE' AND OLD.estado = 'justificada' AND NEW.estado <> OLD.estado))
    AND NOT public.gestiona_sede(public.sede_instancia(v_clase.instancia_curso_id))
  THEN
    RAISE EXCEPTION 'Las inasistencias justificadas las gestiona el Equipo de Gestión.' USING ERRCODE = '42501';
  END IF;

  -- Autoría del último cambio; la versión anterior queda en la auditoría
  NEW.registrado_por := auth.uid();
  RETURN NEW;
END;
$$;

CREATE TRIGGER asistencia_alumnas_validar
  BEFORE INSERT OR UPDATE ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.validar_asistencia_alumna();

-- El primer pase de lista deja la clase realizada (US-13 escenario 4)
CREATE OR REPLACE FUNCTION public.marcar_clase_realizada()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.clases
  SET estado = 'realizada',
      fecha_realizacion = coalesce(fecha_realizacion, timezone('utc'::text, now())),
      registrada_por = coalesce(registrada_por, auth.uid())
  WHERE id = NEW.clase_id AND estado = 'programada';
  RETURN NULL;
END;
$$;

CREATE TRIGGER asistencia_alumnas_clase_realizada
  AFTER INSERT ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.marcar_clase_realizada();

-- Una alumna que deja de estar presente pierde su participación de esa clase (US-28 escenario 2)
CREATE OR REPLACE FUNCTION public.limpiar_participacion_no_presente()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' OR NEW.estado <> 'presente' THEN
    DELETE FROM public.participacion_clase
    WHERE clase_id = OLD.clase_id AND inscripcion_id = OLD.inscripcion_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER asistencia_alumnas_limpiar_participacion
  AFTER UPDATE OF estado OR DELETE ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.limpiar_participacion_no_presente();

-- -----------------------------------------------------------------------------
-- 3. PARTICIPACIÓN Y PODIO (US-28, US-29)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_participacion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
  END IF;
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.asistencia_alumnas
    WHERE clase_id = NEW.clase_id AND inscripcion_id = NEW.inscripcion_id AND estado = 'presente'
  ) THEN
    RAISE EXCEPTION 'Solo las alumnas presentes registran ejercicios, participación o podio.' USING ERRCODE = '22023';
  END IF;

  NEW.registrado_por := auth.uid();
  RETURN NEW;
END;
$$;

CREATE TRIGGER participacion_clase_validar
  BEFORE INSERT OR UPDATE ON public.participacion_clase
  FOR EACH ROW EXECUTE FUNCTION public.validar_participacion();

-- -----------------------------------------------------------------------------
-- 4. ASISTENCIA DE TUTORAS (US-33, US-34)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_asistencia_tutor()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
  END IF;
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_clase FROM public.clases WHERE id = NEW.clase_id;
  IF NOT EXISTS (
    SELECT 1 FROM public.tutores_instancia
    WHERE instancia_curso_id = v_clase.instancia_curso_id AND tutor_id = NEW.tutor_id
  ) THEN
    RAISE EXCEPTION 'La tutora no está asignada al curso de esta clase.' USING ERRCODE = '22023';
  END IF;
  PERFORM public.validar_clase_registrable(v_clase);

  NEW.registrado_por := auth.uid();
  RETURN NEW;
END;
$$;

CREATE TRIGGER asistencia_tutores_validar
  BEFORE INSERT OR UPDATE ON public.asistencia_tutores
  FOR EACH ROW EXECUTE FUNCTION public.validar_asistencia_tutor();

-- -----------------------------------------------------------------------------
-- 5. ASIGNACIÓN A CURSOS: ADHESIÓN FIRMADA Y VOLUNTARIA VIGENTE (US-31)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_adhesion_tutor()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  SELECT * INTO v_ficha FROM public.voluntarios_detalle WHERE perfil_id = NEW.tutor_id;
  IF v_ficha.id IS NULL OR NOT v_ficha.declaracion_adhesion_firmada THEN
    RAISE EXCEPTION 'Para asignarla a un curso, la voluntaria debe tener firmada la declaración de adhesión.'
      USING ERRCODE = '22023';
  END IF;
  IF v_ficha.fecha_salida IS NOT NULL AND v_ficha.fecha_salida < public.hoy_chile() THEN
    RAISE EXCEPTION 'La voluntaria ya no participa del voluntariado: no se asigna a cursos.' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tutores_instancia_adhesion
  BEFORE INSERT OR UPDATE OF tutor_id ON public.tutores_instancia
  FOR EACH ROW EXECUTE FUNCTION public.validar_adhesion_tutor();

-- -----------------------------------------------------------------------------
-- 6. RPC: GUARDAR EL PASE DE LISTA DE ALUMNAS (US-13, US-14, US-15)
-- -----------------------------------------------------------------------------
-- p_registros: [{inscripcion_id, estado}]. Por cada fila:
--   - sin cambios: se ignora (reenviar la misma lista no escribe nada);
--   - modificada después de p_guardado_en: se conserva la versión posterior;
--   - justificada (o pasar a justificada) y no es Gestión: se conserva;
--   - alumna sin registro que ya no está activa: se omite.
-- Devuelve cuántas filas se guardaron y cuántas se conservaron u omitieron.
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

    IF v_actual.id IS NULL THEN
      IF v_estado_insc <> 'activa' THEN
        v_omitidas := v_omitidas + 1;
      ELSIF v_fila.estado = 'justificada' AND NOT v_gestion THEN
        v_justificadas := v_justificadas + 1;
      ELSE
        INSERT INTO public.asistencia_alumnas (clase_id, inscripcion_id, estado, registrado_por, registrado_en, updated_at)
        VALUES (p_clase_id, v_fila.inscripcion_id, v_fila.estado, auth.uid(), now(), now());
        v_guardados := v_guardados + 1;
      END IF;
    ELSIF v_actual.estado = v_fila.estado THEN
      v_sin_cambios := v_sin_cambios + 1;
    ELSIF v_actual.updated_at > v_momento THEN
      v_posteriores := v_posteriores + 1;
    ELSIF (v_actual.estado = 'justificada' OR v_fila.estado = 'justificada') AND NOT v_gestion THEN
      v_justificadas := v_justificadas + 1;
    ELSE
      UPDATE public.asistencia_alumnas SET estado = v_fila.estado WHERE id = v_actual.id;
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
-- 7. RPC: GUARDAR EJERCICIOS Y PARTICIPACIÓN (US-28)
-- -----------------------------------------------------------------------------
-- p_registros: [{inscripcion_id, ejercicios, participo_activa}]. Las alumnas
-- que ya no están presentes se omiten (la asistencia pudo cambiar mientras
-- tanto). No toca el podio.
CREATE OR REPLACE FUNCTION public.guardar_participacion_clase(p_clase_id uuid, p_registros jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_fila record;
  v_guardados int := 0;
  v_omitidas int := 0;
BEGIN
  v_clase := public.clase_operable(p_clase_id);

  IF jsonb_typeof(p_registros) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'La lista de participación no es válida.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('participacion_clase:' || p_clase_id::text));

  FOR v_fila IN
    SELECT
      (e->>'inscripcion_id')::uuid AS inscripcion_id,
      coalesce((e->>'ejercicios')::int, 0) AS ejercicios,
      coalesce((e->>'participo_activa')::boolean, false) AS participo
    FROM jsonb_array_elements(p_registros) AS e
  LOOP
    IF v_fila.ejercicios < 0 THEN
      RAISE EXCEPTION 'Los ejercicios resueltos no pueden ser negativos.' USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.asistencia_alumnas
      WHERE clase_id = p_clase_id AND inscripcion_id = v_fila.inscripcion_id AND estado = 'presente'
    ) THEN
      v_omitidas := v_omitidas + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.participacion_clase (clase_id, inscripcion_id, ejercicios_completados, participo_activa, registrado_por)
    VALUES (p_clase_id, v_fila.inscripcion_id, v_fila.ejercicios, v_fila.participo, auth.uid())
    ON CONFLICT (clase_id, inscripcion_id) DO UPDATE
      SET ejercicios_completados = EXCLUDED.ejercicios_completados,
          participo_activa = EXCLUDED.participo_activa
      WHERE participacion_clase.ejercicios_completados IS DISTINCT FROM EXCLUDED.ejercicios_completados
         OR participacion_clase.participo_activa IS DISTINCT FROM EXCLUDED.participo_activa;
    IF FOUND THEN
      v_guardados := v_guardados + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('guardados', v_guardados, 'omitidas', v_omitidas);
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. RPC: GUARDAR EL PODIO KAHOOT (US-29)
-- -----------------------------------------------------------------------------
-- Tres alumnas presentes y distintas, en orden (1°, 2° y 3° lugar). Reemplaza
-- el podio anterior de la clase.
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
  v_podio uuid[] := ARRAY[p_primero, p_segundo, p_tercero];
BEGIN
  v_clase := public.clase_operable(p_clase_id);

  IF array_position(v_podio, NULL) IS NOT NULL
    OR (SELECT count(DISTINCT x) FROM unnest(v_podio) AS x) <> 3
  THEN
    RAISE EXCEPTION 'Elige tres alumnas distintas para el podio.' USING ERRCODE = '22023';
  END IF;

  IF (
    SELECT count(*) FROM public.asistencia_alumnas
    WHERE clase_id = p_clase_id AND inscripcion_id = ANY (v_podio) AND estado = 'presente'
  ) <> 3 THEN
    RAISE EXCEPTION 'El podio solo admite alumnas presentes en la clase.' USING ERRCODE = '22023';
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

-- -----------------------------------------------------------------------------
-- 9. RPC: GUARDAR EL PASE DE LISTA DE TUTORAS (US-33, US-34)
-- -----------------------------------------------------------------------------
-- p_registros: [{tutor_id, estado}] con las mismas reglas de concurrencia que
-- el pase de lista de alumnas.
CREATE OR REPLACE FUNCTION public.guardar_asistencia_tutores(
  p_clase_id uuid,
  p_registros jsonb,
  p_guardado_en timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_momento timestamptz := public.momento_guardado(p_guardado_en);
  v_fila record;
  v_actual public.asistencia_tutores;
  v_guardados int := 0;
  v_sin_cambios int := 0;
  v_posteriores int := 0;
BEGIN
  v_clase := public.clase_operable(p_clase_id);

  IF jsonb_typeof(p_registros) IS DISTINCT FROM 'array' OR jsonb_array_length(p_registros) = 0 THEN
    RAISE EXCEPTION 'La lista de tutoras está vacía.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('asistencia_tutores:' || p_clase_id::text));

  FOR v_fila IN
    SELECT (e->>'tutor_id')::uuid AS tutor_id, (e->>'estado')::public.estado_asistencia AS estado
    FROM jsonb_array_elements(p_registros) AS e
  LOOP
    IF v_fila.tutor_id IS NULL OR v_fila.estado IS NULL THEN
      RAISE EXCEPTION 'Cada registro necesita la tutora y el estado.' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_actual FROM public.asistencia_tutores
    WHERE clase_id = p_clase_id AND tutor_id = v_fila.tutor_id
    FOR UPDATE;

    IF v_actual.id IS NULL THEN
      INSERT INTO public.asistencia_tutores (clase_id, tutor_id, estado, registrado_por, registrado_en, updated_at)
      VALUES (p_clase_id, v_fila.tutor_id, v_fila.estado, auth.uid(), now(), now());
      v_guardados := v_guardados + 1;
    ELSIF v_actual.estado = v_fila.estado THEN
      v_sin_cambios := v_sin_cambios + 1;
    ELSIF v_actual.updated_at > v_momento THEN
      v_posteriores := v_posteriores + 1;
    ELSE
      UPDATE public.asistencia_tutores SET estado = v_fila.estado WHERE id = v_actual.id;
      v_guardados := v_guardados + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'guardados', v_guardados,
    'sin_cambios', v_sin_cambios,
    'conservados_por_edicion_posterior', v_posteriores
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 10. LECTURA DE LA CLASE (con los permisos de quien consulta: respeta la RLS)
-- -----------------------------------------------------------------------------
-- Alumnas de la clase: las activas del curso y las que ya tienen registro en
-- ella (ej. retiradas después), con su asistencia, participación y podio.
CREATE OR REPLACE FUNCTION public.lista_asistencia_clase(p_clase_id uuid)
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
  podio_kahoot int
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
    pc.podio_kahoot
  FROM public.clases c
  JOIN public.inscripciones i ON i.instancia_curso_id = c.instancia_curso_id
  JOIN public.alumnas a ON a.id = i.alumna_id
  LEFT JOIN public.autorizaciones_apoderado au ON au.alumna_id = a.id
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = i.id
  LEFT JOIN public.perfiles p ON p.id = aa.registrado_por
  LEFT JOIN public.participacion_clase pc ON pc.clase_id = c.id AND pc.inscripcion_id = i.id
  WHERE c.id = p_clase_id AND (i.estado = 'activa' OR aa.id IS NOT NULL)
  ORDER BY a.apellidos, a.nombres;
$$;

-- Tutoras asignadas al curso de la clase (y las que tienen registro en ella)
CREATE OR REPLACE FUNCTION public.lista_asistencia_tutores(p_clase_id uuid)
RETURNS TABLE (
  tutor_id uuid,
  nombres text,
  apellidos text,
  es_equipo_gestion boolean,
  estado public.estado_asistencia,
  registrado_por_nombre text,
  actualizado_en timestamptz
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH personas AS (
    SELECT ti.tutor_id
    FROM public.clases c JOIN public.tutores_instancia ti ON ti.instancia_curso_id = c.instancia_curso_id
    WHERE c.id = p_clase_id
    UNION
    SELECT at.tutor_id FROM public.asistencia_tutores at WHERE at.clase_id = p_clase_id
  )
  SELECT
    p.id,
    p.nombres::text,
    p.apellidos::text,
    p.rol = 'equipo_gestion',
    at.estado,
    nullif(btrim(concat_ws(' ', r.nombres, r.apellidos)), ''),
    at.updated_at
  FROM personas x
  JOIN public.perfiles p ON p.id = x.tutor_id
  LEFT JOIN public.asistencia_tutores at ON at.clase_id = p_clase_id AND at.tutor_id = p.id
  LEFT JOIN public.perfiles r ON r.id = at.registrado_por
  ORDER BY p.nombres, p.apellidos;
$$;

-- -----------------------------------------------------------------------------
-- 11. PERMISOS: las escrituras pasan por las RPC
-- -----------------------------------------------------------------------------
REVOKE INSERT, UPDATE ON public.asistencia_alumnas, public.participacion_clase, public.asistencia_tutores
  FROM anon, authenticated;

REVOKE ALL ON FUNCTION public.validar_clase_registrable(public.clases) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.clase_operable(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.momento_guardado(timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hoy_chile() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guardar_asistencia_clase(uuid, jsonb, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guardar_participacion_clase(uuid, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guardar_podio_kahoot(uuid, uuid, uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guardar_asistencia_tutores(uuid, jsonb, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lista_asistencia_clase(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lista_asistencia_tutores(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hoy_chile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_asistencia_clase(uuid, jsonb, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_participacion_clase(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_podio_kahoot(uuid, uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_asistencia_tutores(uuid, jsonb, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lista_asistencia_clase(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lista_asistencia_tutores(uuid) TO authenticated;
