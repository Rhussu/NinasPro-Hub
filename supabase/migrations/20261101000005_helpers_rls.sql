-- =============================================================================
-- Migration: 20261101000005_helpers_rls.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Funciones auxiliares SECURITY DEFINER y políticas RLS por rol y
--              sede (RNF-S-2, US-06, US-17, US-27, US-38).
--
-- Modelo de acceso:
--   directorio      -> acceso nacional (todas las sedes)
--   equipo_gestion  -> gestiona las sedes asignadas en usuarios_sedes
--   tutora          -> opera las clases de sus sedes (asistencia, participación)
--   alumna          -> solo sus propios datos e instancias en que está inscrita
--   comunicacion    -> catálogo y evidencias aptas
--
-- Las políticas nunca consultan directamente una tabla con RLS desde su misma
-- política: usan estas funciones, que se ejecutan como su dueño y evitan la
-- recursión infinita (42P17) que tenía la política anterior de perfiles.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FUNCIONES AUXILIARES
-- -----------------------------------------------------------------------------

-- Rol de la usuaria autenticada; NULL si no tiene perfil o está inactiva
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.rol_usuario
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT rol FROM public.perfiles WHERE id = auth.uid() AND activo;
$$;

CREATE OR REPLACE FUNCTION public.is_directorio()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce(public.current_user_role() = 'directorio', false);
$$;

CREATE OR REPLACE FUNCTION public.es_equipo_gestion()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce(public.current_user_role() = 'equipo_gestion', false);
$$;

-- Directorio o equipo de gestión (pueden administrar datos de alumnas y voluntariado)
CREATE OR REPLACE FUNCTION public.es_administracion()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce(public.current_user_role() IN ('directorio', 'equipo_gestion'), false);
$$;

-- Sedes asignadas a la usuaria autenticada
CREATE OR REPLACE FUNCTION public.sedes_usuario()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT us.sede_id FROM public.usuarios_sedes us WHERE us.perfil_id = auth.uid();
$$;

-- Directorio, o gestión/tutora asignada a la sede
CREATE OR REPLACE FUNCTION public.es_staff_sede(p_sede uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.is_directorio()
    OR (
      coalesce(public.current_user_role() IN ('equipo_gestion', 'tutora'), false)
      AND p_sede IN (SELECT public.sedes_usuario())
    );
$$;

-- Directorio, o equipo de gestión asignado a la sede
CREATE OR REPLACE FUNCTION public.gestiona_sede(p_sede uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.is_directorio()
    OR (public.es_equipo_gestion() AND p_sede IN (SELECT public.sedes_usuario()));
$$;

CREATE OR REPLACE FUNCTION public.sede_instancia(p_instancia uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT sede_id FROM public.instancias_curso WHERE id = p_instancia;
$$;

CREATE OR REPLACE FUNCTION public.sede_clase(p_clase uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT ic.sede_id
  FROM public.clases c JOIN public.instancias_curso ic ON ic.id = c.instancia_curso_id
  WHERE c.id = p_clase;
$$;

CREATE OR REPLACE FUNCTION public.sede_inscripcion(p_inscripcion uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT ic.sede_id
  FROM public.inscripciones i JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
  WHERE i.id = p_inscripcion;
$$;

-- Ficha de alumna vinculada a la cuenta autenticada
CREATE OR REPLACE FUNCTION public.alumna_actual_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT a.id FROM public.alumnas a
  WHERE a.perfil_usuario_id = auth.uid() AND public.current_user_role() = 'alumna';
$$;

CREATE OR REPLACE FUNCTION public.inscripcion_propia(p_inscripcion uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.inscripciones i
    WHERE i.id = p_inscripcion AND i.alumna_id = public.alumna_actual_id()
  );
$$;

-- La alumna autenticada está (o estuvo) inscrita en la instancia (US-26: las
-- retiradas conservan lectura de su material)
CREATE OR REPLACE FUNCTION public.alumna_inscrita_en(p_instancia uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.inscripciones i
    WHERE i.instancia_curso_id = p_instancia AND i.alumna_id = public.alumna_actual_id()
  );
$$;

-- Puede ver la instancia: staff de su sede o alumna inscrita
CREATE OR REPLACE FUNCTION public.puede_ver_instancia(p_instancia uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.es_staff_sede(public.sede_instancia(p_instancia))
    OR public.alumna_inscrita_en(p_instancia);
$$;

-- Puede ver la ficha de la alumna: ella misma, directorio o staff de una sede donde tenga inscripción
CREATE OR REPLACE FUNCTION public.alumna_visible(p_alumna uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT p_alumna = public.alumna_actual_id()
    OR public.is_directorio()
    OR EXISTS (
      SELECT 1 FROM public.inscripciones i
      JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
      WHERE i.alumna_id = p_alumna AND public.es_staff_sede(ic.sede_id)
    );
$$;

-- Puede administrar la ficha de la alumna: directorio o gestión de una sede donde tenga inscripción
CREATE OR REPLACE FUNCTION public.gestiona_alumna(p_alumna uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.is_directorio()
    OR EXISTS (
      SELECT 1 FROM public.inscripciones i
      JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
      WHERE i.alumna_id = p_alumna AND public.gestiona_sede(ic.sede_id)
    );
$$;

-- El perfil comparte alguna sede con la usuaria autenticada (o es directorio)
CREATE OR REPLACE FUNCTION public.perfil_en_mis_sedes(p_perfil uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.is_directorio()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_sedes us
      WHERE us.perfil_id = p_perfil AND public.es_staff_sede(us.sede_id)
    );
$$;

CREATE OR REPLACE FUNCTION public.gestiona_perfil(p_perfil uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.is_directorio()
    OR EXISTS (
      SELECT 1 FROM public.usuarios_sedes us
      WHERE us.perfil_id = p_perfil AND public.gestiona_sede(us.sede_id)
    );
$$;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- -----------------------------------------------------------------------------
-- 2. ESCALAMIENTO DE PRIVILEGIOS (US-04): solo la Directiva otorga roles de
--    administración o cambia el rol de un perfil existente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proteger_rol_perfil()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Operaciones del sistema (service role, triggers de auth) no tienen auth.uid()
  IF auth.uid() IS NULL OR public.is_directorio() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' AND NEW.rol IN ('directorio', 'equipo_gestion') THEN
    RAISE EXCEPTION 'Solo la Directiva puede crear perfiles con rol %', NEW.rol
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.rol IS DISTINCT FROM OLD.rol THEN
    RAISE EXCEPTION 'Solo la Directiva puede cambiar el rol de un perfil'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER perfiles_proteger_rol
  BEFORE INSERT OR UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.proteger_rol_perfil();

-- -----------------------------------------------------------------------------
-- 3. ELIMINAR POLÍTICAS BASE ANTERIORES
-- -----------------------------------------------------------------------------
DROP POLICY "Usuarios pueden consultar su propio perfil" ON public.perfiles;
DROP POLICY "Directorio y gestión tienen acceso completo a perfiles" ON public.perfiles;
DROP POLICY "Lectura de instancias de curso para usuarios autenticados" ON public.instancias_curso;
DROP POLICY "Alumnas solo pueden consultar su propia ficha" ON public.alumnas;
DROP POLICY "Docencia y gestión pueden consultar alumnas" ON public.alumnas;

-- -----------------------------------------------------------------------------
-- 4. IDENTIDAD Y VOLUNTARIADO
-- -----------------------------------------------------------------------------
CREATE POLICY perfiles_select ON public.perfiles FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.perfil_en_mis_sedes(id));
CREATE POLICY perfiles_insert ON public.perfiles FOR INSERT TO authenticated
  WITH CHECK (public.es_administracion());
CREATE POLICY perfiles_update ON public.perfiles FOR UPDATE TO authenticated
  USING (public.gestiona_perfil(id)) WITH CHECK (public.gestiona_perfil(id) OR public.es_administracion());
CREATE POLICY perfiles_delete ON public.perfiles FOR DELETE TO authenticated
  USING (public.is_directorio());

CREATE POLICY voluntarios_select ON public.voluntarios_detalle FOR SELECT TO authenticated
  USING (perfil_id = auth.uid() OR public.perfil_en_mis_sedes(perfil_id));
CREATE POLICY voluntarios_write ON public.voluntarios_detalle FOR ALL TO authenticated
  USING (public.gestiona_perfil(perfil_id)) WITH CHECK (public.gestiona_perfil(perfil_id));

CREATE POLICY sedes_write ON public.sedes FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

CREATE POLICY usuarios_sedes_select ON public.usuarios_sedes FOR SELECT TO authenticated
  USING (perfil_id = auth.uid() OR public.es_staff_sede(sede_id));
CREATE POLICY usuarios_sedes_write ON public.usuarios_sedes FOR ALL TO authenticated
  USING (public.gestiona_sede(sede_id)) WITH CHECK (public.gestiona_sede(sede_id));

-- -----------------------------------------------------------------------------
-- 5. ESTRUCTURA ACADÉMICA
-- -----------------------------------------------------------------------------
CREATE POLICY cursos_write ON public.cursos FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

CREATE POLICY instancias_select ON public.instancias_curso FOR SELECT TO authenticated
  USING (public.es_staff_sede(sede_id) OR public.alumna_inscrita_en(id) OR public.current_user_role() = 'comunicacion');
CREATE POLICY instancias_write ON public.instancias_curso FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

CREATE POLICY tutores_instancia_select ON public.tutores_instancia FOR SELECT TO authenticated
  USING (tutor_id = auth.uid() OR public.es_staff_sede(public.sede_instancia(instancia_curso_id)));
CREATE POLICY tutores_instancia_write ON public.tutores_instancia FOR ALL TO authenticated
  USING (public.gestiona_sede(public.sede_instancia(instancia_curso_id)))
  WITH CHECK (public.gestiona_sede(public.sede_instancia(instancia_curso_id)));

CREATE POLICY rol_tarea_tutor_write ON public.rol_tarea_tutor FOR ALL TO authenticated
  USING (public.is_directorio()) WITH CHECK (public.is_directorio());

-- -----------------------------------------------------------------------------
-- 6. ALUMNAS, APODERADOS Y AUTORIZACIONES (datos de menores: mínimo privilegio)
-- -----------------------------------------------------------------------------
CREATE POLICY alumnas_select ON public.alumnas FOR SELECT TO authenticated
  USING (public.alumna_visible(id));
CREATE POLICY alumnas_insert ON public.alumnas FOR INSERT TO authenticated
  WITH CHECK (public.es_administracion());
CREATE POLICY alumnas_update ON public.alumnas FOR UPDATE TO authenticated
  USING (public.gestiona_alumna(id)) WITH CHECK (public.gestiona_alumna(id));
CREATE POLICY alumnas_delete ON public.alumnas FOR DELETE TO authenticated
  USING (public.is_directorio());

-- Contacto del apoderado: solo administración (las tutoras no lo necesitan)
CREATE POLICY apoderados_select ON public.apoderados FOR SELECT TO authenticated
  USING (
    public.is_directorio()
    OR EXISTS (SELECT 1 FROM public.alumnas a WHERE a.apoderado_id = apoderados.id AND public.gestiona_alumna(a.id))
  );
CREATE POLICY apoderados_insert ON public.apoderados FOR INSERT TO authenticated
  WITH CHECK (public.es_administracion());
CREATE POLICY apoderados_update ON public.apoderados FOR UPDATE TO authenticated
  USING (
    public.is_directorio()
    OR EXISTS (SELECT 1 FROM public.alumnas a WHERE a.apoderado_id = apoderados.id AND public.gestiona_alumna(a.id))
  );

CREATE POLICY autorizaciones_select ON public.autorizaciones_apoderado FOR SELECT TO authenticated
  USING (public.alumna_visible(alumna_id) AND public.current_user_role() <> 'alumna');
CREATE POLICY autorizaciones_write ON public.autorizaciones_apoderado FOR ALL TO authenticated
  USING (public.gestiona_alumna(alumna_id))
  WITH CHECK (public.gestiona_alumna(alumna_id));

CREATE POLICY autorizaciones_canales_select ON public.autorizaciones_imagen_canales FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.autorizaciones_apoderado aa
    WHERE aa.id = autorizacion_id AND public.alumna_visible(aa.alumna_id) AND public.current_user_role() <> 'alumna'
  ));
CREATE POLICY autorizaciones_canales_write ON public.autorizaciones_imagen_canales FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.autorizaciones_apoderado aa
    WHERE aa.id = autorizacion_id AND public.gestiona_alumna(aa.alumna_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.autorizaciones_apoderado aa
    WHERE aa.id = autorizacion_id AND public.gestiona_alumna(aa.alumna_id)
  ));

CREATE POLICY inscripciones_select ON public.inscripciones FOR SELECT TO authenticated
  USING (public.es_staff_sede(public.sede_instancia(instancia_curso_id)) OR alumna_id = public.alumna_actual_id());
CREATE POLICY inscripciones_write ON public.inscripciones FOR ALL TO authenticated
  USING (public.gestiona_sede(public.sede_instancia(instancia_curso_id)))
  WITH CHECK (public.gestiona_sede(public.sede_instancia(instancia_curso_id)));

-- -----------------------------------------------------------------------------
-- 7. CLASES, PLANIFICACIÓN Y TAREAS
-- -----------------------------------------------------------------------------
CREATE POLICY clases_select ON public.clases FOR SELECT TO authenticated
  USING (public.puede_ver_instancia(instancia_curso_id));
CREATE POLICY clases_insert ON public.clases FOR INSERT TO authenticated
  WITH CHECK (public.gestiona_sede(public.sede_instancia(instancia_curso_id)));
-- Tutoras actualizan el estado de la clase al pasar lista; gestión suspende (US-03, US-13)
CREATE POLICY clases_update ON public.clases FOR UPDATE TO authenticated
  USING (public.es_staff_sede(public.sede_instancia(instancia_curso_id)))
  WITH CHECK (public.es_staff_sede(public.sede_instancia(instancia_curso_id)));
CREATE POLICY clases_delete ON public.clases FOR DELETE TO authenticated
  USING (public.gestiona_sede(public.sede_instancia(instancia_curso_id)));

CREATE POLICY planificacion_select ON public.planificacion_clases FOR SELECT TO authenticated
  USING (
    public.es_staff_sede(public.sede_clase(clase_id))
    OR (publicado_para_alumnas AND EXISTS (
      SELECT 1 FROM public.clases c WHERE c.id = clase_id AND public.alumna_inscrita_en(c.instancia_curso_id)
    ))
  );
CREATE POLICY planificacion_write ON public.planificacion_clases FOR ALL TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));

CREATE POLICY recursos_select ON public.recursos_clase FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.clases c WHERE c.id = clase_id AND public.puede_ver_instancia(c.instancia_curso_id)));
CREATE POLICY recursos_write ON public.recursos_clase FOR ALL TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));

CREATE POLICY tareas_select ON public.tareas_semanales_tutores FOR SELECT TO authenticated
  USING (tutor_id = auth.uid() OR public.es_staff_sede(public.sede_clase(clase_id)));
CREATE POLICY tareas_insert ON public.tareas_semanales_tutores FOR INSERT TO authenticated
  WITH CHECK (public.gestiona_sede(public.sede_clase(clase_id)));
-- La tutora marca el cumplimiento de su propia tarea (US-44)
CREATE POLICY tareas_update ON public.tareas_semanales_tutores FOR UPDATE TO authenticated
  USING (tutor_id = auth.uid() OR public.gestiona_sede(public.sede_clase(clase_id)))
  WITH CHECK (tutor_id = auth.uid() OR public.gestiona_sede(public.sede_clase(clase_id)));
CREATE POLICY tareas_delete ON public.tareas_semanales_tutores FOR DELETE TO authenticated
  USING (public.gestiona_sede(public.sede_clase(clase_id)));

-- -----------------------------------------------------------------------------
-- 8. ASISTENCIA, JUSTIFICATIVOS Y PARTICIPACIÓN
-- -----------------------------------------------------------------------------
CREATE POLICY asistencia_select ON public.asistencia_alumnas FOR SELECT TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)) OR public.inscripcion_propia(inscripcion_id));
CREATE POLICY asistencia_insert ON public.asistencia_alumnas FOR INSERT TO authenticated
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)) AND registrado_por = auth.uid());
CREATE POLICY asistencia_update ON public.asistencia_alumnas FOR UPDATE TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));
CREATE POLICY asistencia_delete ON public.asistencia_alumnas FOR DELETE TO authenticated
  USING (public.gestiona_sede(public.sede_clase(clase_id)));

-- Tutoras: solo lectura (US-38). Alumna: los suyos. Resolver: solo administración (US-37)
CREATE POLICY justificativos_select ON public.justificativos_inasistencia FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.asistencia_alumnas aa
    WHERE aa.id = asistencia_alumna_id
      AND (public.es_staff_sede(public.sede_clase(aa.clase_id)) OR public.inscripcion_propia(aa.inscripcion_id))
  ));
CREATE POLICY justificativos_insert ON public.justificativos_inasistencia FOR INSERT TO authenticated
  WITH CHECK (
    subido_por = auth.uid()
    AND estado = 'pendiente'
    AND EXISTS (
      SELECT 1 FROM public.asistencia_alumnas aa
      WHERE aa.id = asistencia_alumna_id
        AND (public.gestiona_sede(public.sede_clase(aa.clase_id)) OR public.inscripcion_propia(aa.inscripcion_id))
    )
  );
CREATE POLICY justificativos_update ON public.justificativos_inasistencia FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.asistencia_alumnas aa
    WHERE aa.id = asistencia_alumna_id AND public.gestiona_sede(public.sede_clase(aa.clase_id))
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.asistencia_alumnas aa
    WHERE aa.id = asistencia_alumna_id AND public.gestiona_sede(public.sede_clase(aa.clase_id))
  ));

CREATE POLICY participacion_select ON public.participacion_clase FOR SELECT TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)) OR public.inscripcion_propia(inscripcion_id));
CREATE POLICY participacion_write ON public.participacion_clase FOR ALL TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));

CREATE POLICY asistencia_tutores_select ON public.asistencia_tutores FOR SELECT TO authenticated
  USING (tutor_id = auth.uid() OR public.es_staff_sede(public.sede_clase(clase_id)));
CREATE POLICY asistencia_tutores_write ON public.asistencia_tutores FOR ALL TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));

-- -----------------------------------------------------------------------------
-- 9. EVIDENCIA FOTOGRÁFICA
-- -----------------------------------------------------------------------------
CREATE POLICY evidencias_select ON public.evidencias_fotograficas FOR SELECT TO authenticated
  USING (
    public.es_staff_sede(public.sede_clase(clase_id))
    OR (public.current_user_role() = 'comunicacion' AND apta_para_evidencia)
  );
CREATE POLICY evidencias_insert ON public.evidencias_fotograficas FOR INSERT TO authenticated
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)) AND subida_por = auth.uid());
CREATE POLICY evidencias_update ON public.evidencias_fotograficas FOR UPDATE TO authenticated
  USING (public.es_staff_sede(public.sede_clase(clase_id)))
  WITH CHECK (public.es_staff_sede(public.sede_clase(clase_id)));
CREATE POLICY evidencias_delete ON public.evidencias_fotograficas FOR DELETE TO authenticated
  USING (public.gestiona_sede(public.sede_clase(clase_id)));

-- -----------------------------------------------------------------------------
-- 10. ALERTAS Y ENCUESTAS (las alertas las crea un trigger del sistema)
-- -----------------------------------------------------------------------------
CREATE POLICY alertas_select ON public.alertas_desercion FOR SELECT TO authenticated
  USING (public.gestiona_sede(public.sede_inscripcion(inscripcion_id)));
CREATE POLICY alertas_update ON public.alertas_desercion FOR UPDATE TO authenticated
  USING (public.gestiona_sede(public.sede_inscripcion(inscripcion_id)))
  WITH CHECK (public.gestiona_sede(public.sede_inscripcion(inscripcion_id)));

CREATE POLICY encuestas_select ON public.encuestas_satisfaccion FOR SELECT TO authenticated
  USING (public.puede_ver_instancia(instancia_curso_id));
CREATE POLICY encuestas_write ON public.encuestas_satisfaccion FOR ALL TO authenticated
  USING (public.gestiona_sede(public.sede_instancia(instancia_curso_id)))
  WITH CHECK (public.gestiona_sede(public.sede_instancia(instancia_curso_id)));

CREATE POLICY preguntas_select ON public.preguntas_encuesta FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.encuestas_satisfaccion e WHERE e.id = encuesta_id AND public.puede_ver_instancia(e.instancia_curso_id)));
CREATE POLICY preguntas_write ON public.preguntas_encuesta FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.encuestas_satisfaccion e WHERE e.id = encuesta_id AND public.gestiona_sede(public.sede_instancia(e.instancia_curso_id))))
  WITH CHECK (EXISTS (SELECT 1 FROM public.encuestas_satisfaccion e WHERE e.id = encuesta_id AND public.gestiona_sede(public.sede_instancia(e.instancia_curso_id))));

-- Respuestas: la alumna escribe las suyas; las métricas agregadas se leen por RPC (US-42)
CREATE POLICY respuestas_insert ON public.respuestas_encuesta FOR INSERT TO authenticated
  WITH CHECK (public.inscripcion_propia(inscripcion_id));
CREATE POLICY respuestas_select ON public.respuestas_encuesta FOR SELECT TO authenticated
  USING (public.inscripcion_propia(inscripcion_id) OR public.is_directorio());
