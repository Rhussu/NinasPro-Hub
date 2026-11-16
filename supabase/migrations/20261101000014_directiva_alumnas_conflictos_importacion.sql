-- =============================================================================
-- Migration: 20261101000014_directiva_alumnas_conflictos_importacion.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: La gestión de las alumnas es solo de la Directiva, y los
--              conflictos de una carga masiva se resuelven en la misma carga o
--              quedan pendientes para después (US-04, US-07..US-12).
--
--   - Corrección de los requisitos: fichas, inscripciones, cargas, retiros,
--     autorizaciones, revocaciones y accesos de alumnas los gestiona la
--     Directiva. El Equipo de Gestión opera el semana a semana (clases y
--     coordinación con las tutoras) y ya no escribe datos de alumnas.
--   - importar_alumnas clasifica cada fila como nueva, existente, ya inscrita,
--     con conflicto (RUT repetido en el archivo, ficha existente con datos
--     distintos, correo en uso) o inválida (errores de datos). Cada fila puede
--     traer su resolución (actualizar o mantener la ficha, inscribir sin
--     correo, descartar). Al confirmar, lo que sigue sin resolver queda en
--     conflictos_importacion para resolverlo después.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ESCRITURAS SOBRE ALUMNAS: SOLO LA DIRECTIVA
-- -----------------------------------------------------------------------------
DROP POLICY alumnas_insert ON public.alumnas;
DROP POLICY alumnas_update ON public.alumnas;
CREATE POLICY alumnas_insert ON public.alumnas FOR INSERT TO authenticated
  WITH CHECK (public.is_directorio());
CREATE POLICY alumnas_update ON public.alumnas FOR UPDATE TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

DROP POLICY apoderados_insert ON public.apoderados;
DROP POLICY apoderados_update ON public.apoderados;
CREATE POLICY apoderados_insert ON public.apoderados FOR INSERT TO authenticated
  WITH CHECK (public.is_directorio());
CREATE POLICY apoderados_update ON public.apoderados FOR UPDATE TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

DROP POLICY inscripciones_write ON public.inscripciones;
CREATE POLICY inscripciones_write ON public.inscripciones FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

DROP POLICY autorizaciones_write ON public.autorizaciones_apoderado;
CREATE POLICY autorizaciones_write ON public.autorizaciones_apoderado FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

DROP POLICY autorizaciones_canales_write ON public.autorizaciones_imagen_canales;
CREATE POLICY autorizaciones_canales_write ON public.autorizaciones_imagen_canales FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

-- La nómina administrativa (consentimiento, asistencia, regularización) es de la Directiva
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
    count(*) FILTER (WHERE aa.estado IN ('presente', 'justificada'))::int AS clases_asistidas
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

-- Respaldos firmados: solo la Directiva los sube y los lee
DROP POLICY autorizaciones_respaldo_select ON storage.objects;
DROP POLICY autorizaciones_respaldo_insert ON storage.objects;
DROP POLICY autorizaciones_respaldo_update ON storage.objects;
DROP POLICY autorizaciones_respaldo_delete ON storage.objects;
CREATE POLICY autorizaciones_respaldo_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.is_directorio() AND public.alumna_de_ruta(name) IS NOT NULL);
CREATE POLICY autorizaciones_respaldo_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'autorizaciones' AND public.is_directorio()
    AND EXISTS (SELECT 1 FROM public.alumnas WHERE id = public.alumna_de_ruta(name))
  );
CREATE POLICY autorizaciones_respaldo_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.is_directorio())
  WITH CHECK (
    bucket_id = 'autorizaciones' AND public.is_directorio()
    AND EXISTS (SELECT 1 FROM public.alumnas WHERE id = public.alumna_de_ruta(name))
  );
CREATE POLICY autorizaciones_respaldo_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.is_directorio());

-- -----------------------------------------------------------------------------
-- 2. ACCESOS DE ALUMNAS: SOLO LA DIRECTIVA (US-04)
-- -----------------------------------------------------------------------------
DROP POLICY correos_autorizados_select ON public.correos_autorizados;
DROP POLICY correos_autorizados_delete ON public.correos_autorizados;
CREATE POLICY correos_autorizados_select ON public.correos_autorizados FOR SELECT TO authenticated
  USING (public.is_directorio());
CREATE POLICY correos_autorizados_delete ON public.correos_autorizados FOR DELETE TO authenticated
  USING (usado_en IS NULL AND public.is_directorio());

-- Igual que en la migración 09, sin el permiso de Gestión para alumnas de su sede:
-- cualquier intento que no sea de la Directiva se audita y responde 403.
CREATE OR REPLACE FUNCTION public.autorizar_correo(
  p_correo text,
  p_rol public.rol_usuario,
  p_sede_id uuid DEFAULT NULL,
  p_alumna_id uuid DEFAULT NULL,
  p_rut text DEFAULT NULL,
  p_nombres text DEFAULT NULL,
  p_apellidos text DEFAULT NULL,
  p_es_lider_sede boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_actor public.rol_usuario := public.current_user_role();
  v_correo text := lower(btrim(coalesce(p_correo, '')));
  v_alumna public.alumnas;
  v_fila public.correos_autorizados;
BEGIN
  IF v_actor IS DISTINCT FROM 'directorio' THEN
    PERFORM public.registrar_evento_seguridad(
      'autorizacion_denegada',
      auth.uid(),
      v_correo,
      jsonb_build_object(
        'rol_actor', v_actor,
        'rol_solicitado', p_rol,
        'sede_id', p_sede_id,
        'alumna_id', p_alumna_id
      )
    );
    PERFORM set_config('response.status', '403', true);
    RETURN jsonb_build_object(
      'code', '42501',
      'message', 'No tienes permiso para autorizar este acceso. El intento quedó registrado.'
    );
  END IF;

  IF v_correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'Revisa el formato del correo.';
  END IF;

  IF p_rol = 'alumna' THEN
    IF p_alumna_id IS NULL OR p_sede_id IS NULL THEN
      RAISE EXCEPTION 'Elige la alumna y su sede.';
    END IF;
    SELECT * INTO v_alumna FROM public.alumnas WHERE id = p_alumna_id;
    IF v_alumna.id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.inscripciones i
      JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
      WHERE i.alumna_id = p_alumna_id AND ic.sede_id = p_sede_id
    ) THEN
      RAISE EXCEPTION 'La alumna no está inscrita en esa sede.';
    END IF;
    IF v_alumna.perfil_usuario_id IS NOT NULL THEN
      RAISE EXCEPTION 'La alumna ya tiene una cuenta.';
    END IF;
  ELSE
    IF v_correo NOT LIKE '%@ninaspro.cl' THEN
      RAISE EXCEPTION 'El voluntariado usa su correo institucional @ninaspro.cl.';
    END IF;
    IF nullif(btrim(p_rut), '') IS NULL OR nullif(btrim(p_nombres), '') IS NULL OR nullif(btrim(p_apellidos), '') IS NULL THEN
      RAISE EXCEPTION 'Completa el RUT, los nombres y los apellidos.';
    END IF;
    IF p_rol <> 'directorio' AND p_sede_id IS NULL THEN
      RAISE EXCEPTION 'Elige la sede.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.perfiles WHERE rut = btrim(p_rut)) THEN
      RAISE EXCEPTION 'Ya existe una cuenta con el RUT %.', btrim(p_rut);
    END IF;
  END IF;

  IF p_es_lider_sede AND p_rol <> 'equipo_gestion' THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión puede liderar una sede.';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_correo) THEN
    RAISE EXCEPTION 'Ya existe una cuenta con el correo %.', v_correo;
  END IF;

  DELETE FROM public.correos_autorizados
  WHERE correo = v_correo AND usado_en IS NULL AND expira_en <= timezone('utc'::text, now());
  IF EXISTS (SELECT 1 FROM public.correos_autorizados WHERE correo = v_correo AND usado_en IS NULL) THEN
    RAISE EXCEPTION 'El correo % ya tiene una autorización pendiente.', v_correo;
  END IF;

  INSERT INTO public.correos_autorizados
    (correo, rol, sede_id, alumna_id, rut, nombres, apellidos, es_lider_sede, autorizado_por)
  VALUES (
    v_correo,
    p_rol,
    CASE WHEN p_rol = 'directorio' THEN NULL ELSE p_sede_id END,
    CASE WHEN p_rol = 'alumna' THEN p_alumna_id END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_rut) END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_nombres) END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_apellidos) END,
    coalesce(p_es_lider_sede, false),
    auth.uid()
  )
  RETURNING * INTO v_fila;

  RETURN to_jsonb(v_fila);
END;
$$;

CREATE OR REPLACE FUNCTION public.alumnas_para_autorizar()
RETURNS TABLE (
  id uuid,
  rut varchar,
  nombres varchar,
  apellidos varchar,
  correo varchar,
  sede_id uuid,
  sede_nombre varchar
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT DISTINCT ON (a.id) a.id, a.rut, a.nombres, a.apellidos, a.correo, s.id, s.nombre
  FROM public.alumnas a
  JOIN public.inscripciones i ON i.alumna_id = a.id
  JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
  JOIN public.sedes s ON s.id = ic.sede_id
  WHERE a.perfil_usuario_id IS NULL
    AND public.is_directorio()
    AND NOT EXISTS (
      SELECT 1 FROM public.correos_autorizados ca
      WHERE ca.alumna_id = a.id AND ca.usado_en IS NULL AND ca.expira_en > timezone('utc'::text, now())
    )
  ORDER BY a.id, i.fecha_inscripcion DESC;
$$;

-- -----------------------------------------------------------------------------
-- 3. RETIRO, AUTORIZACIONES Y REVOCACIÓN: SOLO LA DIRECTIVA
-- -----------------------------------------------------------------------------
-- Las RPC de la migración 13 permitían a Gestión de la sede. Ahora cada RPC
-- llama primero a exigir_directiva(), que responde 403 a cualquier otro rol.
CREATE OR REPLACE FUNCTION public.exigir_directiva(p_accion text)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_directorio() THEN
    RAISE EXCEPTION 'Solo la Directiva %.', p_accion USING ERRCODE = '42501';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.retirar_inscripcion(p_inscripcion_id uuid, p_fecha date, p_motivo text)
RETURNS public.inscripciones
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_insc public.inscripciones;
BEGIN
  PERFORM public.exigir_directiva('registra retiros');
  SELECT * INTO v_insc FROM public.inscripciones WHERE id = p_inscripcion_id;
  IF v_insc.id IS NULL THEN
    RAISE EXCEPTION 'La inscripción no existe.' USING ERRCODE = '22023';
  END IF;
  IF v_insc.estado NOT IN ('activa', 'preinscrita') THEN
    RAISE EXCEPTION 'La inscripción ya está %.', v_insc.estado USING ERRCODE = '22023';
  END IF;
  IF nullif(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Indica el motivo formal del retiro.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha IS NULL OR p_fecha > current_date THEN
    RAISE EXCEPTION 'La fecha de retiro no puede ser futura.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha < v_insc.fecha_inscripcion THEN
    RAISE EXCEPTION 'La fecha de retiro no puede ser anterior a la inscripción (%).', to_char(v_insc.fecha_inscripcion, 'DD-MM-YYYY')
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.inscripciones
  SET estado = 'retirada', fecha_retiro = p_fecha, motivo_retiro = btrim(p_motivo)
  WHERE id = p_inscripcion_id
  RETURNING * INTO v_insc;
  RETURN v_insc;
END;
$$;

-- Las de la migración 13 se renombran y quedan internas; las públicas exigen la Directiva
ALTER FUNCTION public.registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date)
  RENAME TO _registrar_autorizaciones;
ALTER FUNCTION public.revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text)
  RENAME TO _revocar_autorizacion_imagen;
REVOKE ALL ON FUNCTION public._registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.registrar_autorizaciones(
  p_alumna_id uuid,
  p_tratamiento_datos public.estado_autorizacion,
  p_canales jsonb DEFAULT '{}'::jsonb,
  p_documento text DEFAULT NULL,
  p_fecha_firma date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.exigir_directiva('registra autorizaciones');
  RETURN public._registrar_autorizaciones(p_alumna_id, p_tratamiento_datos, p_canales, p_documento, p_fecha_firma);
END;
$$;

CREATE OR REPLACE FUNCTION public.revocar_autorizacion_imagen(
  p_alumna_id uuid,
  p_canales public.tipo_canal_imagen[],
  p_fecha date,
  p_motivo text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.exigir_directiva('revoca autorizaciones');
  RETURN public._revocar_autorizacion_imagen(p_alumna_id, p_canales, p_fecha, p_motivo);
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. CONFLICTOS DE IMPORTACIÓN PENDIENTES
-- -----------------------------------------------------------------------------
CREATE TABLE public.conflictos_importacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instancia_curso_id UUID NOT NULL REFERENCES public.instancias_curso(id) ON DELETE CASCADE,
  archivo TEXT,
  numero_fila INTEGER NOT NULL,
  -- Datos de la fila con las correcciones hechas en la vista previa
  fila JSONB NOT NULL,
  motivo TEXT NOT NULL,
  creado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL DEFAULT auth.uid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.conflictos_importacion ENABLE ROW LEVEL SECURITY;

-- Solo la RPC los crea o reemplaza; la Directiva los ve y descarta
CREATE POLICY conflictos_importacion_select ON public.conflictos_importacion FOR SELECT TO authenticated
  USING (public.is_directorio());
CREATE POLICY conflictos_importacion_delete ON public.conflictos_importacion FOR DELETE TO authenticated
  USING (public.is_directorio());
REVOKE INSERT, UPDATE ON public.conflictos_importacion FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPC: CARGA CON CONFLICTOS Y RESOLUCIONES (US-07, US-08, US-09)
-- -----------------------------------------------------------------------------
-- Cada fila puede traer:
--   'resolucion': 'actualizar_ficha' | 'mantener_ficha' | 'sin_correo' | 'descartar'
--   'conflicto_id': el pendiente que esta fila resuelve (se reemplaza o se borra)
-- Estados de respuesta: nueva, existente, inscrita (ya estaba en el curso),
-- conflicto, invalida, descartada y, al confirmar, pendiente (guardada en
-- conflictos_importacion). Las válidas se inscriben todas o ninguna.
DROP FUNCTION public.importar_alumnas(uuid, jsonb, boolean);

-- Texto comparable: sin espacios extra ni mayúsculas
CREATE OR REPLACE FUNCTION public.texto_comparable(p_texto text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$
  SELECT lower(btrim(regexp_replace(coalesce(p_texto, ''), '\s+', ' ', 'g')));
$$;

CREATE OR REPLACE FUNCTION public.importar_alumnas(
  p_instancia_id uuid,
  p_filas jsonb,
  p_solo_validar boolean DEFAULT false,
  p_archivo text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_instancia public.instancias_curso;
  v_resultado jsonb := '[]'::jsonb;
  v_fila jsonb;
  v_datos jsonb;
  v_num int;
  v_res text;
  v_conflicto_id uuid;
  v_errores text[];
  v_conflictos text[];
  v_tipos text[];
  v_diferencias jsonb;
  v_estado text;
  v_motivo text;
  v_rut text;
  v_rut_apod text;
  v_nombres text;
  v_apellidos text;
  v_fecha_txt text;
  v_fecha_nac date;
  v_correo text;
  v_establecimiento text;
  v_curso_escolar text;
  v_nombres_apod text;
  v_apellidos_apod text;
  v_telefono text;
  v_correo_apod text;
  v_parentesco text;
  v_alumna public.alumnas;
  v_apod public.apoderados;
  v_apoderado_id uuid;
  v_repetidas text;
  v_filas_por_rut jsonb;
  v_inscritas int := 0;
  v_pendientes int := 0;
  v_archivo_previo text;
  v_correo_re constant text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
BEGIN
  PERFORM public.exigir_directiva('inscribe alumnas');
  SELECT * INTO v_instancia FROM public.instancias_curso WHERE id = p_instancia_id;
  IF v_instancia.id IS NULL THEN
    RAISE EXCEPTION 'La instancia de curso no existe.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) = 0 THEN
    RAISE EXCEPTION 'La planilla no tiene filas.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_filas) > 1000 THEN
    RAISE EXCEPTION 'La planilla tiene más de 1.000 filas: divídela en varias cargas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('importar_alumnas' || p_instancia_id::text));

  -- Filas en que aparece cada RUT (las descartadas no cuentan)
  SELECT coalesce(jsonb_object_agg(clave, filas), '{}'::jsonb) INTO v_filas_por_rut
  FROM (
    SELECT public.normalizar_rut(f->>'rut') AS clave,
           string_agg(coalesce(nullif(f->>'fila', ''), '0'), ', ' ORDER BY ord) AS filas
    FROM jsonb_array_elements(p_filas) WITH ORDINALITY AS t(f, ord)
    WHERE public.normalizar_rut(f->>'rut') <> '' AND f->>'resolucion' IS DISTINCT FROM 'descartar'
    GROUP BY 1
  ) r;

  FOR v_fila IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
    v_num := coalesce(nullif(v_fila->>'fila', '')::int, 0);
    v_res := nullif(v_fila->>'resolucion', '');
    v_conflicto_id := nullif(v_fila->>'conflicto_id', '')::uuid;
    v_datos := v_fila - 'resolucion' - 'conflicto_id';
    v_errores := '{}';
    v_conflictos := '{}';
    v_tipos := '{}';
    v_diferencias := '[]'::jsonb;
    v_repetidas := NULL;
    v_archivo_previo := NULL;

    IF v_res IS NOT NULL AND v_res NOT IN ('actualizar_ficha', 'mantener_ficha', 'sin_correo', 'descartar') THEN
      RAISE EXCEPTION 'Resolución desconocida en la fila %: %.', v_num, v_res USING ERRCODE = '22023';
    END IF;
    IF v_conflicto_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.conflictos_importacion WHERE id = v_conflicto_id AND instancia_curso_id = p_instancia_id
    ) THEN
      RAISE EXCEPTION 'El conflicto de la fila % ya no existe o es de otro curso.', v_num USING ERRCODE = '22023';
    END IF;

    v_rut := nullif(btrim(v_datos->>'rut'), '');
    v_rut_apod := nullif(btrim(v_datos->>'rut_apoderado'), '');
    v_nombres := nullif(btrim(regexp_replace(v_datos->>'nombres', '\s+', ' ', 'g')), '');
    v_apellidos := nullif(btrim(regexp_replace(v_datos->>'apellidos', '\s+', ' ', 'g')), '');
    v_fecha_txt := btrim(v_datos->>'fecha_nacimiento');
    v_fecha_nac := public.fecha_o_null(v_fecha_txt);
    v_correo := CASE WHEN v_res = 'sin_correo' THEN NULL ELSE nullif(lower(btrim(v_datos->>'correo')), '') END;
    v_establecimiento := nullif(btrim(v_datos->>'establecimiento'), '');
    v_curso_escolar := nullif(btrim(v_datos->>'curso_escolar'), '');
    v_nombres_apod := nullif(btrim(regexp_replace(v_datos->>'nombres_apoderado', '\s+', ' ', 'g')), '');
    v_apellidos_apod := nullif(btrim(regexp_replace(v_datos->>'apellidos_apoderado', '\s+', ' ', 'g')), '');
    v_telefono := nullif(btrim(v_datos->>'telefono_apoderado'), '');
    v_correo_apod := nullif(lower(btrim(v_datos->>'correo_apoderado')), '');
    v_parentesco := nullif(btrim(v_datos->>'parentesco'), '');
    v_alumna := NULL;
    v_apod := NULL;

    IF v_rut IS NOT NULL AND public.rut_valido(v_rut) THEN
      SELECT * INTO v_alumna FROM public.alumnas WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_rut);
      SELECT * INTO v_apod FROM public.apoderados WHERE id = v_alumna.apoderado_id;
    END IF;

    -- Errores de datos (se corrigen en la fila)
    IF v_rut IS NULL THEN
      v_errores := array_append(v_errores, 'Falta el RUT de la alumna');
    ELSIF NOT public.rut_valido(v_rut) THEN
      v_errores := array_append(v_errores, 'RUT de la alumna inválido (dígito verificador)');
    END IF;
    IF v_nombres IS NULL OR v_apellidos IS NULL THEN
      v_errores := array_append(v_errores, 'Faltan los nombres o apellidos de la alumna');
    ELSIF length(v_nombres) > 100 OR length(v_apellidos) > 100 THEN
      v_errores := array_append(v_errores, 'Nombres o apellidos de más de 100 caracteres');
    END IF;
    IF v_fecha_nac IS NULL THEN
      v_errores := array_append(v_errores, 'Fecha de nacimiento ausente o no válida');
    ELSIF v_fecha_nac >= current_date OR v_fecha_nac < current_date - interval '30 years' THEN
      v_errores := array_append(v_errores, 'Fecha de nacimiento fuera de rango');
    END IF;
    IF v_correo IS NOT NULL AND (v_correo !~ v_correo_re OR length(v_correo) > 150) THEN
      v_errores := array_append(v_errores, 'Correo de la alumna no válido');
    END IF;
    IF length(v_establecimiento) > 150 OR length(v_curso_escolar) > 50 OR length(v_parentesco) > 50 THEN
      v_errores := array_append(v_errores, 'Establecimiento, curso escolar o parentesco demasiado largos');
    END IF;
    IF v_rut_apod IS NOT NULL AND NOT public.rut_valido(v_rut_apod) THEN
      v_errores := array_append(v_errores, 'RUT del apoderado/a inválido (dígito verificador)');
    END IF;
    IF v_nombres_apod IS NULL OR v_apellidos_apod IS NULL THEN
      v_errores := array_append(v_errores, 'Faltan los nombres o apellidos del apoderado/a');
    ELSIF length(v_nombres_apod) > 100 OR length(v_apellidos_apod) > 100 THEN
      v_errores := array_append(v_errores, 'Nombre del apoderado/a de más de 100 caracteres');
    END IF;
    IF v_telefono IS NULL OR v_correo_apod IS NULL THEN
      v_errores := array_append(v_errores, 'El correo y el teléfono del apoderado/a son obligatorios por protocolo institucional');
    ELSE
      IF length(regexp_replace(v_telefono, '\D', '', 'g')) NOT BETWEEN 8 AND 15 OR length(v_telefono) > 20 THEN
        v_errores := array_append(v_errores, 'Teléfono del apoderado/a no válido');
      END IF;
      IF v_correo_apod !~ v_correo_re OR length(v_correo_apod) > 150 THEN
        v_errores := array_append(v_errores, 'Correo del apoderado/a no válido');
      END IF;
    END IF;

    -- Conflictos (se resuelven eligiendo qué hacer)
    IF v_rut IS NOT NULL AND v_res IS DISTINCT FROM 'descartar' THEN
      v_repetidas := v_filas_por_rut->>public.normalizar_rut(v_rut);
      IF v_repetidas LIKE '%,%' THEN
        v_tipos := array_append(v_tipos, 'rut_repetido');
        v_conflictos := array_append(v_conflictos, 'RUT repetido en la planilla (filas ' || v_repetidas || '): elige qué fila vale');
      END IF;
    END IF;

    IF v_correo IS NOT NULL AND v_correo ~ v_correo_re AND (
      EXISTS (SELECT 1 FROM public.alumnas WHERE correo = v_correo AND id IS DISTINCT FROM v_alumna.id)
      OR EXISTS (
        SELECT 1 FROM auth.users u
        WHERE lower(u.email) = v_correo AND u.id IS DISTINCT FROM v_alumna.perfil_usuario_id
      )
    ) THEN
      v_tipos := array_append(v_tipos, 'correo_en_uso');
      v_conflictos := array_append(v_conflictos, 'El correo de la alumna ya lo usa otra persona');
    END IF;

    -- Ficha existente con datos distintos a los de la planilla
    IF v_alumna.id IS NOT NULL AND v_res IS DISTINCT FROM 'mantener_ficha' AND v_res IS DISTINCT FROM 'actualizar_ficha' THEN
      SELECT coalesce(jsonb_agg(jsonb_build_object('campo', d.campo, 'ficha', d.ficha, 'planilla', d.planilla) ORDER BY d.orden), '[]'::jsonb)
      INTO v_diferencias
      FROM (VALUES
        (1, 'Nombres', v_alumna.nombres::text, v_nombres),
        (2, 'Apellidos', v_alumna.apellidos::text, v_apellidos),
        (3, 'Fecha de nacimiento', to_char(v_alumna.fecha_nacimiento, 'DD-MM-YYYY'), to_char(v_fecha_nac, 'DD-MM-YYYY')),
        (4, 'Establecimiento', v_alumna.establecimiento_educacional::text, v_establecimiento),
        (5, 'Curso escolar', v_alumna.curso_escolar::text, v_curso_escolar),
        (6, 'Correo de la alumna', v_alumna.correo::text, v_correo),
        (7, 'Nombre del apoderado/a', btrim(v_apod.nombres || ' ' || v_apod.apellidos), btrim(coalesce(v_nombres_apod, '') || ' ' || coalesce(v_apellidos_apod, ''))),
        (8, 'Teléfono del apoderado/a', v_apod.telefono::text, v_telefono),
        (9, 'Correo del apoderado/a', v_apod.correo::text, v_correo_apod)
      ) AS d(orden, campo, ficha, planilla)
      -- Un dato vacío en la ficha o en la planilla no es un conflicto (se completa o se conserva)
      WHERE nullif(d.ficha, '') IS NOT NULL AND nullif(d.planilla, '') IS NOT NULL
        AND CASE WHEN d.orden = 8
          THEN regexp_replace(d.ficha, '\D', '', 'g') <> regexp_replace(d.planilla, '\D', '', 'g')
          ELSE public.texto_comparable(d.ficha) <> public.texto_comparable(d.planilla)
        END;
      IF jsonb_array_length(v_diferencias) > 0 THEN
        v_tipos := array_append(v_tipos, 'ficha_distinta');
        v_conflictos := array_append(v_conflictos, 'El RUT ya tiene ficha con datos distintos: mantén la ficha o actualízala');
      END IF;
    END IF;

    IF v_res = 'descartar' THEN
      v_estado := 'descartada';
    ELSIF v_alumna.id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.inscripciones WHERE alumna_id = v_alumna.id AND instancia_curso_id = p_instancia_id
    ) THEN
      v_estado := 'inscrita';
      v_errores := '{}';
      v_conflictos := ARRAY['Ya está inscrita en este curso'];
      v_tipos := '{}';
    ELSIF cardinality(v_errores) > 0 THEN
      v_estado := 'invalida';
    ELSIF cardinality(v_conflictos) > 0 THEN
      v_estado := 'conflicto';
    ELSIF v_alumna.id IS NOT NULL THEN
      v_estado := 'existente';
    ELSE
      v_estado := 'nueva';
    END IF;
    v_motivo := nullif(array_to_string(v_errores || v_conflictos, '. '), '');

    IF NOT coalesce(p_solo_validar, false) THEN
      -- El pendiente que esta fila resolvía se reemplaza por el resultado nuevo
      IF v_conflicto_id IS NOT NULL THEN
        DELETE FROM public.conflictos_importacion WHERE id = v_conflicto_id
        RETURNING archivo INTO v_archivo_previo;
      END IF;

      IF v_estado IN ('invalida', 'conflicto') THEN
        INSERT INTO public.conflictos_importacion (instancia_curso_id, archivo, numero_fila, fila, motivo)
        VALUES (
          p_instancia_id,
          coalesce(nullif(btrim(p_archivo), ''), v_archivo_previo),
          v_num,
          v_datos,
          v_motivo
        );
        v_estado := 'pendiente';
        v_pendientes := v_pendientes + 1;
      ELSIF v_estado IN ('nueva', 'existente') THEN
        IF v_alumna.id IS NULL THEN
          IF v_rut_apod IS NOT NULL THEN
            SELECT id INTO v_apoderado_id FROM public.apoderados
            WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_rut_apod);
          ELSE
            v_apoderado_id := NULL;
          END IF;
          IF v_apoderado_id IS NULL THEN
            INSERT INTO public.apoderados (rut, nombres, apellidos, correo, telefono, parentesco)
            VALUES (
              CASE WHEN v_rut_apod IS NULL THEN NULL ELSE public.formatear_rut(v_rut_apod) END,
              v_nombres_apod, v_apellidos_apod, v_correo_apod, v_telefono, coalesce(v_parentesco, 'Apoderado/a')
            )
            RETURNING id INTO v_apoderado_id;
          END IF;

          INSERT INTO public.alumnas (
            rut, nombres, apellidos, fecha_nacimiento, establecimiento_educacional, curso_escolar, correo, apoderado_id
          )
          VALUES (
            public.formatear_rut(v_rut), v_nombres, v_apellidos, v_fecha_nac, v_establecimiento, v_curso_escolar,
            v_correo, v_apoderado_id
          )
          RETURNING * INTO v_alumna;
        ELSE
          -- Actualizar la ficha con la planilla, o solo completar los datos que faltan
          UPDATE public.alumnas SET
            nombres = CASE WHEN v_res = 'actualizar_ficha' THEN v_nombres ELSE nombres END,
            apellidos = CASE WHEN v_res = 'actualizar_ficha' THEN v_apellidos ELSE apellidos END,
            fecha_nacimiento = CASE WHEN v_res = 'actualizar_ficha' THEN v_fecha_nac ELSE fecha_nacimiento END,
            establecimiento_educacional = CASE
              WHEN v_res = 'actualizar_ficha' THEN coalesce(v_establecimiento, establecimiento_educacional)
              ELSE coalesce(establecimiento_educacional, v_establecimiento) END,
            curso_escolar = CASE
              WHEN v_res = 'actualizar_ficha' THEN coalesce(v_curso_escolar, curso_escolar)
              ELSE coalesce(curso_escolar, v_curso_escolar) END,
            correo = CASE
              WHEN v_res = 'actualizar_ficha' THEN coalesce(v_correo, correo)
              ELSE coalesce(correo, v_correo) END,
            updated_at = timezone('utc'::text, now())
          WHERE id = v_alumna.id
          RETURNING * INTO v_alumna;

          IF v_res = 'actualizar_ficha' THEN
            UPDATE public.apoderados SET
              nombres = v_nombres_apod,
              apellidos = v_apellidos_apod,
              telefono = v_telefono,
              correo = v_correo_apod,
              parentesco = coalesce(v_parentesco, parentesco),
              rut = coalesce(rut, CASE WHEN v_rut_apod IS NULL THEN NULL ELSE public.formatear_rut(v_rut_apod) END),
              updated_at = timezone('utc'::text, now())
            WHERE id = v_alumna.apoderado_id;
          END IF;
        END IF;

        INSERT INTO public.inscripciones (alumna_id, instancia_curso_id, estado)
        VALUES (v_alumna.id, p_instancia_id, 'preinscrita');
        v_inscritas := v_inscritas + 1;

        IF v_alumna.correo IS NOT NULL
          AND v_alumna.perfil_usuario_id IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.correos_autorizados
            WHERE (correo = v_alumna.correo OR alumna_id = v_alumna.id) AND usado_en IS NULL
          )
          AND NOT EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_alumna.correo)
        THEN
          INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por)
          VALUES (v_alumna.correo, 'alumna', v_instancia.sede_id, v_alumna.id, auth.uid());
        END IF;
      END IF;
    END IF;

    v_resultado := v_resultado || jsonb_build_object(
      'fila', v_num,
      'datos', v_datos,
      'rut', CASE WHEN v_rut IS NOT NULL AND public.rut_valido(v_rut) THEN public.formatear_rut(v_rut) ELSE coalesce(v_rut, '') END,
      'nombre', btrim(coalesce(v_nombres, '') || ' ' || coalesce(v_apellidos, '')),
      'apoderado', btrim(coalesce(v_nombres_apod, '') || ' ' || coalesce(v_apellidos_apod, '')),
      'estado', v_estado,
      'motivo', v_motivo,
      'errores', to_jsonb(v_errores),
      'conflictos', to_jsonb(v_tipos),
      'diferencias', v_diferencias,
      'filas_repetidas', CASE WHEN v_repetidas LIKE '%,%' THEN to_jsonb(string_to_array(v_repetidas, ', ')::int[]) ELSE '[]'::jsonb END,
      'resolucion', v_res
    );
  END LOOP;

  RETURN jsonb_build_object('filas', v_resultado, 'inscritas', v_inscritas, 'pendientes', v_pendientes);
END;
$$;

-- Descartar un pendiente sin inscribir
CREATE OR REPLACE FUNCTION public.descartar_conflicto_importacion(p_conflicto_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.exigir_directiva('resuelve conflictos de importación');
  DELETE FROM public.conflictos_importacion WHERE id = p_conflicto_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. PERMISOS
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.importar_alumnas(uuid, jsonb, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.descartar_conflicto_importacion(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.exigir_directiva(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.importar_alumnas(uuid, jsonb, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.descartar_conflicto_importacion(uuid) TO authenticated;
