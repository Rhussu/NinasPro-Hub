-- =============================================================================
-- Migration: 20261101000020_reportes_portal_alertas.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Exportación, auditoría, dashboard, portal de la alumna y alertas
--              de deserción (US-21..US-27, US-39, US-40).
--
--   - Lecturas denegadas: las RPC de lectura que reciben un id ajeno registran
--     el intento en auditoria_seguridad y responden 403 (US-06 E2, US-27 E3).
--   - Alertas: un trigger sobre la asistencia detecta 3 inasistencias seguidas
--     sin justificar y mantiene una sola alerta sin atender por alumna (US-39).
--     Gestión de la sede registra el contacto con la apoderada (US-40).
--   - Portal: portal_alumna() calcula la asistencia con la recuperación por
--     ejercicios y el umbral (80 % o 70 % con un justificativo aceptado) (US-25).
--   - Dashboard: resumen_sedes() y asistencia_por_clase() (Directiva).
--   - Exportación: exportar_reporte() arma el reporte en la base y registra la
--     descarga en la misma llamada, con modo disociado (US-21, US-22).
--   - Auditoría: más tablas auditadas, bitácoras que ni el administrador puede
--     alterar y consultar_auditoria() con filtros para ARCO (US-23, US-24).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. LECTURAS DENEGADAS (US-06 E2, US-27 E3)
-- -----------------------------------------------------------------------------
ALTER TYPE public.evento_seguridad ADD VALUE IF NOT EXISTS 'acceso_denegado';

-- Registra el intento y deja la respuesta HTTP en 403. No lanza una excepción
-- para que el registro de auditoría se confirme.
CREATE OR REPLACE FUNCTION public.denegar_acceso(p_recurso text, p_id uuid, p_detalle jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.registrar_evento_seguridad(
    'acceso_denegado',
    auth.uid(),
    (SELECT p.correo FROM public.perfiles p WHERE p.id = auth.uid()),
    jsonb_build_object('recurso', p_recurso, 'id', p_id, 'rol', public.current_user_role())
      || coalesce(p_detalle, '{}'::jsonb)
  );
  PERFORM set_config('response.status', '403', true);
END;
$$;

-- Pase de lista de alumnas: solo el staff de la sede de la clase
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
  podio_kahoot int,
  justificativo_estado public.estado_justificativo,
  justificativo_motivo public.motivo_justificativo
)
LANGUAGE plpgsql SET search_path = ''
AS $$
#variable_conflict use_column
BEGIN
  IF NOT public.es_staff_sede(public.sede_clase(p_clase_id)) THEN
    PERFORM public.denegar_acceso('lista_asistencia_clase', p_clase_id);
    RETURN;
  END IF;

  RETURN QUERY
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
END;
$$;

-- Pase de lista de tutoras: solo el staff de la sede de la clase
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
LANGUAGE plpgsql SET search_path = ''
AS $$
#variable_conflict use_column
BEGIN
  IF NOT public.es_staff_sede(public.sede_clase(p_clase_id)) THEN
    PERFORM public.denegar_acceso('lista_asistencia_tutores', p_clase_id);
    RETURN;
  END IF;

  RETURN QUERY
  WITH personas AS (
    SELECT ti.tutor_id AS persona
    FROM public.clases c
    JOIN public.tutores_instancia ti ON ti.instancia_curso_id = c.instancia_curso_id
    LEFT JOIN public.voluntarios_detalle v ON v.perfil_id = ti.tutor_id
    WHERE c.id = p_clase_id AND (v.fecha_salida IS NULL OR v.fecha_salida >= c.fecha)
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
  JOIN public.perfiles p ON p.id = x.persona
  LEFT JOIN public.asistencia_tutores at ON at.clase_id = p_clase_id AND at.tutor_id = p.id
  LEFT JOIN public.perfiles r ON r.id = at.registrado_por
  ORDER BY p.nombres, p.apellidos;
END;
$$;

-- Roles de la clase: solo el staff de la sede de la clase
CREATE OR REPLACE FUNCTION public.roles_clase(p_clase_id uuid)
RETURNS TABLE (
  tutor_id uuid,
  nombres text,
  apellidos text,
  es_equipo_gestion boolean,
  tareas jsonb
)
LANGUAGE plpgsql SET search_path = ''
AS $$
#variable_conflict use_column
BEGIN
  IF NOT public.es_staff_sede(public.sede_clase(p_clase_id)) THEN
    PERFORM public.denegar_acceso('roles_clase', p_clase_id);
    RETURN;
  END IF;

  RETURN QUERY
  WITH clase AS (
    SELECT c.id, c.instancia_curso_id, c.fecha FROM public.clases c WHERE c.id = p_clase_id
  ),
  personas AS (
    SELECT ti.tutor_id AS persona
    FROM clase JOIN public.tutores_instancia ti ON ti.instancia_curso_id = clase.instancia_curso_id
    LEFT JOIN public.voluntarios_detalle v ON v.perfil_id = ti.tutor_id
    WHERE v.fecha_salida IS NULL OR v.fecha_salida >= clase.fecha
    UNION
    SELECT t.tutor_id FROM public.tareas_semanales_tutores t WHERE t.clase_id = p_clase_id
  )
  SELECT
    p.id,
    p.nombres::text,
    p.apellidos::text,
    p.rol = 'equipo_gestion',
    coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id,
        'rol_id', t.rol_tarea_tutor_id,
        'completada', t.completada
      ) ORDER BY r.es_requerido DESC, r.nombre)
      FROM public.tareas_semanales_tutores t
      JOIN public.rol_tarea_tutor r ON r.id = t.rol_tarea_tutor_id
      WHERE t.clase_id = p_clase_id AND t.tutor_id = p.id
    ), '[]'::jsonb)
  FROM personas x
  JOIN public.perfiles p ON p.id = x.persona
  ORDER BY p.nombres, p.apellidos;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. ALERTAS DE DESERCIÓN: 3 INASISTENCIAS SEGUIDAS SIN JUSTIFICAR (US-39)
-- -----------------------------------------------------------------------------
-- Una sola alerta sin atender por inscripción
CREATE UNIQUE INDEX alertas_desercion_una_activa
  ON public.alertas_desercion (inscripcion_id) WHERE NOT atendida;

ALTER TABLE public.alertas_desercion
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  ADD CONSTRAINT alertas_desercion_contacto_completo CHECK (
    NOT atendida OR (fecha_contacto IS NOT NULL AND nullif(btrim(observacion_gestion), '') IS NOT NULL)
  );

-- Racha más reciente de al menos 3 inasistencias seguidas de la inscripción.
-- Cuentan las clases no suspendidas con asistencia registrada, en orden; una
-- clase presente o justificada corta la racha (US-39 escenario 2).
CREATE OR REPLACE FUNCTION public.racha_inasistencias(p_inscripcion uuid)
RETURNS TABLE (inasistencias int, desde date, hasta date, ultima_clase uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  WITH registros AS (
    SELECT c.id, c.fecha, aa.estado, row_number() OVER (ORDER BY c.fecha, c.numero_sesion) AS n
    FROM public.asistencia_alumnas aa
    JOIN public.clases c ON c.id = aa.clase_id
    WHERE aa.inscripcion_id = p_inscripcion AND c.estado <> 'suspendida'
  ),
  islas AS (
    SELECT r.*, r.n - row_number() OVER (ORDER BY r.n) AS grupo
    FROM registros r WHERE r.estado = 'ausente'
  )
  SELECT count(*)::int, min(fecha), max(fecha), (array_agg(id ORDER BY n DESC))[1]
  FROM islas
  GROUP BY grupo
  HAVING count(*) >= 3
  ORDER BY max(fecha) DESC
  LIMIT 1;
$$;

-- Deja las alertas de la inscripción al día con su asistencia:
--   - Sin alerta para la racha: se crea (escenario 1).
--   - Con una alerta sin atender: se actualiza la última clase y el conteo, sin
--     crear otra (escenario 3).
--   - Si ya no hay racha (se justificó o corrigió una falta), la alerta sin
--     atender se elimina; la eliminación queda en la auditoría.
--   - Una alerta ya atendida no se repite para la misma racha.
CREATE OR REPLACE FUNCTION public.actualizar_alerta_desercion(p_inscripcion uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_racha record;
  v_alerta public.alertas_desercion;
  v_fecha_alerta date;
BEGIN
  SELECT * INTO v_racha FROM public.racha_inasistencias(p_inscripcion);

  SELECT a.* INTO v_alerta
  FROM public.alertas_desercion a
  WHERE a.inscripcion_id = p_inscripcion
  ORDER BY NOT a.atendida DESC, a.created_at DESC
  LIMIT 1;

  IF v_racha.inasistencias IS NULL THEN
    IF v_alerta.id IS NOT NULL AND NOT v_alerta.atendida THEN
      DELETE FROM public.alertas_desercion WHERE id = v_alerta.id;
    END IF;
    RETURN;
  END IF;

  IF v_alerta.id IS NOT NULL AND NOT v_alerta.atendida THEN
    UPDATE public.alertas_desercion
    SET clase_id = v_racha.ultima_clase,
        inasistencias_consecutivas = v_racha.inasistencias,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_alerta.id
      AND (clase_id, inasistencias_consecutivas) IS DISTINCT FROM (v_racha.ultima_clase, v_racha.inasistencias);
    RETURN;
  END IF;

  SELECT c.fecha INTO v_fecha_alerta FROM public.clases c WHERE c.id = v_alerta.clase_id;
  IF v_alerta.id IS NULL OR v_fecha_alerta < v_racha.desde THEN
    INSERT INTO public.alertas_desercion (inscripcion_id, clase_id, inasistencias_consecutivas, motivo_alerta)
    VALUES (
      p_inscripcion,
      v_racha.ultima_clase,
      v_racha.inasistencias,
      'Acumulación de ' || v_racha.inasistencias || ' inasistencias consecutivas sin justificar'
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.evaluar_alerta_desercion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.actualizar_alerta_desercion(CASE WHEN TG_OP = 'DELETE' THEN OLD.inscripcion_id ELSE NEW.inscripcion_id END);
  RETURN NULL;
END;
$$;

CREATE TRIGGER asistencia_alumnas_alerta_desercion
  AFTER INSERT OR UPDATE OF estado OR DELETE ON public.asistencia_alumnas
  FOR EACH ROW EXECUTE FUNCTION public.evaluar_alerta_desercion();

-- La suspensión de una clase cambia qué faltas son seguidas
CREATE OR REPLACE FUNCTION public.reevaluar_alertas_clase()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_inscripcion uuid;
BEGIN
  FOR v_inscripcion IN
    SELECT DISTINCT aa.inscripcion_id FROM public.asistencia_alumnas aa WHERE aa.clase_id = NEW.id
  LOOP
    PERFORM public.actualizar_alerta_desercion(v_inscripcion);
  END LOOP;
  RETURN NULL;
END;
$$;

CREATE TRIGGER clases_reevaluar_alertas
  AFTER UPDATE OF estado ON public.clases
  FOR EACH ROW WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION public.reevaluar_alertas_clase();

-- -----------------------------------------------------------------------------
-- 3. PANEL DE ALERTAS Y CONTACTO PREVENTIVO (US-40)
-- -----------------------------------------------------------------------------
-- Las alertas las escribe el sistema; el contacto, la RPC
REVOKE INSERT, UPDATE, DELETE ON public.alertas_desercion FROM anon, authenticated;

-- Gestión de la sede (o la Directiva) ve las alertas con el contacto de la
-- apoderada. security_invoker: cada rol ve lo que su RLS le permite.
CREATE VIEW public.alertas_detalle WITH (security_invoker = true) AS
SELECT
  al.id,
  al.inscripcion_id,
  i.alumna_id,
  a.nombres AS alumna_nombres,
  a.apellidos AS alumna_apellidos,
  a.rut AS alumna_rut,
  ic.id AS instancia_curso_id,
  cu.codigo AS curso_codigo,
  cu.nombre AS curso_nombre,
  ic.sede_id,
  s.nombre AS sede_nombre,
  al.clase_id,
  c.numero_sesion,
  c.fecha AS clase_fecha,
  al.inasistencias_consecutivas,
  al.motivo_alerta,
  al.atendida,
  al.fecha_contacto,
  al.observacion_gestion,
  nullif(btrim(concat_ws(' ', g.nombres, g.apellidos)), '') AS atendida_por_nombre,
  nullif(btrim(concat_ws(' ', ap.nombres, ap.apellidos)), '') AS apoderado_nombre,
  ap.telefono AS apoderado_telefono,
  ap.correo AS apoderado_correo,
  ap.parentesco AS apoderado_parentesco,
  al.created_at
FROM public.alertas_desercion al
JOIN public.inscripciones i ON i.id = al.inscripcion_id
JOIN public.alumnas a ON a.id = i.alumna_id
JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
JOIN public.cursos cu ON cu.id = ic.curso_id
JOIN public.sedes s ON s.id = ic.sede_id
JOIN public.clases c ON c.id = al.clase_id
LEFT JOIN public.apoderados ap ON ap.id = a.apoderado_id
LEFT JOIN public.perfiles g ON g.id = al.atendida_por;

REVOKE ALL ON public.alertas_detalle FROM anon, public;
GRANT SELECT ON public.alertas_detalle TO authenticated;

CREATE OR REPLACE FUNCTION public.registrar_contacto_alerta(p_id uuid, p_observacion text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_alerta public.alertas_desercion;
  v_observacion text := nullif(btrim(coalesce(p_observacion, '')), '');
BEGIN
  SELECT * INTO v_alerta FROM public.alertas_desercion WHERE id = p_id FOR UPDATE;
  IF v_alerta.id IS NULL THEN
    RAISE EXCEPTION 'La alerta no existe.' USING ERRCODE = '22023';
  END IF;
  IF NOT public.gestiona_sede(public.sede_inscripcion(v_alerta.inscripcion_id)) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede registra el contacto.' USING ERRCODE = '42501';
  END IF;
  IF v_alerta.atendida THEN
    RAISE EXCEPTION 'Esta alerta ya tiene un contacto registrado.' USING ERRCODE = '22023';
  END IF;
  IF v_observacion IS NULL THEN
    RAISE EXCEPTION 'Cuenta brevemente qué conversaste con la apoderada.' USING ERRCODE = '22023';
  END IF;
  IF length(v_observacion) > 1000 THEN
    RAISE EXCEPTION 'La observación puede tener hasta 1000 caracteres.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.alertas_desercion
  SET atendida = true,
      fecha_contacto = public.hoy_chile(),
      observacion_gestion = v_observacion,
      atendida_por = auth.uid(),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. PORTAL DE LA ALUMNA (US-25, US-26, US-27)
-- -----------------------------------------------------------------------------
-- Asistencia, cronograma con recursos, ejercicios y podios de la alumna
-- autenticada en su curso (el activo o, si se retiró, el último).
--   - Asistidas: presentes + clases justificadas recuperadas con ejercicios
--     (25 ejercicios = 1 clase, hasta 2 y nunca más que las justificadas).
--   - Umbral: el mínimo del curso, o 70 % si tiene un justificativo aceptado.
--   - Con el id de otra alumna se registra el intento y responde 403.
CREATE OR REPLACE FUNCTION public.portal_alumna(p_alumna_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_alumna_id uuid := public.alumna_actual_id();
  v_alumna public.alumnas;
  v_apoderado public.apoderados;
  v_insc public.inscripciones;
  v_hoy date := public.hoy_chile();
  v_realizadas int;
  v_presentes int;
  v_justificadas int;
  v_ejercicios int;
  v_aceptados int;
  v_total int;
  v_restantes int;
  v_minimo int;
  v_umbral int;
  v_hitos int;
  v_recuperadas int;
  v_asistidas int;
  v_curso jsonb;
  v_sesiones jsonb;
  v_podios jsonb;
BEGIN
  IF v_alumna_id IS NULL OR (p_alumna_id IS NOT NULL AND p_alumna_id <> v_alumna_id) THEN
    PERFORM public.denegar_acceso('portal_alumna', p_alumna_id);
    RETURN jsonb_build_object(
      'code', '42501',
      'message', 'Solo puedes ver tu propio portal. El intento quedó registrado.'
    );
  END IF;

  SELECT * INTO v_alumna FROM public.alumnas WHERE id = v_alumna_id;
  SELECT * INTO v_apoderado FROM public.apoderados WHERE id = v_alumna.apoderado_id;

  SELECT i.* INTO v_insc
  FROM public.inscripciones i
  JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
  WHERE i.alumna_id = v_alumna_id
  ORDER BY i.estado = 'activa' DESC, ic.fecha_inicio DESC
  LIMIT 1;

  IF v_insc.id IS NULL THEN
    RETURN jsonb_build_object(
      'alumna', jsonb_build_object(
        'id', v_alumna.id, 'nombres', v_alumna.nombres, 'apellidos', v_alumna.apellidos,
        'rut', public.formatear_rut(v_alumna.rut)
      ),
      'apoderado', jsonb_build_object(
        'nombre', btrim(concat_ws(' ', v_apoderado.nombres, v_apoderado.apellidos)),
        'telefono', v_apoderado.telefono
      ),
      'inscripcion', NULL
    );
  END IF;

  SELECT jsonb_build_object(
    'instancia_id', ic.id,
    'codigo', cu.codigo,
    'nombre', cu.nombre,
    'periodo', ic.periodo_academico,
    'seccion', ic.seccion,
    'sede_nombre', s.nombre,
    'classroom_url', ic.classroom_url,
    'juez_virtual_url', ic.juez_virtual_url,
    'porcentaje_minimo', ic.porcentaje_asistencia_minimo
  ), ic.porcentaje_asistencia_minimo
  INTO v_curso, v_minimo
  FROM public.instancias_curso ic
  JOIN public.cursos cu ON cu.id = ic.curso_id
  JOIN public.sedes s ON s.id = ic.sede_id
  WHERE ic.id = v_insc.instancia_curso_id;

  SELECT
    count(*) FILTER (WHERE c.estado = 'realizada'),
    count(*) FILTER (WHERE c.estado = 'realizada' AND aa.estado = 'presente'),
    count(*) FILTER (WHERE c.estado = 'realizada' AND aa.estado = 'justificada'),
    count(*) FILTER (WHERE c.estado <> 'suspendida'),
    count(*) FILTER (WHERE c.estado = 'programada' AND c.fecha >= v_hoy)
  INTO v_realizadas, v_presentes, v_justificadas, v_total, v_restantes
  FROM public.clases c
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = v_insc.id
  WHERE c.instancia_curso_id = v_insc.instancia_curso_id;

  SELECT coalesce(sum(pc.ejercicios_completados), 0)::int INTO v_ejercicios
  FROM public.participacion_clase pc WHERE pc.inscripcion_id = v_insc.id;

  SELECT count(*)::int INTO v_aceptados
  FROM public.justificativos_inasistencia j
  WHERE j.inscripcion_id = v_insc.id AND j.estado = 'aceptado';

  v_umbral := CASE WHEN v_aceptados > 0 THEN least(70, v_minimo) ELSE v_minimo END;
  v_hitos := least(v_ejercicios / 25, 2);
  v_recuperadas := least(v_hitos, v_justificadas);
  v_asistidas := v_presentes + v_recuperadas;

  SELECT jsonb_build_object(
    'primero', count(*) FILTER (WHERE pc.podio_kahoot = 1),
    'segundo', count(*) FILTER (WHERE pc.podio_kahoot = 2),
    'tercero', count(*) FILTER (WHERE pc.podio_kahoot = 3)
  ) INTO v_podios
  FROM public.participacion_clase pc WHERE pc.inscripcion_id = v_insc.id;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'numero_sesion', c.numero_sesion,
    'fecha', c.fecha,
    'hora_inicio', to_char(c.hora_inicio, 'HH24:MI'),
    'hora_fin', to_char(c.hora_fin, 'HH24:MI'),
    'estado', c.estado,
    'es_especial', c.es_especial,
    'motivo_suspension', c.motivo_suspension,
    'tema', pl.tema_titulo,
    'asistencia', aa.estado,
    'ejercicios', pc.ejercicios_completados,
    'recursos', coalesce((
      SELECT jsonb_agg(jsonb_build_object('id', r.id, 'titulo', r.titulo, 'tipo', r.tipo, 'url', r.url)
                       ORDER BY r.orden, r.titulo)
      FROM public.recursos_clase r WHERE r.clase_id = c.id
    ), '[]'::jsonb)
  ) ORDER BY c.fecha, c.numero_sesion), '[]'::jsonb)
  INTO v_sesiones
  FROM public.clases c
  LEFT JOIN public.planificacion_clases pl ON pl.clase_id = c.id AND pl.publicado_para_alumnas
  LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = v_insc.id
  LEFT JOIN public.participacion_clase pc ON pc.clase_id = c.id AND pc.inscripcion_id = v_insc.id
  WHERE c.instancia_curso_id = v_insc.instancia_curso_id;

  RETURN jsonb_build_object(
    'alumna', jsonb_build_object(
      'id', v_alumna.id, 'nombres', v_alumna.nombres, 'apellidos', v_alumna.apellidos,
      'rut', public.formatear_rut(v_alumna.rut)
    ),
    'apoderado', jsonb_build_object(
      'nombre', btrim(concat_ws(' ', v_apoderado.nombres, v_apoderado.apellidos)),
      'telefono', v_apoderado.telefono
    ),
    'inscripcion', jsonb_build_object('id', v_insc.id, 'estado', v_insc.estado),
    'curso', v_curso,
    'hoy', v_hoy,
    'sesiones', v_sesiones,
    'asistencia', jsonb_build_object(
      'realizadas', v_realizadas,
      'presentes', v_presentes,
      'justificadas', v_justificadas,
      'recuperadas', v_recuperadas,
      'asistidas', v_asistidas,
      'porcentaje', CASE WHEN v_realizadas = 0 THEN NULL ELSE round(v_asistidas * 100.0 / v_realizadas, 1) END,
      'umbral', v_umbral,
      'umbral_reducido', v_umbral < v_minimo,
      'justificativos_aceptados', v_aceptados,
      'total_clases', v_total,
      'restantes', v_restantes,
      -- Clases que le faltan para alcanzar el umbral sobre el total del curso (US-25 E2)
      'clases_necesarias', greatest(0, ceil(v_umbral * v_total / 100.0)::int - v_asistidas)
    ),
    'ejercicios', jsonb_build_object('total', v_ejercicios, 'hitos', v_hitos),
    'podios', v_podios
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. DASHBOARD DE LA DIRECTIVA (US-25 consola)
-- -----------------------------------------------------------------------------
-- Asistencia: presentes sobre los registros de las clases realizadas
CREATE OR REPLACE FUNCTION public.resumen_sedes()
RETURNS TABLE (
  sede_id uuid,
  nombre text,
  institucion text,
  activa boolean,
  cursos int,
  alumnas_activas int,
  asistencia_promedio numeric,
  voluntarias_activas int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT
    s.id,
    s.nombre::text,
    s.institucion_anfitriona::text,
    s.activa,
    (SELECT count(*) FROM public.instancias_curso ic WHERE ic.sede_id = s.id AND ic.activo)::int,
    (SELECT count(DISTINCT i.alumna_id)
       FROM public.inscripciones i JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
      WHERE ic.sede_id = s.id AND i.estado = 'activa')::int,
    (SELECT round(count(*) FILTER (WHERE aa.estado = 'presente') * 100.0 / nullif(count(*), 0), 1)
       FROM public.asistencia_alumnas aa
       JOIN public.clases c ON c.id = aa.clase_id
       JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
      WHERE ic.sede_id = s.id AND c.estado = 'realizada'),
    (SELECT count(*) FROM public.voluntarios_detalle v WHERE v.sede_id = s.id AND v.fecha_salida IS NULL)::int
  FROM public.sedes s
  WHERE public.gestiona_sede(s.id)
  ORDER BY s.nombre;
$$;

-- Presentes y registros de cada sede en cada día de clases realizadas
CREATE OR REPLACE FUNCTION public.asistencia_por_clase()
RETURNS TABLE (sede_id uuid, sede_nombre text, fecha date, presentes int, total int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT s.id, s.nombre::text, c.fecha,
         (count(*) FILTER (WHERE aa.estado = 'presente'))::int,
         count(*)::int
  FROM public.asistencia_alumnas aa
  JOIN public.clases c ON c.id = aa.clase_id
  JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
  JOIN public.sedes s ON s.id = ic.sede_id
  WHERE c.estado = 'realizada' AND public.gestiona_sede(s.id)
  GROUP BY s.id, s.nombre, c.fecha
  ORDER BY c.fecha, s.nombre;
$$;

-- -----------------------------------------------------------------------------
-- 6. EXPORTACIÓN FILTRADA Y DISOCIADA (US-21, US-22)
-- -----------------------------------------------------------------------------
ALTER TABLE public.auditoria_accesos_descargas
  ADD COLUMN tipo_reporte TEXT,
  -- Sin FK: la bitácora no se modifica aunque se elimine la instancia
  ADD COLUMN filtro_instancia_id UUID,
  ADD COLUMN fecha_desde DATE,
  ADD COLUMN fecha_hasta DATE,
  ADD COLUMN disociado BOOLEAN NOT NULL DEFAULT false,
  -- Alumnas identificables en el archivo (vacío si es disociado), para ARCO (US-24 E1)
  ADD COLUMN alumnas_incluidas UUID[] NOT NULL DEFAULT '{}';

CREATE INDEX auditoria_descargas_fecha_idx ON public.auditoria_accesos_descargas (fecha_hora DESC);
CREATE INDEX auditoria_descargas_alumnas_idx ON public.auditoria_accesos_descargas USING gin (alumnas_incluidas);

CREATE OR REPLACE FUNCTION public.fecha_texto(p_fecha date)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$ SELECT to_char(p_fecha, 'DD-MM-YYYY'); $$;

-- Arma el reporte (asistencia, nomina o participacion) con los filtros. Sin
-- p_vista_previa devuelve todas las filas y registra la descarga; la vista
-- previa trae solo 10 filas y no se registra.
--   - Gestión exporta solo sus sedes (US-21 E3); la Directiva, todas. La nómina
--     (con consentimientos) es de la Directiva, como su vista (migración 14).
--   - Disociado: RUT, nombres y apellidos se reemplazan por ALUMNA-001… (US-22 E1).
--   - Sin filas, el archivo lleva solo los encabezados (US-22 E3).
CREATE OR REPLACE FUNCTION public.exportar_reporte(
  p_tipo text,
  p_sede_id uuid DEFAULT NULL,
  p_instancia_id uuid DEFAULT NULL,
  p_desde date DEFAULT NULL,
  p_hasta date DEFAULT NULL,
  p_disociado boolean DEFAULT false,
  p_formato text DEFAULT 'CSV',
  p_vista_previa boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_sede uuid := p_sede_id;
  v_formato text := upper(coalesce(p_formato, 'CSV'));
  v_disociado boolean := coalesce(p_disociado, false);
  v_encabezados jsonb;
  v_filas jsonb;
  v_total int;
  v_alumnas uuid[];
  -- Posición de la columna RUT (le siguen nombres y apellidos)
  v_pos_rut int := CASE WHEN p_tipo = 'nomina' THEN 4 ELSE 6 END;
BEGIN
  IF NOT public.es_administracion() THEN
    PERFORM public.denegar_acceso('exportar_reporte', p_sede_id, jsonb_build_object('tipo', p_tipo));
    RETURN jsonb_build_object('code', '42501', 'message', 'No tienes permiso para exportar. El intento quedó registrado.');
  END IF;
  IF p_tipo IS NULL OR p_tipo NOT IN ('asistencia', 'nomina', 'participacion') THEN
    RAISE EXCEPTION 'Elige el tipo de reporte.' USING ERRCODE = '22023';
  END IF;
  IF v_formato NOT IN ('CSV', 'XLSX') THEN
    RAISE EXCEPTION 'El formato debe ser CSV o XLSX.' USING ERRCODE = '22023';
  END IF;
  IF p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_hasta < p_desde THEN
    RAISE EXCEPTION 'La fecha de término no puede ser anterior a la de inicio.' USING ERRCODE = '22023';
  END IF;

  IF p_instancia_id IS NOT NULL THEN
    SELECT ic.sede_id INTO v_sede FROM public.instancias_curso ic WHERE ic.id = p_instancia_id;
    IF v_sede IS NULL THEN
      RAISE EXCEPTION 'El curso no existe.' USING ERRCODE = '22023';
    END IF;
    IF p_sede_id IS NOT NULL AND p_sede_id <> v_sede THEN
      RAISE EXCEPTION 'El curso no pertenece a la sede elegida.' USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Gestión de una sola sede exporta su sede aunque no la elija (queda así en la bitácora)
  IF v_sede IS NULL AND NOT public.is_directorio() THEN
    SELECT (array_agg(x))[1] INTO v_sede FROM public.sedes_usuario() AS x HAVING count(*) = 1;
  END IF;

  -- Fuera de su sede: se registra el intento (US-21 E3)
  IF v_sede IS NOT NULL AND NOT public.gestiona_sede(v_sede) THEN
    PERFORM public.denegar_acceso('exportar_reporte', v_sede, jsonb_build_object('tipo', p_tipo));
    RETURN jsonb_build_object('code', '42501', 'message', 'Solo puedes exportar datos de tu sede. El intento quedó registrado.');
  END IF;

  IF to_regclass('pg_temp._reporte') IS NULL THEN
    CREATE TEMP TABLE _reporte (orden bigint, alumna_id uuid, fila jsonb) ON COMMIT DROP;
  ELSE
    TRUNCATE _reporte;
  END IF;

  IF p_tipo = 'asistencia' THEN
    v_encabezados := CASE WHEN v_disociado
      THEN '["Sede", "Curso", "Período", "Clase", "Fecha", "Alumna", "Estado"]'::jsonb
      ELSE '["Sede", "Curso", "Período", "Clase", "Fecha", "RUT", "Nombres", "Apellidos", "Estado"]'::jsonb END;
    INSERT INTO _reporte
    SELECT
      row_number() OVER (ORDER BY s.nombre, cu.codigo, ic.periodo_academico, c.fecha, c.numero_sesion, a.apellidos, a.nombres),
      a.id,
      jsonb_build_array(s.nombre, cu.codigo, concat_ws(' · ', ic.periodo_academico, CASE WHEN ic.seccion > 1 THEN 'Sección ' || ic.seccion END), c.numero_sesion::text,
                        public.fecha_texto(c.fecha), public.formatear_rut(a.rut), a.nombres, a.apellidos,
                        CASE aa.estado WHEN 'presente' THEN 'Presente' WHEN 'ausente' THEN 'Ausente'
                                       WHEN 'justificada' THEN 'Justificada' ELSE 'Sin registro' END)
    FROM public.clases c
    JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
    JOIN public.cursos cu ON cu.id = ic.curso_id
    JOIN public.sedes s ON s.id = ic.sede_id
    JOIN public.inscripciones i ON i.instancia_curso_id = ic.id
    JOIN public.alumnas a ON a.id = i.alumna_id
    LEFT JOIN public.asistencia_alumnas aa ON aa.clase_id = c.id AND aa.inscripcion_id = i.id
    WHERE c.estado = 'realizada'
      AND public.gestiona_sede(ic.sede_id)
      AND (v_sede IS NULL OR ic.sede_id = v_sede)
      AND (p_instancia_id IS NULL OR ic.id = p_instancia_id)
      AND (p_desde IS NULL OR c.fecha >= p_desde)
      AND (p_hasta IS NULL OR c.fecha <= p_hasta)
      AND (aa.id IS NOT NULL OR (i.estado = 'activa' AND i.fecha_inscripcion <= c.fecha));

  ELSIF p_tipo = 'nomina' THEN
    IF NOT public.is_directorio() THEN
      RAISE EXCEPTION 'La nómina de alumnas la exporta la Directiva.' USING ERRCODE = '42501';
    END IF;
    v_encabezados := CASE WHEN v_disociado
      THEN '["Sede", "Curso", "Período", "Alumna", "Estado", "Fecha de inscripción", "Fecha de retiro", "Tratamiento de datos", "Autoriza fotos", "Clases asistidas", "Clases realizadas"]'::jsonb
      ELSE '["Sede", "Curso", "Período", "RUT", "Nombres", "Apellidos", "Estado", "Fecha de inscripción", "Fecha de retiro", "Tratamiento de datos", "Autoriza fotos", "Clases asistidas", "Clases realizadas"]'::jsonb END;
    INSERT INTO _reporte
    SELECT
      row_number() OVER (ORDER BY n.sede_nombre, n.curso_codigo, n.periodo_academico, n.apellidos, n.nombres),
      n.alumna_id,
      jsonb_build_array(n.sede_nombre, n.curso_codigo, concat_ws(' · ', n.periodo_academico, CASE WHEN n.seccion > 1 THEN 'Sección ' || n.seccion END),
                        public.formatear_rut(n.rut), n.nombres, n.apellidos, initcap(n.estado::text),
                        public.fecha_texto(n.fecha_inscripcion), coalesce(public.fecha_texto(n.fecha_retiro), ''),
                        initcap(replace(n.tratamiento_datos::text, '_', ' ')),
                        CASE WHEN n.autoriza_fotos THEN 'Sí' ELSE 'No' END,
                        n.clases_asistidas::text, n.clases_computables::text)
    FROM public.nomina_alumnas n
    JOIN public.instancias_curso ic ON ic.id = n.instancia_curso_id
    WHERE public.gestiona_sede(n.sede_id)
      AND (v_sede IS NULL OR n.sede_id = v_sede)
      AND (p_instancia_id IS NULL OR n.instancia_curso_id = p_instancia_id)
      AND (p_desde IS NULL OR ic.fecha_termino >= p_desde)
      AND (p_hasta IS NULL OR ic.fecha_inicio <= p_hasta);

  ELSE
    v_encabezados := CASE WHEN v_disociado
      THEN '["Sede", "Curso", "Período", "Clase", "Fecha", "Alumna", "Ejercicios", "Participó activamente", "Podio Kahoot"]'::jsonb
      ELSE '["Sede", "Curso", "Período", "Clase", "Fecha", "RUT", "Nombres", "Apellidos", "Ejercicios", "Participó activamente", "Podio Kahoot"]'::jsonb END;
    INSERT INTO _reporte
    SELECT
      row_number() OVER (ORDER BY s.nombre, cu.codigo, ic.periodo_academico, c.fecha, c.numero_sesion, a.apellidos, a.nombres),
      a.id,
      jsonb_build_array(s.nombre, cu.codigo, concat_ws(' · ', ic.periodo_academico, CASE WHEN ic.seccion > 1 THEN 'Sección ' || ic.seccion END), c.numero_sesion::text,
                        public.fecha_texto(c.fecha), public.formatear_rut(a.rut), a.nombres, a.apellidos,
                        pc.ejercicios_completados::text,
                        CASE WHEN pc.participo_activa THEN 'Sí' ELSE 'No' END,
                        coalesce(pc.podio_kahoot::text || '°', ''))
    FROM public.participacion_clase pc
    JOIN public.clases c ON c.id = pc.clase_id
    JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
    JOIN public.cursos cu ON cu.id = ic.curso_id
    JOIN public.sedes s ON s.id = ic.sede_id
    JOIN public.inscripciones i ON i.id = pc.inscripcion_id
    JOIN public.alumnas a ON a.id = i.alumna_id
    WHERE public.gestiona_sede(ic.sede_id)
      AND (v_sede IS NULL OR ic.sede_id = v_sede)
      AND (p_instancia_id IS NULL OR ic.id = p_instancia_id)
      AND (p_desde IS NULL OR c.fecha >= p_desde)
      AND (p_hasta IS NULL OR c.fecha <= p_hasta);
  END IF;

  -- Disociado: las columnas RUT, nombres y apellidos pasan a un código por
  -- alumna, el mismo en todo el archivo
  IF v_disociado THEN
    UPDATE _reporte r
    SET fila = (
      SELECT jsonb_agg(x.valor ORDER BY x.pos)
      FROM (
        SELECT e.valor, e.pos FROM jsonb_array_elements(r.fila) WITH ORDINALITY AS e(valor, pos)
        WHERE e.pos NOT BETWEEN v_pos_rut AND v_pos_rut + 2
        UNION ALL
        SELECT to_jsonb('ALUMNA-' || lpad(d.codigo::text, 3, '0')), v_pos_rut
      ) x
    )
    FROM (SELECT alumna_id, dense_rank() OVER (ORDER BY min(orden)) AS codigo FROM _reporte GROUP BY alumna_id) d
    WHERE d.alumna_id = r.alumna_id;
  END IF;

  SELECT count(*)::int,
         coalesce(jsonb_agg(fila ORDER BY orden) FILTER (WHERE NOT p_vista_previa OR orden <= 10), '[]'::jsonb),
         coalesce(array_agg(DISTINCT alumna_id) FILTER (WHERE NOT v_disociado), '{}')
  INTO v_total, v_filas, v_alumnas
  FROM _reporte;

  IF NOT p_vista_previa THEN
    INSERT INTO public.auditoria_accesos_descargas (
      usuario_id, tipo_operacion, tipo_reporte, filtro_sede_id, filtro_curso_id, filtro_instancia_id,
      periodo_filtrado, fecha_desde, fecha_hasta, formato_archivo, cantidad_registros, disociado, alumnas_incluidas
    )
    SELECT auth.uid(), 'exportacion', p_tipo, v_sede, ic.curso_id, p_instancia_id,
           left(ic.periodo_academico, 20), p_desde, p_hasta, v_formato, v_total, v_disociado, v_alumnas
    FROM (SELECT 1) uno
    LEFT JOIN public.instancias_curso ic ON ic.id = p_instancia_id;
  END IF;

  RETURN jsonb_build_object('encabezados', v_encabezados, 'filas', v_filas, 'total', v_total);
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. AUDITORÍA DE CAMBIOS EN LOS DATOS DE LAS ALUMNAS (US-23)
-- -----------------------------------------------------------------------------
CREATE TRIGGER alumnas_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.alumnas
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER apoderados_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.apoderados
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER inscripciones_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.inscripciones
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER autorizaciones_apoderado_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.autorizaciones_apoderado
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER autorizaciones_imagen_canales_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.autorizaciones_imagen_canales
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER alertas_desercion_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.alertas_desercion
  FOR EACH ROW EXECUTE FUNCTION public.auditar();

-- Ni siquiera el administrador de la base reescribe la historia (US-23 E2)
CREATE OR REPLACE FUNCTION public.impedir_cambios_auditoria()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'La bitácora de auditoría es inmutable: no se puede modificar ni eliminar.'
    USING ERRCODE = '42501';
END;
$$;

CREATE TRIGGER auditoria_cambios_inmutable
  BEFORE UPDATE OR DELETE ON public.auditoria_cambios_datos
  FOR EACH ROW EXECUTE FUNCTION public.impedir_cambios_auditoria();
CREATE TRIGGER auditoria_cambios_sin_truncate
  BEFORE TRUNCATE ON public.auditoria_cambios_datos
  FOR EACH STATEMENT EXECUTE FUNCTION public.impedir_cambios_auditoria();
CREATE TRIGGER auditoria_descargas_inmutable
  BEFORE UPDATE OR DELETE ON public.auditoria_accesos_descargas
  FOR EACH ROW EXECUTE FUNCTION public.impedir_cambios_auditoria();
CREATE TRIGGER auditoria_descargas_sin_truncate
  BEFORE TRUNCATE ON public.auditoria_accesos_descargas
  FOR EACH STATEMENT EXECUTE FUNCTION public.impedir_cambios_auditoria();
CREATE TRIGGER auditoria_seguridad_inmutable
  BEFORE UPDATE OR DELETE ON public.auditoria_seguridad
  FOR EACH ROW EXECUTE FUNCTION public.impedir_cambios_auditoria();
CREATE TRIGGER auditoria_seguridad_sin_truncate
  BEFORE TRUNCATE ON public.auditoria_seguridad
  FOR EACH STATEMENT EXECUTE FUNCTION public.impedir_cambios_auditoria();

-- -----------------------------------------------------------------------------
-- 8. CONSULTA DE LA AUDITORÍA (US-24)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.etiqueta_tabla_auditada(p_tabla text)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT CASE p_tabla
    WHEN 'asistencia_alumnas' THEN 'Asistencia de alumna'
    WHEN 'participacion_clase' THEN 'Participación en clase'
    WHEN 'justificativos_inasistencia' THEN 'Justificativo'
    WHEN 'alertas_desercion' THEN 'Alerta de deserción'
    WHEN 'alumnas' THEN 'Ficha de alumna'
    WHEN 'apoderados' THEN 'Apoderado/a'
    WHEN 'inscripciones' THEN 'Inscripción'
    WHEN 'autorizaciones_apoderado' THEN 'Autorizaciones del apoderado'
    WHEN 'autorizaciones_imagen_canales' THEN 'Autorización de imagen por canal'
    WHEN 'asistencia_tutores' THEN 'Asistencia de tutora'
    WHEN 'evidencias_fotograficas' THEN 'Foto de evidencia'
    WHEN 'voluntarios_detalle' THEN 'Ficha de voluntariado'
    WHEN 'tutores_instancia' THEN 'Asignación de tutora a curso'
    WHEN 'rol_tarea_tutor' THEN 'Catálogo de roles de tutoras'
    WHEN 'tareas_semanales_tutores' THEN 'Rol de tutora en una clase'
    ELSE p_tabla
  END;
$$;

-- Campos que cambiaron en un UPDATE: "estado: ausente → presente" (hasta 4)
CREATE OR REPLACE FUNCTION public.campos_cambiados(p_anterior jsonb, p_nuevo jsonb)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT string_agg(format('%s: %s → %s', k, coalesce(p_anterior ->> k, '∅'), coalesce(p_nuevo ->> k, '∅')), '; ')
  FROM (
    SELECT k FROM jsonb_object_keys(coalesce(p_nuevo, '{}'::jsonb)) AS k
    WHERE k NOT IN ('updated_at', 'created_at', 'fecha_modificacion')
      AND (p_anterior -> k) IS DISTINCT FROM (p_nuevo -> k)
    ORDER BY k
    LIMIT 4
  ) campos;
$$;

-- Bitácora unificada: cambios de datos, descargas y eventos de seguridad, del
-- más reciente al más antiguo (hasta p_limite).
--   - Directiva: todo. Gestión: solo lo ocurrido en sus sedes (US-24 E3).
--   - p_usuaria filtra por nombre o correo; p_rut, por la alumna (ARCO, E1).
--   - p_tipo: modificacion, exportacion, acceso_denegado o seguridad.
CREATE OR REPLACE FUNCTION public.consultar_auditoria(
  p_desde date DEFAULT NULL,
  p_hasta date DEFAULT NULL,
  p_usuaria text DEFAULT NULL,
  p_tipo text DEFAULT NULL,
  p_rut text DEFAULT NULL,
  p_limite int DEFAULT 500
)
RETURNS TABLE (
  id uuid,
  fecha_hora timestamptz,
  tipo text,
  usuaria_nombre text,
  usuaria_correo text,
  sede_id uuid,
  sede_nombre text,
  descripcion text,
  alumna_rut text,
  alumna_nombre text,
  detalle jsonb
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_directiva boolean := public.is_directorio();
  v_alumna uuid;
  v_usuaria text := nullif(btrim(coalesce(p_usuaria, '')), '');
BEGIN
  IF NOT public.es_administracion() THEN
    PERFORM public.denegar_acceso('consultar_auditoria', NULL);
    RETURN;
  END IF;
  IF p_tipo IS NOT NULL AND p_tipo NOT IN ('modificacion', 'exportacion', 'acceso_denegado', 'seguridad') THEN
    RAISE EXCEPTION 'Tipo de acción desconocido.' USING ERRCODE = '22023';
  END IF;

  IF nullif(btrim(coalesce(p_rut, '')), '') IS NOT NULL THEN
    SELECT a.id INTO v_alumna FROM public.alumnas a
    WHERE public.normalizar_rut(a.rut) = public.normalizar_rut(p_rut);
    -- RUT sin ficha: no hay eventos de esa alumna
    IF v_alumna IS NULL THEN
      RETURN;
    END IF;
  END IF;

  RETURN QUERY
  WITH cambios AS (
    SELECT
      c.id, c.fecha_hora, 'modificacion'::text AS tipo, c.ejecutado_por AS usuaria_id, NULL::text AS correo,
      coalesce(
        public.sede_clase((coalesce(c.valor_nuevo, c.valor_anterior) ->> 'clase_id')::uuid),
        public.sede_inscripcion((coalesce(c.valor_nuevo, c.valor_anterior) ->> 'inscripcion_id')::uuid),
        public.sede_instancia((coalesce(c.valor_nuevo, c.valor_anterior) ->> 'instancia_curso_id')::uuid),
        (coalesce(c.valor_nuevo, c.valor_anterior) ->> 'sede_id')::uuid,
        (SELECT ic.sede_id FROM public.inscripciones i JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
          WHERE i.alumna_id = al.alumna ORDER BY i.created_at DESC LIMIT 1)
      ) AS sede,
      public.etiqueta_tabla_auditada(c.tabla_afectada) || ': '
        || CASE c.accion WHEN 'insert' THEN 'registro creado' WHEN 'delete' THEN 'registro eliminado'
           ELSE coalesce(public.campos_cambiados(c.valor_anterior, c.valor_nuevo), 'registro modificado') END
        AS descripcion,
      al.alumna,
      jsonb_build_object('tabla', c.tabla_afectada, 'accion', c.accion, 'registro_id', c.registro_id,
                         'anterior', c.valor_anterior, 'nuevo', c.valor_nuevo, 'ip', c.ip_address) AS detalle
    FROM public.auditoria_cambios_datos c
    LEFT JOIN LATERAL (
      SELECT coalesce(
        (SELECT i.alumna_id FROM public.inscripciones i
          WHERE i.id = (coalesce(c.valor_nuevo, c.valor_anterior) ->> 'inscripcion_id')::uuid),
        (coalesce(c.valor_nuevo, c.valor_anterior) ->> 'alumna_id')::uuid,
        CASE WHEN c.tabla_afectada = 'alumnas' THEN c.registro_id END,
        CASE WHEN c.tabla_afectada = 'apoderados' THEN
          (SELECT a.id FROM public.alumnas a WHERE a.apoderado_id = c.registro_id ORDER BY a.created_at LIMIT 1) END,
        CASE WHEN c.tabla_afectada = 'autorizaciones_imagen_canales' THEN
          (SELECT au.alumna_id FROM public.autorizaciones_apoderado au
            WHERE au.id = (coalesce(c.valor_nuevo, c.valor_anterior) ->> 'autorizacion_id')::uuid) END
      ) AS alumna
    ) al ON true
    WHERE (p_tipo IS NULL OR p_tipo = 'modificacion')
      AND (v_alumna IS NULL OR al.alumna = v_alumna)
      AND (p_desde IS NULL OR (c.fecha_hora AT TIME ZONE 'America/Santiago')::date >= p_desde)
      AND (p_hasta IS NULL OR (c.fecha_hora AT TIME ZONE 'America/Santiago')::date <= p_hasta)
  ),
  descargas AS (
    SELECT
      d.id, d.fecha_hora, 'exportacion'::text AS tipo, d.usuario_id AS usuaria_id, NULL::text AS correo,
      d.filtro_sede_id AS sede,
      format('Exportó %s en %s: %s filas%s%s%s',
        CASE d.tipo_reporte WHEN 'asistencia' THEN 'asistencia' WHEN 'nomina' THEN 'la nómina de alumnas'
             WHEN 'participacion' THEN 'participación y ejercicios' ELSE coalesce(d.tipo_reporte, d.tipo_operacion) END,
        coalesce(d.formato_archivo, '—'),
        d.cantidad_registros,
        CASE WHEN d.disociado THEN ', disociado' ELSE '' END,
        CASE WHEN cu.codigo IS NOT NULL THEN ' · curso ' || cu.codigo ELSE '' END,
        CASE WHEN d.fecha_desde IS NOT NULL OR d.fecha_hasta IS NOT NULL
             THEN ' · ' || coalesce(public.fecha_texto(d.fecha_desde), '…') || ' a ' || coalesce(public.fecha_texto(d.fecha_hasta), '…')
             ELSE '' END) AS descripcion,
      v_alumna AS alumna,
      jsonb_build_object('tipo_reporte', d.tipo_reporte, 'formato', d.formato_archivo, 'filas', d.cantidad_registros,
                         'disociado', d.disociado, 'instancia_id', d.filtro_instancia_id) AS detalle
    FROM public.auditoria_accesos_descargas d
    LEFT JOIN public.cursos cu ON cu.id = d.filtro_curso_id
    WHERE (p_tipo IS NULL OR p_tipo = 'exportacion')
      AND (v_alumna IS NULL OR v_alumna = ANY (d.alumnas_incluidas))
      AND (p_desde IS NULL OR (d.fecha_hora AT TIME ZONE 'America/Santiago')::date >= p_desde)
      AND (p_hasta IS NULL OR (d.fecha_hora AT TIME ZONE 'America/Santiago')::date <= p_hasta)
  ),
  seguridad AS (
    SELECT
      s.id, s.fecha_hora,
      CASE WHEN s.evento = 'acceso_denegado' THEN 'acceso_denegado' ELSE 'seguridad' END AS tipo,
      s.usuario_id AS usuaria_id, s.correo::text AS correo,
      CASE WHEN s.detalle ->> 'recurso' IN ('lista_asistencia_clase', 'lista_asistencia_tutores', 'roles_clase')
           THEN public.sede_clase((s.detalle ->> 'id')::uuid)
           WHEN s.detalle ->> 'recurso' = 'exportar_reporte' THEN (s.detalle ->> 'id')::uuid
           ELSE (s.detalle ->> 'sede_id')::uuid END AS sede,
      CASE s.evento
        WHEN 'registro_rechazado' THEN 'Registro rechazado: el correo no estaba autorizado'
        WHEN 'cuenta_bloqueada' THEN 'Cuenta bloqueada tras 3 intentos fallidos'
        WHEN 'autorizacion_denegada' THEN 'Intento de autorizar un acceso sin permiso'
        ELSE 'Acceso denegado: ' || CASE s.detalle ->> 'recurso'
          WHEN 'portal_alumna' THEN 'portal de otra alumna'
          WHEN 'lista_asistencia_clase' THEN 'pase de lista de otra sede'
          WHEN 'lista_asistencia_tutores' THEN 'asistencia de tutoras de otra sede'
          WHEN 'roles_clase' THEN 'roles de una clase de otra sede'
          WHEN 'exportar_reporte' THEN 'exportación fuera de su alcance'
          WHEN 'consultar_auditoria' THEN 'bitácora de auditoría'
          ELSE coalesce(s.detalle ->> 'recurso', 'recurso protegido') END
      END AS descripcion,
      CASE WHEN s.detalle ->> 'recurso' = 'portal_alumna' THEN (s.detalle ->> 'id')::uuid END AS alumna,
      s.detalle AS detalle
    FROM public.auditoria_seguridad s
    WHERE (p_tipo IS NULL OR p_tipo IN ('seguridad', 'acceso_denegado'))
      AND (p_tipo IS NULL OR (p_tipo = 'acceso_denegado') = (s.evento = 'acceso_denegado'))
      AND (p_desde IS NULL OR (s.fecha_hora AT TIME ZONE 'America/Santiago')::date >= p_desde)
      AND (p_hasta IS NULL OR (s.fecha_hora AT TIME ZONE 'America/Santiago')::date <= p_hasta)
  ),
  eventos AS (
    SELECT * FROM cambios
    UNION ALL
    SELECT * FROM descargas
    UNION ALL
    SELECT * FROM seguridad WHERE v_alumna IS NULL OR seguridad.alumna = v_alumna
  )
  SELECT
    e.id,
    e.fecha_hora,
    e.tipo,
    coalesce(nullif(btrim(concat_ws(' ', p.nombres, p.apellidos)), ''),
             CASE WHEN e.usuaria_id IS NULL AND e.correo IS NULL THEN 'Sistema' END, e.correo),
    coalesce(p.correo::text, e.correo),
    e.sede,
    sd.nombre::text,
    e.descripcion,
    public.formatear_rut(a.rut),
    nullif(btrim(concat_ws(' ', a.nombres, a.apellidos)), ''),
    e.detalle
  FROM eventos e
  LEFT JOIN public.perfiles p ON p.id = e.usuaria_id
  LEFT JOIN public.sedes sd ON sd.id = e.sede
  LEFT JOIN public.alumnas a ON a.id = e.alumna
  WHERE (v_directiva OR (e.sede IS NOT NULL AND public.gestiona_sede(e.sede)))
    AND (v_usuaria IS NULL
         OR concat_ws(' ', p.nombres, p.apellidos) ILIKE '%' || v_usuaria || '%'
         OR coalesce(p.correo::text, e.correo) ILIKE '%' || v_usuaria || '%')
  ORDER BY e.fecha_hora DESC
  LIMIT greatest(1, least(coalesce(p_limite, 500), 2000));
END;
$$;

-- -----------------------------------------------------------------------------
-- 9. PERMISOS
-- -----------------------------------------------------------------------------
-- Las RPC de lectura se ejecutan con el rol de la usuaria y la llaman; solo
-- registra intentos a nombre de quien la invoca
REVOKE ALL ON FUNCTION public.denegar_acceso(text, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.denegar_acceso(text, uuid, jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.racha_inasistencias(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.actualizar_alerta_desercion(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.evaluar_alerta_desercion() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reevaluar_alertas_clase() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.impedir_cambios_auditoria() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.etiqueta_tabla_auditada(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.campos_cambiados(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fecha_texto(date) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.lista_asistencia_clase(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lista_asistencia_tutores(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.roles_clase(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_contacto_alerta(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.portal_alumna(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.resumen_sedes() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.asistencia_por_clase() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.exportar_reporte(text, uuid, uuid, date, date, boolean, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.consultar_auditoria(date, date, text, text, text, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.lista_asistencia_clase(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lista_asistencia_tutores(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.roles_clase(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_contacto_alerta(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.portal_alumna(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resumen_sedes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.asistencia_por_clase() TO authenticated;
GRANT EXECUTE ON FUNCTION public.exportar_reporte(text, uuid, uuid, date, date, boolean, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_auditoria(date, date, text, text, text, int) TO authenticated;
