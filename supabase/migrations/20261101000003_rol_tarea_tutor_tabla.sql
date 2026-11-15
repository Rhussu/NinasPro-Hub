-- =============================================================================
-- Migration: 20261101000003_rol_tarea_tutor_tabla.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Reemplaza el enum rol_tarea_tutor por un catálogo dinámico
--              administrable por la Directiva (US-43) y sube el umbral de
--              asistencia mínima por defecto a 80%.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. LIBERAR EL NOMBRE: una tabla crea un tipo compuesto con su mismo nombre
-- -----------------------------------------------------------------------------
ALTER TYPE public.rol_tarea_tutor RENAME TO rol_tarea_tutor_legacy;

-- -----------------------------------------------------------------------------
-- 2. CATÁLOGO DINÁMICO DE ROLES DE TUTORAS
-- -----------------------------------------------------------------------------
CREATE TABLE public.rol_tarea_tutor (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(50) UNIQUE NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Los valores del enum anterior pasan a ser filas del catálogo
INSERT INTO public.rol_tarea_tutor (codigo, nombre) VALUES
  ('tutora_lider', 'Tutora líder'),
  ('tutora_apoyo', 'Tutora de apoyo'),
  ('registro_asistencia', 'Registro de asistencia'),
  ('dinamica_kahoot', 'Dinámica Kahoot');

-- -----------------------------------------------------------------------------
-- 3. MIGRAR tareas_semanales_tutores DEL ENUM A LA FK
-- -----------------------------------------------------------------------------
ALTER TABLE public.tareas_semanales_tutores
  ADD COLUMN rol_tarea_tutor_id UUID REFERENCES public.rol_tarea_tutor(id) ON DELETE RESTRICT;

UPDATE public.tareas_semanales_tutores t
SET rol_tarea_tutor_id = r.id
FROM public.rol_tarea_tutor r
WHERE r.codigo = t.tarea::text;

ALTER TABLE public.tareas_semanales_tutores
  ALTER COLUMN rol_tarea_tutor_id SET NOT NULL;

-- Al eliminar la columna también se elimina UNIQUE(clase_id, tutor_id, tarea)
ALTER TABLE public.tareas_semanales_tutores DROP COLUMN tarea;

ALTER TABLE public.tareas_semanales_tutores
  ADD CONSTRAINT tareas_semanales_tutores_clase_tutor_rol_key
  UNIQUE (clase_id, tutor_id, rol_tarea_tutor_id);

DROP TYPE public.rol_tarea_tutor_legacy;

-- -----------------------------------------------------------------------------
-- 4. UMBRAL DE ASISTENCIA MÍNIMA POR DEFECTO (US-25)
-- -----------------------------------------------------------------------------
ALTER TABLE public.instancias_curso
  ALTER COLUMN porcentaje_asistencia_minimo SET DEFAULT 80;

-- -----------------------------------------------------------------------------
-- 5. RLS DEL CATÁLOGO
-- -----------------------------------------------------------------------------
ALTER TABLE public.rol_tarea_tutor ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura de roles de tarea de tutor para usuarios autenticados"
  ON public.rol_tarea_tutor FOR SELECT
  TO authenticated
  USING (true);
