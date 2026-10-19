-- =============================================================================
-- MIGRACIÓN: Roles Dinámicos de Tutoras y Asignación Semanal (US-43)
-- Fecha: 19 de Octubre de 2026
-- Descripción:
-- Implementa catálogo configurable de roles de aula para voluntarias/tutoras
-- y tabla de asignaciones semanales por sede/sesión gestionadas por Equipo de Gestión.
-- =============================================================================

-- 1. Tabla de Catálogo de Roles Dinámicos de Tutoras
CREATE TABLE IF NOT EXISTS roles_tutores_catalogo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(50) UNIQUE NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT,
  color_hex VARCHAR(10) NOT NULL DEFAULT '#79207E',
  es_requerido BOOLEAN NOT NULL DEFAULT false,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Tabla de Asignaciones Semanales de Roles a Tutoras
CREATE TABLE IF NOT EXISTS asignaciones_roles_semanales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE CASCADE,
  sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE CASCADE,
  instancia_curso_id UUID REFERENCES instancias_curso(id) ON DELETE CASCADE,
  semana_numero INT NOT NULL,
  fecha_sesion DATE,
  rol_tutor_id UUID NOT NULL REFERENCES roles_tutores_catalogo(id) ON DELETE RESTRICT,
  creado_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(perfil_id, sede_id, semana_numero)
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_asignaciones_sede_semana ON asignaciones_roles_semanales(sede_id, semana_numero);
CREATE INDEX IF NOT EXISTS idx_asignaciones_tutora ON asignaciones_roles_semanales(perfil_id);

-- 3. Habilitar RLS
ALTER TABLE roles_tutores_catalogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE asignaciones_roles_semanales ENABLE ROW LEVEL SECURITY;

-- 4. Políticas RLS
-- Lectura: Todos los usuarios autenticados pueden ver los roles y asignaciones
CREATE POLICY "Lectura pública de roles de tutoras para autenticados"
  ON roles_tutores_catalogo FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Lectura de asignaciones semanales para autenticados"
  ON asignaciones_roles_semanales FOR SELECT
  TO authenticated
  USING (true);

-- Escritura: Directorio y Equipo de Gestión pueden crear/modificar roles y asignaciones
CREATE POLICY "Directorio y Gestión administran roles tutores"
  ON roles_tutores_catalogo FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('directorio', 'equipo_gestion')
    )
  );

CREATE POLICY "Directorio y Gestión administran asignaciones semanales"
  ON asignaciones_roles_semanales FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('directorio', 'equipo_gestion')
    )
  );

-- 5. Seeds iniciales de roles dinámicos (US-43)
INSERT INTO roles_tutores_catalogo (codigo, nombre, descripcion, color_hex, es_requerido)
VALUES
  ('facilitadora', 'Facilitadora Principal', 'Explica conceptos en la pizarra y lidera la sesión pedagógica', '#79207E', true),
  ('co_facilitadora', 'Co-facilitadora', 'Apoya con la resolución guiada de dudas y acompañamiento en sala', '#FF3593', true),
  ('soporte_tecnico', 'Soporte Técnico', 'Soluciona problemas de conexión, entornos Python, Colab y cuentas', '#4A90E2', false),
  ('logistica_materiales', 'Logística y Materiales', 'Organiza salas, credenciales, colaciones y asistencia física', '#00A86B', false)
ON CONFLICT (codigo) DO NOTHING;
