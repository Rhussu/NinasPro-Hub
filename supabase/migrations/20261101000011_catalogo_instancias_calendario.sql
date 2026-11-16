-- =============================================================================
-- Migration: 20261101000011_catalogo_instancias_calendario.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Catálogo de sedes y cursos, programación de instancias con
--              generación de sesiones y calendario con suspensión de clases
--              (US-01, US-02, US-03).
--
--   - Sedes y cursos: nombre y código únicos sin importar mayúsculas ni
--     espacios. Solo la Directiva los escribe (RLS existente → HTTP 403).
--   - Instancias: se crean solo con la RPC crear_instancia_curso, que valida
--     las fechas y genera las sesiones semanales en la misma transacción. Una
--     instancia repetida (mismo curso, sede y período) solo se crea si se
--     confirma, y queda como una sección paralela (A, B, …).
--   - Calendario: Gestión suspende y reanuda clases de su sede y agrega
--     sesiones especiales con la RPC agregar_sesion_especial. Las clases
--     suspendidas no admiten asistencia ni cuentan en el porcentaje.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SEDES Y CURSOS: datos limpios y unicidad sin distinguir mayúsculas (US-01)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalizar_sede()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  NEW.nombre := btrim(regexp_replace(NEW.nombre, '\s+', ' ', 'g'));
  NEW.ciudad := nullif(btrim(NEW.ciudad), '');
  NEW.region := nullif(btrim(NEW.region), '');
  NEW.institucion_anfitriona := nullif(btrim(NEW.institucion_anfitriona), '');
  RETURN NEW;
END;
$$;

CREATE TRIGGER sedes_normalizar
  BEFORE INSERT OR UPDATE ON public.sedes
  FOR EACH ROW EXECUTE FUNCTION public.normalizar_sede();

CREATE OR REPLACE FUNCTION public.normalizar_curso()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  NEW.codigo := upper(btrim(NEW.codigo));
  NEW.nombre := btrim(regexp_replace(NEW.nombre, '\s+', ' ', 'g'));
  NEW.descripcion := nullif(btrim(NEW.descripcion), '');
  RETURN NEW;
END;
$$;

CREATE TRIGGER cursos_normalizar
  BEFORE INSERT OR UPDATE ON public.cursos
  FOR EACH ROW EXECUTE FUNCTION public.normalizar_curso();

ALTER TABLE public.sedes
  ADD CONSTRAINT sedes_nombre_no_vacio CHECK (nombre <> '');
CREATE UNIQUE INDEX sedes_nombre_unico ON public.sedes (lower(nombre));

ALTER TABLE public.cursos
  ADD CONSTRAINT cursos_nombre_no_vacio CHECK (nombre <> ''),
  ADD CONSTRAINT cursos_codigo_no_vacio CHECK (codigo <> '');

-- -----------------------------------------------------------------------------
-- 2. INSTANCIAS: secciones paralelas y horario válido (US-02 escenario 3)
-- -----------------------------------------------------------------------------
ALTER TABLE public.instancias_curso
  ADD COLUMN seccion SMALLINT NOT NULL DEFAULT 1,
  ADD CONSTRAINT instancias_curso_seccion_valida CHECK (seccion BETWEEN 1 AND 26),
  ADD CONSTRAINT instancias_curso_horario_valido CHECK (hora_fin > hora_inicio),
  ADD CONSTRAINT instancias_curso_dia_valido CHECK (
    dia_semana IN ('Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo')
  ),
  DROP CONSTRAINT instancias_curso_curso_id_sede_id_periodo_academico_key,
  ADD CONSTRAINT instancias_curso_seccion_unica UNIQUE (curso_id, sede_id, periodo_academico, seccion);

-- Sin INSERT directo: así toda instancia nace con su calendario de sesiones
REVOKE INSERT ON public.instancias_curso FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. CLASES: sesiones especiales y motivo obligatorio al suspender (US-03)
-- -----------------------------------------------------------------------------
ALTER TABLE public.clases
  ADD COLUMN es_especial BOOLEAN NOT NULL DEFAULT false,
  ADD CONSTRAINT clases_motivo_suspension CHECK (
    estado <> 'suspendida' OR nullif(btrim(motivo_suspension), '') IS NOT NULL
  ),
  ADD CONSTRAINT clases_horario_valido CHECK (hora_inicio IS NULL OR hora_fin IS NULL OR hora_fin > hora_inicio);

-- Las sesiones se crean con las RPC (generación automática o sesión especial)
REVOKE INSERT ON public.clases FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. CÁLCULO DEL CALENDARIO
-- -----------------------------------------------------------------------------

-- Período académico de una fecha: '2026-1' (enero a junio) o '2026-2' (julio a diciembre)
CREATE OR REPLACE FUNCTION public.periodo_academico_de(p_fecha date)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT extract(year FROM p_fecha)::int::text || '-' || CASE WHEN extract(month FROM p_fecha) >= 7 THEN '2' ELSE '1' END;
$$;

-- Nombre del día según ISO (1 = lunes … 7 = domingo)
CREATE OR REPLACE FUNCTION public.nombre_dia_semana(p_dia int)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT (ARRAY['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'])[p_dia];
$$;

-- Fechas de las clases semanales entre dos fechas (inclusive) para un día ISO
CREATE OR REPLACE FUNCTION public.fechas_sesiones(p_inicio date, p_termino date, p_dia int)
RETURNS SETOF date
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT d::date
  FROM generate_series(
    p_inicio + ((p_dia - extract(isodow FROM p_inicio)::int + 7) % 7),
    p_termino,
    interval '7 days'
  ) AS d;
$$;

-- -----------------------------------------------------------------------------
-- 5. RPC: PROGRAMAR UNA INSTANCIA Y GENERAR SUS SESIONES (US-02)
-- -----------------------------------------------------------------------------
-- Errores: 403 sin permiso, 400 con datos inválidos y 409 (PT409) si la
-- instancia ya existe y no se pidió una sección paralela.
CREATE OR REPLACE FUNCTION public.crear_instancia_curso(
  p_curso_id uuid,
  p_sede_id uuid,
  p_fecha_inicio date,
  p_fecha_termino date,
  p_dia_semana int,
  p_hora_inicio time DEFAULT '10:00',
  p_hora_fin time DEFAULT '13:00',
  p_nueva_seccion boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_periodo text;
  v_seccion_max smallint;
  v_total int;
  v_instancia public.instancias_curso;
BEGIN
  IF NOT public.is_directorio() THEN
    RAISE EXCEPTION 'Solo la Directiva programa instancias de curso.' USING ERRCODE = '42501';
  END IF;

  IF p_curso_id IS NULL OR p_sede_id IS NULL OR p_fecha_inicio IS NULL OR p_fecha_termino IS NULL THEN
    RAISE EXCEPTION 'Elige el curso, la sede y las fechas.' USING ERRCODE = '22023';
  END IF;
  IF p_dia_semana IS NULL OR p_dia_semana NOT BETWEEN 1 AND 7 THEN
    RAISE EXCEPTION 'Elige el día de clases.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha_termino <= p_fecha_inicio THEN
    RAISE EXCEPTION 'La fecha de término debe ser posterior a la de inicio.' USING ERRCODE = '22023';
  END IF;
  IF p_hora_fin <= p_hora_inicio THEN
    RAISE EXCEPTION 'La hora de término debe ser posterior a la de inicio.' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cursos WHERE id = p_curso_id AND activo) THEN
    RAISE EXCEPTION 'El curso no existe o no está activo.' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sedes WHERE id = p_sede_id AND activa) THEN
    RAISE EXCEPTION 'La sede no existe o no está activa.' USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_total FROM public.fechas_sesiones(p_fecha_inicio, p_fecha_termino, p_dia_semana);
  IF v_total = 0 THEN
    RAISE EXCEPTION 'No hay ningún % entre esas fechas.', lower(public.nombre_dia_semana(p_dia_semana))
      USING ERRCODE = '22023';
  END IF;

  v_periodo := public.periodo_academico_de(p_fecha_inicio);

  -- Bloquea la combinación para que dos creaciones simultáneas no tomen la misma sección
  PERFORM pg_advisory_xact_lock(hashtext(p_curso_id::text || p_sede_id::text || v_periodo));

  SELECT max(seccion) INTO v_seccion_max
  FROM public.instancias_curso
  WHERE curso_id = p_curso_id AND sede_id = p_sede_id AND periodo_academico = v_periodo;

  IF v_seccion_max IS NOT NULL AND NOT coalesce(p_nueva_seccion, false) THEN
    RAISE EXCEPTION 'Ya existe una instancia de este curso en esta sede para el período %.', v_periodo
      USING ERRCODE = 'PT409', HINT = 'Confirma para crear una sección paralela.';
  END IF;

  INSERT INTO public.instancias_curso (
    curso_id, sede_id, periodo_academico, seccion, fecha_inicio, fecha_termino,
    dia_semana, hora_inicio, hora_fin
  )
  VALUES (
    p_curso_id, p_sede_id, v_periodo, coalesce(v_seccion_max, 0) + 1, p_fecha_inicio, p_fecha_termino,
    public.nombre_dia_semana(p_dia_semana), p_hora_inicio, p_hora_fin
  )
  RETURNING * INTO v_instancia;

  INSERT INTO public.clases (instancia_curso_id, numero_sesion, fecha, hora_inicio, hora_fin, estado)
  SELECT v_instancia.id, row_number() OVER (ORDER BY f), f, p_hora_inicio, p_hora_fin, 'programada'
  FROM public.fechas_sesiones(p_fecha_inicio, p_fecha_termino, p_dia_semana) AS f;

  RETURN to_jsonb(v_instancia) || jsonb_build_object('total_sesiones', v_total);
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. RPC: SESIÓN ESPECIAL O DE RECUPERACIÓN (US-03 escenario 3)
-- -----------------------------------------------------------------------------
-- Toma el número siguiente al último para no renumerar sesiones con registros.
CREATE OR REPLACE FUNCTION public.agregar_sesion_especial(
  p_instancia_id uuid,
  p_fecha date,
  p_hora_inicio time,
  p_hora_fin time
)
RETURNS public.clases
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_instancia public.instancias_curso;
  v_clase public.clases;
BEGIN
  SELECT * INTO v_instancia FROM public.instancias_curso WHERE id = p_instancia_id;

  IF v_instancia.id IS NULL OR NOT public.gestiona_sede(v_instancia.sede_id) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede agrega sesiones.' USING ERRCODE = '42501';
  END IF;
  IF p_fecha IS NULL OR p_hora_inicio IS NULL OR p_hora_fin IS NULL THEN
    RAISE EXCEPTION 'Indica la fecha y el horario de la sesión.' USING ERRCODE = '22023';
  END IF;
  IF p_hora_fin <= p_hora_inicio THEN
    RAISE EXCEPTION 'La hora de término debe ser posterior a la de inicio.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha < v_instancia.fecha_inicio THEN
    RAISE EXCEPTION 'La sesión no puede ser anterior al inicio del curso.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clases WHERE instancia_curso_id = p_instancia_id AND fecha = p_fecha) THEN
    RAISE EXCEPTION 'El curso ya tiene una sesión el %.', to_char(p_fecha, 'DD-MM-YYYY') USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_instancia_id::text));

  INSERT INTO public.clases (instancia_curso_id, numero_sesion, fecha, hora_inicio, hora_fin, estado, es_especial)
  SELECT p_instancia_id, coalesce(max(numero_sesion), 0) + 1, p_fecha, p_hora_inicio, p_hora_fin, 'programada', true
  FROM public.clases WHERE instancia_curso_id = p_instancia_id
  RETURNING * INTO v_clase;

  RETURN v_clase;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. SUSPENDER Y REANUDAR CLASES (US-03 escenario 2)
-- -----------------------------------------------------------------------------
-- La tutora puede actualizar la clase al pasar lista, pero solo Gestión de la
-- sede (o la Directiva) cambia su estado desde o hacia 'suspendida'.
CREATE OR REPLACE FUNCTION public.validar_cambio_estado_clase()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NEW.estado IS DISTINCT FROM OLD.estado AND 'suspendida' IN (NEW.estado, OLD.estado) THEN
    IF auth.uid() IS NOT NULL AND NOT public.gestiona_sede(public.sede_instancia(NEW.instancia_curso_id)) THEN
      RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede suspende o reanuda clases.' USING ERRCODE = '42501';
    END IF;

    IF NEW.estado = 'suspendida' THEN
      IF OLD.estado = 'realizada' OR EXISTS (SELECT 1 FROM public.asistencia_alumnas WHERE clase_id = NEW.id) THEN
        RAISE EXCEPTION 'No se puede suspender una clase que ya tiene asistencia registrada.' USING ERRCODE = '22023';
      END IF;
      IF nullif(btrim(NEW.motivo_suspension), '') IS NULL THEN
        RAISE EXCEPTION 'Indica el motivo de la suspensión.' USING ERRCODE = '22023';
      END IF;
      NEW.motivo_suspension := btrim(NEW.motivo_suspension);
    END IF;
  END IF;

  IF NEW.estado <> 'suspendida' THEN
    NEW.motivo_suspension := NULL;
  END IF;

  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE TRIGGER clases_validar_estado
  BEFORE UPDATE ON public.clases
  FOR EACH ROW EXECUTE FUNCTION public.validar_cambio_estado_clase();

-- Una clase suspendida sale del flujo diario: no admite asistencia ni participación
CREATE OR REPLACE FUNCTION public.impedir_registro_clase_suspendida()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.clases WHERE id = NEW.clase_id AND estado = 'suspendida') THEN
    RAISE EXCEPTION 'La clase está suspendida: no se registra asistencia ni participación.' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER asistencia_alumnas_clase_activa
  BEFORE INSERT OR UPDATE ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.impedir_registro_clase_suspendida();
CREATE TRIGGER asistencia_tutores_clase_activa
  BEFORE INSERT OR UPDATE ON public.asistencia_tutores
  FOR EACH ROW EXECUTE FUNCTION public.impedir_registro_clase_suspendida();
CREATE TRIGGER participacion_clase_activa
  BEFORE INSERT OR UPDATE ON public.participacion_clase
  FOR EACH ROW EXECUTE FUNCTION public.impedir_registro_clase_suspendida();

-- -----------------------------------------------------------------------------
-- 8. PORCENTAJE DE ASISTENCIA SIN CLASES SUSPENDIDAS (US-03, base de US-25)
-- -----------------------------------------------------------------------------
-- Solo cuentan las clases realizadas; las suspendidas y programadas tienen
-- denominador 0. La justificada cuenta como asistencia. Se ejecuta con los
-- permisos de quien consulta, así que respeta la RLS.
CREATE OR REPLACE FUNCTION public.asistencia_inscripcion(p_inscripcion_id uuid)
RETURNS TABLE (clases_computables int, clases_asistidas int, porcentaje numeric)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT
    count(*)::int,
    count(*) FILTER (WHERE a.estado IN ('presente', 'justificada'))::int,
    CASE WHEN count(*) = 0 THEN NULL
      ELSE round(100.0 * count(*) FILTER (WHERE a.estado IN ('presente', 'justificada')) / count(*), 1)
    END
  FROM public.inscripciones i
  JOIN public.clases c ON c.instancia_curso_id = i.instancia_curso_id AND c.estado = 'realizada'
  LEFT JOIN public.asistencia_alumnas a ON a.clase_id = c.id AND a.inscripcion_id = i.id
  WHERE i.id = p_inscripcion_id;
$$;

-- -----------------------------------------------------------------------------
-- 9. PERMISOS DE LAS RPC
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.crear_instancia_curso(uuid, uuid, date, date, int, time, time, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agregar_sesion_especial(uuid, date, time, time) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crear_instancia_curso(uuid, uuid, date, date, int, time, time, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agregar_sesion_especial(uuid, date, time, time) TO authenticated;
