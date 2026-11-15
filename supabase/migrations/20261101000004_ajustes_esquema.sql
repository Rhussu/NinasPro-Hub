-- =============================================================================
-- Migration: 20261101000004_ajustes_esquema.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Cierra las brechas entre el esquema y los datos que usa la UI
--              del mockup (enlaces del curso, revocación de imagen, catálogo de
--              roles, alertas, correo propio de la alumna).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. INSTANCIAS DE CURSO: enlaces a Google Classroom y juez virtual (US-26)
-- -----------------------------------------------------------------------------
ALTER TABLE public.instancias_curso
  ADD COLUMN classroom_url TEXT,
  ADD COLUMN juez_virtual_url TEXT,
  ADD CONSTRAINT instancias_curso_classroom_https CHECK (classroom_url IS NULL OR classroom_url LIKE 'https://%'),
  ADD CONSTRAINT instancias_curso_juez_https CHECK (juez_virtual_url IS NULL OR juez_virtual_url LIKE 'https://%'),
  ADD CONSTRAINT instancias_curso_fechas_validas CHECK (fecha_termino > fecha_inicio),
  ADD CONSTRAINT instancias_curso_porcentaje_valido CHECK (porcentaje_asistencia_minimo BETWEEN 0 AND 100);

-- -----------------------------------------------------------------------------
-- 2. RECURSOS DE CLASE: solo enlaces seguros (US-26)
-- -----------------------------------------------------------------------------
ALTER TABLE public.recursos_clase
  ADD CONSTRAINT recursos_clase_url_https CHECK (url LIKE 'https://%');

-- -----------------------------------------------------------------------------
-- 3. ALUMNAS: correo propio para habilitar su cuenta del portal (US-04, US-27)
-- -----------------------------------------------------------------------------
ALTER TABLE public.alumnas
  ADD COLUMN correo VARCHAR(150) UNIQUE;

-- -----------------------------------------------------------------------------
-- 4. AUTORIZACIONES DE IMAGEN: un registro vigente por alumna y revocación
--    por canal con fecha y motivo (US-10, US-12)
-- -----------------------------------------------------------------------------
ALTER TYPE public.tipo_canal_imagen ADD VALUE IF NOT EXISTS 'prensa';

ALTER TABLE public.autorizaciones_apoderado
  ADD CONSTRAINT autorizaciones_apoderado_alumna_key UNIQUE (alumna_id);

ALTER TABLE public.autorizaciones_imagen_canales
  ADD COLUMN fecha_revocacion DATE,
  ADD COLUMN motivo_revocacion TEXT,
  ADD CONSTRAINT autorizaciones_canales_revocacion_completa CHECK (
    (fecha_revocacion IS NULL AND motivo_revocacion IS NULL)
    OR (fecha_revocacion IS NOT NULL AND motivo_revocacion IS NOT NULL AND autorizado = false)
  );

-- -----------------------------------------------------------------------------
-- 5. CATÁLOGO DE ROLES DE TUTORAS: color y obligatoriedad (US-43)
-- -----------------------------------------------------------------------------
ALTER TABLE public.rol_tarea_tutor
  ADD COLUMN color_hex VARCHAR(7) NOT NULL DEFAULT '#7C3AED',
  ADD COLUMN es_requerido BOOLEAN NOT NULL DEFAULT false,
  ADD CONSTRAINT rol_tarea_tutor_color_hex CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$');

-- -----------------------------------------------------------------------------
-- 6. ALERTAS DE DESERCIÓN: inasistencias que gatillaron la alerta (US-39, US-40)
-- -----------------------------------------------------------------------------
ALTER TABLE public.alertas_desercion
  ADD COLUMN inasistencias_consecutivas INTEGER NOT NULL DEFAULT 3
    CHECK (inasistencias_consecutivas > 0);

-- -----------------------------------------------------------------------------
-- 7. VOLUNTARIADO: la salida no puede ser anterior al ingreso (US-32)
-- -----------------------------------------------------------------------------
ALTER TABLE public.voluntarios_detalle
  ADD CONSTRAINT voluntarios_detalle_fechas_validas CHECK (fecha_salida IS NULL OR fecha_salida >= fecha_ingreso);

-- -----------------------------------------------------------------------------
-- 8. PARTICIPACIÓN: podio Kahoot solo admite 1°, 2° o 3° lugar (US-29)
-- -----------------------------------------------------------------------------
ALTER TABLE public.participacion_clase
  ADD CONSTRAINT participacion_clase_podio_valido CHECK (podio_kahoot IS NULL OR podio_kahoot BETWEEN 1 AND 3),
  ADD CONSTRAINT participacion_clase_ejercicios_validos CHECK (ejercicios_completados >= 0);

CREATE UNIQUE INDEX participacion_clase_podio_unico
  ON public.participacion_clase (clase_id, podio_kahoot)
  WHERE podio_kahoot IS NOT NULL;
