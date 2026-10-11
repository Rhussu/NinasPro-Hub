-- =============================================================================
-- Migration: 20261010000002_rls_policies.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Activación de Row Level Security (RLS) y políticas de acceso base
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. HABILITACIÓN DE RLS EN TODAS LAS TABLAS
-- -----------------------------------------------------------------------------
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voluntarios_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_sedes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instancias_curso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutores_instancia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apoderados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alumnas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.autorizaciones_apoderado ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.autorizaciones_imagen_canales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inscripciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificacion_clases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recursos_clase ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tareas_semanales_tutores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencia_alumnas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.justificativos_inasistencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participacion_clase ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencia_tutores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidencias_fotograficas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alertas_desercion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encuestas_satisfaccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preguntas_encuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.respuestas_encuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.foro_preguntas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.foro_respuestas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria_cambios_datos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria_accesos_descargas ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 2. FUNCIONES AUXILIARES DE ROL (SECURITY DEFINER)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS rol_usuario AS $$
  SELECT rol FROM public.perfiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_directorio()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'directorio'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 3. POLÍTICAS BASE: PERFILES Y ACCESO PERSONAL
-- -----------------------------------------------------------------------------
CREATE POLICY "Usuarios pueden consultar su propio perfil"
  ON public.perfiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Directorio y gestión tienen acceso completo a perfiles"
  ON public.perfiles FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid() AND rol IN ('directorio', 'equipo_gestion')
    )
  );

-- -----------------------------------------------------------------------------
-- 4. POLÍTICAS BASE: CATÁLOGO ACADÉMICO (SEDES, CURSOS, INSTANCIAS)
-- -----------------------------------------------------------------------------
CREATE POLICY "Lectura de sedes para usuarios autenticados"
  ON public.sedes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Lectura de cursos para usuarios autenticados"
  ON public.cursos FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Lectura de instancias de curso para usuarios autenticados"
  ON public.instancias_curso FOR SELECT
  TO authenticated
  USING (true);

-- -----------------------------------------------------------------------------
-- 5. POLÍTICAS BASE: ALUMNAS (ESTRICTO ACCESO POR ROL / ID)
-- -----------------------------------------------------------------------------
CREATE POLICY "Alumnas solo pueden consultar su propia ficha"
  ON public.alumnas FOR SELECT
  TO authenticated
  USING (perfil_usuario_id = auth.uid());

CREATE POLICY "Docencia y gestión pueden consultar alumnas"
  ON public.alumnas FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid() AND rol IN ('directorio', 'equipo_gestion', 'tutora')
    )
  );

-- -----------------------------------------------------------------------------
-- 6. POLÍTICAS BASE: AUDITORÍA (INMUTABLE - SIN UPDATE NI DELETE)
-- -----------------------------------------------------------------------------
CREATE POLICY "Registro de auditoría de cambios por usuarios autenticados"
  ON public.auditoria_cambios_datos FOR INSERT
  TO authenticated
  WITH CHECK (ejecutado_por = auth.uid());

CREATE POLICY "Directorio puede consultar auditoría de cambios"
  ON public.auditoria_cambios_datos FOR SELECT
  TO authenticated
  USING (public.is_directorio());

CREATE POLICY "Registro de auditoría de descargas por usuarios autenticados"
  ON public.auditoria_accesos_descargas FOR INSERT
  TO authenticated
  WITH CHECK (usuario_id = auth.uid());

CREATE POLICY "Directorio puede consultar auditoría de descargas"
  ON public.auditoria_accesos_descargas FOR SELECT
  TO authenticated
  USING (public.is_directorio());
