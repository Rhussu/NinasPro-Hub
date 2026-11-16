-- =============================================================================
-- Migration: 20261101000013_alumnas_importacion_autorizaciones.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Nómina de alumnas, carga masiva, ficha única por RUT, retiro,
--              autorizaciones del apoderado y revocación de imagen
--              (US-07, US-08, US-09, US-10, US-11, US-12).
--
--   - RUT: se valida con módulo 11 y se guarda con formato 12.345.678-K. La
--     ficha y el apoderado son únicos por RUT sin importar puntos ni guion.
--   - Alumnas, apoderados e inscripciones se crean solo con la RPC
--     importar_alumnas (carga masiva o inscripción individual), que valida cada
--     fila, reutiliza la ficha si el RUT ya existe e inscribe en una sola
--     transacción. Con p_solo_validar = true devuelve la previsualización.
--   - La matrícula se activa sola cuando el apoderado otorga el tratamiento de
--     datos (RB-1); sin él, la inscripción no puede quedar activa.
--   - Las autorizaciones se registran y revocan solo con RPC: un canal sin
--     respuesta queda no autorizado (RB-2) y la revocación rige desde su fecha
--     (RB-4). El respaldo firmado va a un bucket privado.
--
-- Las validaciones de reglas se aplican a las solicitudes de la app (con
-- auth.uid()); las operaciones del sistema (seed, service role) no las pasan.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RUT CHILENO (US-08)
-- -----------------------------------------------------------------------------
-- '12.345.678-k' -> '12345678K'
CREATE OR REPLACE FUNCTION public.normalizar_rut(p_rut text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$
  SELECT upper(regexp_replace(coalesce(p_rut, ''), '[.\-\s]', '', 'g'));
$$;

-- Formato válido y dígito verificador según módulo 11. Es la misma regla que
-- validarRut en lib/utils/rut.dart.
CREATE OR REPLACE FUNCTION public.rut_valido(p_rut text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$
DECLARE
  v_rut text := public.normalizar_rut(p_rut);
  v_cuerpo text;
  v_suma int := 0;
  v_mult int := 2;
  v_resto int;
  v_dv text;
BEGIN
  IF v_rut !~ '^\d{7,8}[0-9K]$' THEN
    RETURN false;
  END IF;
  v_cuerpo := left(v_rut, -1);
  FOR i IN REVERSE length(v_cuerpo)..1 LOOP
    v_suma := v_suma + substr(v_cuerpo, i, 1)::int * v_mult;
    v_mult := CASE WHEN v_mult = 7 THEN 2 ELSE v_mult + 1 END;
  END LOOP;
  v_resto := 11 - (v_suma % 11);
  v_dv := CASE v_resto WHEN 11 THEN '0' WHEN 10 THEN 'K' ELSE v_resto::text END;
  RETURN v_dv = right(v_rut, 1);
END;
$$;

-- '12345678K' -> '12.345.678-K' (formato de las fichas existentes)
CREATE OR REPLACE FUNCTION public.formatear_rut(p_rut text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$
  SELECT CASE WHEN length(public.normalizar_rut(p_rut)) < 2 THEN p_rut ELSE
    regexp_replace(left(public.normalizar_rut(p_rut), -1), '(\d)(?=(\d{3})+$)', '\1.', 'g')
    || '-' || right(public.normalizar_rut(p_rut), 1)
  END;
$$;

-- Una sola ficha por RUT aunque se haya escrito con o sin puntos
CREATE UNIQUE INDEX alumnas_rut_normalizado ON public.alumnas (public.normalizar_rut(rut));
CREATE UNIQUE INDEX apoderados_rut_normalizado ON public.apoderados (public.normalizar_rut(rut))
  WHERE rut IS NOT NULL;

-- Fecha ISO o NULL si no es una fecha real (ej. 2026-02-30)
CREATE OR REPLACE FUNCTION public.fecha_o_null(p_texto text)
RETURNS date
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $$
BEGIN
  IF p_texto !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RETURN NULL;
  END IF;
  RETURN p_texto::date;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. INSCRIPCIONES: retiro completo y activación condicionada (US-09, US-11)
-- -----------------------------------------------------------------------------
ALTER TABLE public.inscripciones
  ADD CONSTRAINT inscripciones_retiro_completo CHECK (
    estado <> 'retirada' OR (fecha_retiro IS NOT NULL AND nullif(btrim(motivo_retiro), '') IS NOT NULL)
  );

-- Altas solo por la RPC (valida RUT, contacto del apoderado y duplicados)
REVOKE INSERT ON public.alumnas, public.apoderados, public.inscripciones FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.consentimiento_datos_otorgado(p_alumna uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.autorizaciones_apoderado
    WHERE alumna_id = p_alumna AND autoriza_tratamiento_datos = 'otorgada'
  );
$$;

-- Con el consentimiento ya otorgado (ej. una alumna que vuelve en otro año),
-- la nueva inscripción nace activa. Sin él, la app no puede activarla (RB-1).
CREATE OR REPLACE FUNCTION public.validar_estado_inscripcion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.estado = 'preinscrita' AND public.consentimiento_datos_otorgado(NEW.alumna_id) THEN
    NEW.estado := 'activa';
  END IF;

  IF auth.uid() IS NOT NULL
    AND NEW.estado = 'activa'
    AND (TG_OP = 'INSERT' OR OLD.estado IS DISTINCT FROM 'activa')
    AND NOT public.consentimiento_datos_otorgado(NEW.alumna_id)
  THEN
    RAISE EXCEPTION 'La matrícula se activa al registrar el consentimiento de tratamiento de datos del apoderado.'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.estado <> 'retirada' THEN
    NEW.fecha_retiro := NULL;
    NEW.motivo_retiro := NULL;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER inscripciones_validar_estado
  BEFORE INSERT OR UPDATE ON public.inscripciones
  FOR EACH ROW EXECUTE FUNCTION public.validar_estado_inscripcion();

-- Otorgar el tratamiento de datos activa las preinscripciones; retirarlo las
-- devuelve a preinscrita (sale de las listas de asistencia). US-11 escenario 1.
CREATE OR REPLACE FUNCTION public.sincronizar_matricula_consentimiento()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NEW.autoriza_tratamiento_datos = 'otorgada'
    AND (TG_OP = 'INSERT' OR OLD.autoriza_tratamiento_datos IS DISTINCT FROM 'otorgada')
  THEN
    UPDATE public.inscripciones SET estado = 'activa'
    WHERE alumna_id = NEW.alumna_id AND estado = 'preinscrita';
  ELSIF TG_OP = 'UPDATE'
    AND OLD.autoriza_tratamiento_datos = 'otorgada'
    AND NEW.autoriza_tratamiento_datos <> 'otorgada'
  THEN
    UPDATE public.inscripciones SET estado = 'preinscrita'
    WHERE alumna_id = NEW.alumna_id AND estado = 'activa';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER autorizaciones_sincronizar_matricula
  AFTER INSERT OR UPDATE OF autoriza_tratamiento_datos ON public.autorizaciones_apoderado
  FOR EACH ROW EXECUTE FUNCTION public.sincronizar_matricula_consentimiento();

-- Sin consentimiento no hay asistencia ordinaria (US-11 escenario 2)
CREATE OR REPLACE FUNCTION public.impedir_asistencia_sin_consentimiento()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.inscripciones WHERE id = NEW.inscripcion_id AND estado = 'preinscrita')
  THEN
    RAISE EXCEPTION 'La alumna aún no tiene el consentimiento de datos: no se registra su asistencia.'
      USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER asistencia_alumnas_consentimiento
  BEFORE INSERT ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.impedir_asistencia_sin_consentimiento();
CREATE TRIGGER participacion_clase_consentimiento
  BEFORE INSERT ON public.participacion_clase
  FOR EACH ROW EXECUTE FUNCTION public.impedir_asistencia_sin_consentimiento();

-- -----------------------------------------------------------------------------
-- 3. RPC: CARGA MASIVA E INSCRIPCIÓN INDIVIDUAL (US-07, US-08, US-09)
-- -----------------------------------------------------------------------------
-- p_filas: arreglo de objetos con las columnas de la plantilla y 'fila' (número
-- de fila en la planilla). Cada fila se clasifica como 'nueva' (se crea la
-- ficha), 'existente' (el RUT ya tiene ficha y se reutiliza) o 'invalida' (con
-- su motivo). Las válidas se inscriben todas o ninguna; las inválidas no
-- impiden las demás. Con p_solo_validar no se escribe nada.
CREATE OR REPLACE FUNCTION public.importar_alumnas(
  p_instancia_id uuid,
  p_filas jsonb,
  p_solo_validar boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_instancia public.instancias_curso;
  v_resultado jsonb := '[]'::jsonb;
  v_fila jsonb;
  v_num int;
  v_motivos text[];
  v_rut text;
  v_rut_apod text;
  v_nombres text;
  v_apellidos text;
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
  v_apoderado_id uuid;
  v_estado text;
  v_repetidas text;
  v_inscritas int := 0;
  v_filas_por_rut jsonb;
  v_correo_re constant text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
BEGIN
  SELECT * INTO v_instancia FROM public.instancias_curso WHERE id = p_instancia_id;
  IF v_instancia.id IS NULL OR NOT public.gestiona_sede(v_instancia.sede_id) THEN
    RAISE EXCEPTION 'Solo la Directiva o el Equipo de Gestión de la sede inscriben alumnas.' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) = 0 THEN
    RAISE EXCEPTION 'La planilla no tiene filas.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_filas) > 1000 THEN
    RAISE EXCEPTION 'La planilla tiene más de 1.000 filas: divídela en varias cargas.' USING ERRCODE = '22023';
  END IF;

  -- Dos cargas simultáneas a la misma instancia no deben cruzarse
  PERFORM pg_advisory_xact_lock(hashtext('importar_alumnas' || p_instancia_id::text));

  -- Filas en que aparece cada RUT, para rechazar los repetidos dentro del archivo (US-08)
  SELECT coalesce(jsonb_object_agg(clave, filas), '{}'::jsonb) INTO v_filas_por_rut
  FROM (
    SELECT public.normalizar_rut(f->>'rut') AS clave,
           string_agg(coalesce(f->>'fila', '?'), ', ' ORDER BY ord) AS filas
    FROM jsonb_array_elements(p_filas) WITH ORDINALITY AS t(f, ord)
    WHERE public.normalizar_rut(f->>'rut') <> ''
    GROUP BY 1
  ) r;

  FOR v_fila IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
    v_num := coalesce(nullif(v_fila->>'fila', '')::int, 0);
    v_motivos := '{}';
    v_rut := nullif(btrim(v_fila->>'rut'), '');
    v_rut_apod := nullif(btrim(v_fila->>'rut_apoderado'), '');
    v_nombres := nullif(btrim(regexp_replace(v_fila->>'nombres', '\s+', ' ', 'g')), '');
    v_apellidos := nullif(btrim(regexp_replace(v_fila->>'apellidos', '\s+', ' ', 'g')), '');
    v_fecha_nac := public.fecha_o_null(btrim(v_fila->>'fecha_nacimiento'));
    v_correo := nullif(lower(btrim(v_fila->>'correo')), '');
    v_establecimiento := nullif(btrim(v_fila->>'establecimiento'), '');
    v_curso_escolar := nullif(btrim(v_fila->>'curso_escolar'), '');
    v_nombres_apod := nullif(btrim(regexp_replace(v_fila->>'nombres_apoderado', '\s+', ' ', 'g')), '');
    v_apellidos_apod := nullif(btrim(regexp_replace(v_fila->>'apellidos_apoderado', '\s+', ' ', 'g')), '');
    v_telefono := nullif(btrim(v_fila->>'telefono_apoderado'), '');
    v_correo_apod := nullif(lower(btrim(v_fila->>'correo_apoderado')), '');
    v_parentesco := nullif(btrim(v_fila->>'parentesco'), '');
    v_alumna := NULL;

    -- Identidad de la alumna
    IF v_rut IS NULL THEN
      v_motivos := array_append(v_motivos, 'Falta el RUT de la alumna');
    ELSIF NOT public.rut_valido(v_rut) THEN
      v_motivos := array_append(v_motivos, 'RUT de la alumna inválido (dígito verificador)');
    ELSE
      v_repetidas := v_filas_por_rut->>public.normalizar_rut(v_rut);
      IF v_repetidas LIKE '%,%' THEN
        v_motivos := array_append(v_motivos, ('RUT repetido en la planilla (filas ' || v_repetidas || ')'));
      END IF;
      SELECT * INTO v_alumna FROM public.alumnas WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_rut);
    END IF;

    IF v_alumna.id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.inscripciones WHERE alumna_id = v_alumna.id AND instancia_curso_id = p_instancia_id
    ) THEN
      v_motivos := array_append(v_motivos, 'Ya está inscrita en este curso');
    END IF;

    IF v_nombres IS NULL OR v_apellidos IS NULL THEN
      v_motivos := array_append(v_motivos, 'Faltan los nombres o apellidos de la alumna');
    ELSIF length(v_nombres) > 100 OR length(v_apellidos) > 100 THEN
      v_motivos := array_append(v_motivos, 'Nombres o apellidos de más de 100 caracteres');
    END IF;

    IF v_fecha_nac IS NULL THEN
      v_motivos := array_append(v_motivos, 'Fecha de nacimiento ausente o no válida');
    ELSIF v_fecha_nac >= current_date OR v_fecha_nac < current_date - interval '30 years' THEN
      v_motivos := array_append(v_motivos, 'Fecha de nacimiento fuera de rango');
    END IF;

    IF v_correo IS NOT NULL THEN
      IF v_correo !~ v_correo_re OR length(v_correo) > 150 THEN
        v_motivos := array_append(v_motivos, 'Correo de la alumna no válido');
      ELSIF EXISTS (SELECT 1 FROM public.alumnas WHERE correo = v_correo AND id IS DISTINCT FROM v_alumna.id)
        OR EXISTS (
          SELECT 1 FROM auth.users u
          WHERE lower(u.email) = v_correo AND u.id IS DISTINCT FROM v_alumna.perfil_usuario_id
        )
      THEN
        v_motivos := array_append(v_motivos, 'El correo de la alumna ya lo usa otra persona');
      END IF;
    END IF;

    IF length(v_establecimiento) > 150 OR length(v_curso_escolar) > 50 OR length(v_parentesco) > 50 THEN
      v_motivos := array_append(v_motivos, 'Establecimiento, curso escolar o parentesco demasiado largos');
    END IF;

    -- Apoderado/a: contacto obligatorio por protocolo institucional (US-08 escenario 3)
    IF v_rut_apod IS NOT NULL AND NOT public.rut_valido(v_rut_apod) THEN
      v_motivos := array_append(v_motivos, 'RUT del apoderado/a inválido (dígito verificador)');
    END IF;
    IF v_nombres_apod IS NULL OR v_apellidos_apod IS NULL THEN
      v_motivos := array_append(v_motivos, 'Faltan los nombres o apellidos del apoderado/a');
    ELSIF length(v_nombres_apod) > 100 OR length(v_apellidos_apod) > 100 THEN
      v_motivos := array_append(v_motivos, 'Nombre del apoderado/a de más de 100 caracteres');
    END IF;
    IF v_telefono IS NULL OR v_correo_apod IS NULL THEN
      v_motivos := array_append(v_motivos, 'El correo y el teléfono del apoderado/a son obligatorios por protocolo institucional');
    ELSE
      IF length(regexp_replace(v_telefono, '\D', '', 'g')) NOT BETWEEN 8 AND 15 OR length(v_telefono) > 20 THEN
        v_motivos := array_append(v_motivos, 'Teléfono del apoderado/a no válido');
      END IF;
      IF v_correo_apod !~ v_correo_re OR length(v_correo_apod) > 150 THEN
        v_motivos := array_append(v_motivos, 'Correo del apoderado/a no válido');
      END IF;
    END IF;

    IF cardinality(v_motivos) > 0 THEN
      v_estado := 'invalida';
    ELSIF v_alumna.id IS NOT NULL THEN
      v_estado := 'existente';
    ELSE
      v_estado := 'nueva';
    END IF;

    IF v_estado <> 'invalida' AND NOT coalesce(p_solo_validar, false) THEN
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
      ELSIF v_alumna.correo IS NULL AND v_correo IS NOT NULL THEN
        UPDATE public.alumnas SET correo = v_correo, updated_at = timezone('utc'::text, now())
        WHERE id = v_alumna.id
        RETURNING * INTO v_alumna;
      END IF;

      -- Nace preinscrita; el trigger la activa si ya tiene el consentimiento
      INSERT INTO public.inscripciones (alumna_id, instancia_curso_id, estado)
      VALUES (v_alumna.id, p_instancia_id, 'preinscrita');
      v_inscritas := v_inscritas + 1;

      -- Con su correo, la alumna queda autorizada para crear su cuenta (US-04)
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

    v_resultado := v_resultado || jsonb_build_object(
      'fila', v_num,
      'rut', CASE WHEN v_rut IS NOT NULL AND public.rut_valido(v_rut) THEN public.formatear_rut(v_rut) ELSE coalesce(v_rut, '') END,
      'nombre', btrim(coalesce(v_nombres, '') || ' ' || coalesce(v_apellidos, '')),
      'apoderado', btrim(coalesce(v_nombres_apod, '') || ' ' || coalesce(v_apellidos_apod, '')),
      'estado', v_estado,
      'motivo', CASE WHEN cardinality(v_motivos) = 0 THEN NULL ELSE array_to_string(v_motivos, '. ') END
    );
  END LOOP;

  RETURN jsonb_build_object('filas', v_resultado, 'inscritas', v_inscritas);
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. RPC: RETIRO FORMAL (US-09 escenario 3)
-- -----------------------------------------------------------------------------
-- Cambia solo el estado de la matrícula: la asistencia y participación previas
-- se conservan (las FK son RESTRICT).
CREATE OR REPLACE FUNCTION public.retirar_inscripcion(p_inscripcion_id uuid, p_fecha date, p_motivo text)
RETURNS public.inscripciones
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_insc public.inscripciones;
BEGIN
  SELECT * INTO v_insc FROM public.inscripciones WHERE id = p_inscripcion_id;
  IF v_insc.id IS NULL OR NOT public.gestiona_sede(public.sede_instancia(v_insc.instancia_curso_id)) THEN
    RAISE EXCEPTION 'Solo la Directiva o el Equipo de Gestión de la sede registran retiros.' USING ERRCODE = '42501';
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

-- -----------------------------------------------------------------------------
-- 5. AUTORIZACIONES DEL APODERADO (US-10, US-12)
-- -----------------------------------------------------------------------------
-- Solo por RPC: así cada registro guarda quién lo hizo, cuándo y su respaldo
REVOKE INSERT, UPDATE, DELETE ON public.autorizaciones_apoderado, public.autorizaciones_imagen_canales
  FROM anon, authenticated;

-- Resumen del uso de imagen: otorgada si hay algún canal, revocada si todos
-- los que se otorgaron se revocaron, no_otorgada en otro caso
CREATE OR REPLACE FUNCTION public.estado_imagen_general(p_autorizacion uuid)
RETURNS public.estado_autorizacion
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT CASE
    WHEN bool_or(autorizado) THEN 'otorgada'
    WHEN bool_or(fecha_revocacion IS NOT NULL) THEN 'revocada'
    ELSE 'no_otorgada'
  END::public.estado_autorizacion
  FROM public.autorizaciones_imagen_canales WHERE autorizacion_id = p_autorizacion;
$$;

-- p_canales: {"redes_sociales": true, "prensa": false, …}. Un canal ausente
-- queda no autorizado (RB-2). Volver a otorgar un canal revocado borra la
-- revocación; dejarlo en false la conserva.
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
DECLARE
  v_alumna public.alumnas;
  v_aut public.autorizaciones_apoderado;
  v_clave text;
  v_canal public.tipo_canal_imagen;
  v_otorgado boolean;
  v_alguno boolean := false;
  v_documento text := nullif(btrim(p_documento), '');
BEGIN
  SELECT * INTO v_alumna FROM public.alumnas WHERE id = p_alumna_id;
  IF v_alumna.id IS NULL OR NOT public.gestiona_alumna(p_alumna_id) THEN
    RAISE EXCEPTION 'Solo la Directiva o el Equipo de Gestión de su sede registran autorizaciones.' USING ERRCODE = '42501';
  END IF;
  IF p_tratamiento_datos IS NULL OR p_tratamiento_datos = 'revocada' THEN
    RAISE EXCEPTION 'Indica si el apoderado/a otorgó el tratamiento de datos.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(coalesce(p_canales, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'Los canales de imagen no tienen el formato esperado.' USING ERRCODE = '22023';
  END IF;
  FOR v_clave IN SELECT jsonb_object_keys(coalesce(p_canales, '{}'::jsonb)) LOOP
    IF NOT v_clave = ANY (enum_range(NULL::public.tipo_canal_imagen)::text[]) THEN
      RAISE EXCEPTION 'Canal de imagen desconocido: %.', v_clave USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(p_canales->v_clave) <> 'boolean' THEN
      RAISE EXCEPTION 'El canal % debe ser verdadero o falso.', v_clave USING ERRCODE = '22023';
    END IF;
    v_alguno := v_alguno OR (p_canales->>v_clave)::boolean;
  END LOOP;
  IF v_documento IS NOT NULL AND v_documento NOT LIKE p_alumna_id::text || '/%' THEN
    RAISE EXCEPTION 'El respaldo no corresponde a esta alumna.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha_firma > current_date THEN
    RAISE EXCEPTION 'La fecha de firma no puede ser futura.' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_aut FROM public.autorizaciones_apoderado WHERE alumna_id = p_alumna_id FOR UPDATE;
  v_documento := coalesce(v_documento, v_aut.documento_respaldo_url);

  IF (p_tratamiento_datos = 'otorgada' OR v_alguno) AND v_documento IS NULL THEN
    RAISE EXCEPTION 'Adjunta el documento firmado por el apoderado/a para registrar lo que autorizó.' USING ERRCODE = '22023';
  END IF;

  IF v_aut.id IS NULL THEN
    INSERT INTO public.autorizaciones_apoderado (
      alumna_id, apoderado_id, autoriza_tratamiento_datos, documento_respaldo_url, fecha_firma, registrado_por
    )
    VALUES (
      p_alumna_id, v_alumna.apoderado_id, p_tratamiento_datos, v_documento,
      coalesce(p_fecha_firma, current_date), auth.uid()
    )
    RETURNING * INTO v_aut;
  ELSE
    UPDATE public.autorizaciones_apoderado
    SET autoriza_tratamiento_datos = p_tratamiento_datos,
        documento_respaldo_url = v_documento,
        fecha_firma = coalesce(p_fecha_firma, fecha_firma, current_date),
        registrado_por = auth.uid(),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_aut.id
    RETURNING * INTO v_aut;
  END IF;

  FOREACH v_canal IN ARRAY enum_range(NULL::public.tipo_canal_imagen) LOOP
    v_otorgado := coalesce((p_canales->>v_canal::text)::boolean, false);
    INSERT INTO public.autorizaciones_imagen_canales (autorizacion_id, canal, autorizado)
    VALUES (v_aut.id, v_canal, v_otorgado)
    ON CONFLICT (autorizacion_id, canal) DO UPDATE
      SET autorizado = excluded.autorizado,
          fecha_revocacion = CASE WHEN excluded.autorizado THEN NULL ELSE autorizaciones_imagen_canales.fecha_revocacion END,
          motivo_revocacion = CASE WHEN excluded.autorizado THEN NULL ELSE autorizaciones_imagen_canales.motivo_revocacion END,
          fecha_modificacion = CASE
            WHEN autorizaciones_imagen_canales.autorizado = excluded.autorizado THEN autorizaciones_imagen_canales.fecha_modificacion
            ELSE timezone('utc'::text, now())
          END;
  END LOOP;

  UPDATE public.autorizaciones_apoderado
  SET autoriza_uso_imagen_general = public.estado_imagen_general(v_aut.id)
  WHERE id = v_aut.id
  RETURNING * INTO v_aut;

  RETURN to_jsonb(v_aut);
END;
$$;

-- Revocación por canal desde la fecha en que el apoderado la solicitó (US-12)
CREATE OR REPLACE FUNCTION public.revocar_autorizacion_imagen(
  p_alumna_id uuid,
  p_canales public.tipo_canal_imagen[],
  p_fecha date,
  p_motivo text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_aut public.autorizaciones_apoderado;
  v_no_otorgado text;
BEGIN
  IF NOT public.gestiona_alumna(p_alumna_id) THEN
    RAISE EXCEPTION 'Solo la Directiva o el Equipo de Gestión de su sede revocan autorizaciones.' USING ERRCODE = '42501';
  END IF;
  IF p_canales IS NULL OR cardinality(p_canales) = 0 THEN
    RAISE EXCEPTION 'Elige al menos un canal.' USING ERRCODE = '22023';
  END IF;
  IF nullif(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Indica el motivo de la revocación.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha IS NULL OR p_fecha > current_date THEN
    RAISE EXCEPTION 'La fecha de la solicitud no puede ser futura.' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_aut FROM public.autorizaciones_apoderado WHERE alumna_id = p_alumna_id FOR UPDATE;
  IF v_aut.id IS NULL THEN
    RAISE EXCEPTION 'La alumna no tiene autorizaciones registradas.' USING ERRCODE = '22023';
  END IF;
  IF v_aut.fecha_firma IS NOT NULL AND p_fecha < v_aut.fecha_firma::date THEN
    RAISE EXCEPTION 'La revocación no puede ser anterior a la firma (%).', to_char(v_aut.fecha_firma, 'DD-MM-YYYY')
      USING ERRCODE = '22023';
  END IF;

  SELECT string_agg(c::text, ', ') INTO v_no_otorgado
  FROM unnest(p_canales) AS c
  WHERE NOT EXISTS (
    SELECT 1 FROM public.autorizaciones_imagen_canales
    WHERE autorizacion_id = v_aut.id AND canal = c AND autorizado
  );
  IF v_no_otorgado IS NOT NULL THEN
    RAISE EXCEPTION 'Solo se revocan canales autorizados (no lo estaba: %).', v_no_otorgado USING ERRCODE = '22023';
  END IF;

  UPDATE public.autorizaciones_imagen_canales
  SET autorizado = false,
      fecha_revocacion = p_fecha,
      motivo_revocacion = btrim(p_motivo),
      fecha_modificacion = timezone('utc'::text, now())
  WHERE autorizacion_id = v_aut.id AND canal = ANY (p_canales);

  UPDATE public.autorizaciones_apoderado
  SET autoriza_uso_imagen_general = public.estado_imagen_general(v_aut.id),
      registrado_por = auth.uid(),
      updated_at = timezone('utc'::text, now())
  WHERE id = v_aut.id
  RETURNING * INTO v_aut;

  RETURN to_jsonb(v_aut);
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. APTITUD DE LAS EVIDENCIAS POR CANAL (US-12 escenarios 2 y 3)
-- -----------------------------------------------------------------------------
-- Una foto es apta para un canal si se marcó apta y, salvo que los rostros
-- estén censurados, cada alumna presente en esa clase tenía el tratamiento de
-- datos y el canal autorizados en la fecha de la clase. Una revocación con
-- fecha D afecta solo a las clases desde D: las anteriores conservan su
-- aptitud (los usos históricos no cambian).
CREATE OR REPLACE FUNCTION public.evidencia_apta_canal(p_evidencia_id uuid, p_canal public.tipo_canal_imagen)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT e.apta_para_evidencia AND (
    e.rostros_censurados OR NOT EXISTS (
      SELECT 1
      FROM public.asistencia_alumnas aa
      JOIN public.inscripciones i ON i.id = aa.inscripcion_id
      LEFT JOIN public.autorizaciones_apoderado ap ON ap.alumna_id = i.alumna_id
      LEFT JOIN public.autorizaciones_imagen_canales ca ON ca.autorizacion_id = ap.id AND ca.canal = p_canal
      WHERE aa.clase_id = e.clase_id
        AND aa.estado = 'presente'
        AND NOT (
          coalesce(ap.autoriza_tratamiento_datos = 'otorgada', false)
          AND (coalesce(ca.autorizado, false) OR coalesce(ca.fecha_revocacion > cl.fecha, false))
        )
    )
  )
  FROM public.evidencias_fotograficas e
  JOIN public.clases cl ON cl.id = e.clase_id
  WHERE e.id = p_evidencia_id
    AND (public.es_staff_sede(public.sede_clase(cl.id)) OR public.current_user_role() = 'comunicacion');
$$;

-- -----------------------------------------------------------------------------
-- 7. NÓMINA: una fila por inscripción con asistencia y consentimiento
-- -----------------------------------------------------------------------------
-- security_invoker: cada rol ve solo lo que su RLS le permite. No incluye
-- datos del apoderado (la ficha los lee aparte, solo administración).
CREATE VIEW public.nomina_alumnas WITH (security_invoker = true) AS
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
  -- US-11 escenario 3: sigue sin consentimiento tras 2 sesiones desde su inscripción
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
) ses ON true;

REVOKE ALL ON public.nomina_alumnas FROM anon, public;
GRANT SELECT ON public.nomina_alumnas TO authenticated;

-- -----------------------------------------------------------------------------
-- 8. RESPALDOS FIRMADOS EN UN BUCKET PRIVADO (US-10 escenario 3)
-- -----------------------------------------------------------------------------
-- Ruta: <alumna_id>/<archivo>. Storage cifra en reposo (AES-256) y la app solo
-- lee con URLs firmadas de corta duración sobre HTTPS.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('autorizaciones', 'autorizaciones', false, 5242880, ARRAY['application/pdf', 'image/png', 'image/jpeg'])
ON CONFLICT (id) DO NOTHING;

-- Alumna dueña de un objeto del bucket, o NULL si la ruta no empieza con un uuid
CREATE OR REPLACE FUNCTION public.alumna_de_ruta(p_nombre text)
RETURNS uuid
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $$
BEGIN
  RETURN split_part(p_nombre, '/', 1)::uuid;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

CREATE POLICY autorizaciones_respaldo_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.gestiona_alumna(public.alumna_de_ruta(name)));
CREATE POLICY autorizaciones_respaldo_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'autorizaciones' AND public.gestiona_alumna(public.alumna_de_ruta(name)));
CREATE POLICY autorizaciones_respaldo_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.gestiona_alumna(public.alumna_de_ruta(name)))
  WITH CHECK (bucket_id = 'autorizaciones' AND public.gestiona_alumna(public.alumna_de_ruta(name)));
CREATE POLICY autorizaciones_respaldo_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'autorizaciones' AND public.gestiona_alumna(public.alumna_de_ruta(name)));

-- -----------------------------------------------------------------------------
-- 9. PERMISOS DE LAS FUNCIONES
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.importar_alumnas(uuid, jsonb, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.retirar_inscripcion(uuid, date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.evidencia_apta_canal(uuid, public.tipo_canal_imagen) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.consentimiento_datos_otorgado(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.estado_imagen_general(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.importar_alumnas(uuid, jsonb, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retirar_inscripcion(uuid, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_autorizaciones(uuid, public.estado_autorizacion, jsonb, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revocar_autorizacion_imagen(uuid, public.tipo_canal_imagen[], date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.evidencia_apta_canal(uuid, public.tipo_canal_imagen) TO authenticated;
