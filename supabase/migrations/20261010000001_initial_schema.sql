-- =============================================================================
-- Migration: 20261010000001_initial_schema.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Esquema relacional en Tercera Forma Normal (3NF) - 8 Módulos
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- TIPOS ENUMERADOS (ENUMS)
-- -----------------------------------------------------------------------------

CREATE TYPE rol_usuario AS ENUM (
  'directorio',
  'equipo_gestion',
  'tutora',
  'alumna',
  'comunicacion'
);

CREATE TYPE modalidad_sede AS ENUM (
  'presencial',
  'online'
);

CREATE TYPE estado_inscripcion AS ENUM (
  'preinscrita',
  'activa',
  'retirada',
  'egresada'
);

CREATE TYPE estado_autorizacion AS ENUM (
  'pendiente',
  'otorgada',
  'no_otorgada',
  'revocada'
);

CREATE TYPE tipo_canal_imagen AS ENUM (
  'redes_sociales',
  'sitio_web',
  'memoria_anual',
  'reporte_patrocinantes',
  'interno'
);

CREATE TYPE estado_clase AS ENUM (
  'programada',
  'realizada',
  'suspendida'
);

CREATE TYPE estado_asistencia AS ENUM (
  'presente',
  'ausente',
  'justificada'
);

CREATE TYPE motivo_justificativo AS ENUM (
  'salud',
  'familiar',
  'escolar',
  'otro'
);

CREATE TYPE estado_justificativo AS ENUM (
  'pendiente',
  'aceptado',
  'rechazado'
);

CREATE TYPE rol_tarea_tutor AS ENUM (
  'tutora_lider',
  'tutora_apoyo',
  'registro_asistencia',
  'dinamica_kahoot'
);

CREATE TYPE tipo_pregunta_encuesta AS ENUM (
  'escala_1_a_5',
  'texto_libre',
  'seleccion_multiple'
);

CREATE TYPE tipo_accion_auditoria AS ENUM (
  'insert',
  'update',
  'delete',
  'export',
  'access_view'
);

-- -----------------------------------------------------------------------------
-- MÓDULO 1: IDENTIDAD, ACCESO Y VOLUNTARIADO
-- -----------------------------------------------------------------------------

CREATE TABLE perfiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rut VARCHAR(12) UNIQUE NOT NULL,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  correo VARCHAR(150) UNIQUE NOT NULL,
  telefono VARCHAR(20),
  rol rol_usuario NOT NULL DEFAULT 'tutora',
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE voluntarios_detalle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id UUID UNIQUE NOT NULL REFERENCES perfiles(id) ON DELETE CASCADE,
  institucion_u_ocupacion VARCHAR(150),
  fecha_ingreso DATE NOT NULL,
  fecha_salida DATE,
  declaracion_adhesion_firmada BOOLEAN NOT NULL DEFAULT false,
  fecha_firma_declaracion TIMESTAMPTZ,
  documento_adhesion_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE sedes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(80) UNIQUE NOT NULL,
  ciudad VARCHAR(80),
  region VARCHAR(80),
  modalidad modalidad_sede NOT NULL DEFAULT 'presencial',
  institucion_anfitriona VARCHAR(150),
  activa BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE usuarios_sedes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE CASCADE,
  sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
  es_lider_sede BOOLEAN NOT NULL DEFAULT false,
  asignado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(perfil_id, sede_id)
);

-- -----------------------------------------------------------------------------
-- MÓDULO 2: ESTRUCTURA ACADÉMICA
-- -----------------------------------------------------------------------------

CREATE TABLE cursos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(120) NOT NULL,
  codigo VARCHAR(20) UNIQUE NOT NULL,
  descripcion TEXT,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE instancias_curso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  curso_id UUID NOT NULL REFERENCES cursos(id) ON DELETE RESTRICT,
  sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
  periodo_academico VARCHAR(20) NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_termino DATE NOT NULL,
  dia_semana VARCHAR(15) NOT NULL DEFAULT 'Sábado',
  hora_inicio TIME NOT NULL DEFAULT '10:00',
  hora_fin TIME NOT NULL DEFAULT '13:00',
  porcentaje_asistencia_minimo INTEGER NOT NULL DEFAULT 75,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(curso_id, sede_id, periodo_academico)
);

CREATE TABLE tutores_instancia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instancia_curso_id UUID NOT NULL REFERENCES instancias_curso(id) ON DELETE CASCADE,
  tutor_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  asignado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(instancia_curso_id, tutor_id)
);

-- -----------------------------------------------------------------------------
-- MÓDULO 3: ALUMNAS, APODERADOS Y PROTECCIÓN LEGAL (LEY 19.628 / 21.719)
-- -----------------------------------------------------------------------------

CREATE TABLE apoderados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rut VARCHAR(12) UNIQUE,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  correo VARCHAR(150) NOT NULL,
  telefono VARCHAR(20) NOT NULL,
  parentesco VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE alumnas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rut VARCHAR(12) UNIQUE NOT NULL,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  establecimiento_educacional VARCHAR(150),
  curso_escolar VARCHAR(50),
  apoderado_id UUID NOT NULL REFERENCES apoderados(id) ON DELETE RESTRICT,
  perfil_usuario_id UUID UNIQUE REFERENCES perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE autorizaciones_apoderado (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alumna_id UUID NOT NULL REFERENCES alumnas(id) ON DELETE CASCADE,
  apoderado_id UUID NOT NULL REFERENCES apoderados(id) ON DELETE RESTRICT,
  autoriza_tratamiento_datos estado_autorizacion NOT NULL DEFAULT 'pendiente',
  autoriza_uso_imagen_general estado_autorizacion NOT NULL DEFAULT 'pendiente',
  documento_respaldo_url TEXT,
  fecha_firma TIMESTAMPTZ,
  registrado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE autorizaciones_imagen_canales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  autorizacion_id UUID NOT NULL REFERENCES autorizaciones_apoderado(id) ON DELETE CASCADE,
  canal tipo_canal_imagen NOT NULL,
  autorizado BOOLEAN NOT NULL DEFAULT false,
  fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(autorizacion_id, canal)
);

CREATE TABLE inscripciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alumna_id UUID NOT NULL REFERENCES alumnas(id) ON DELETE RESTRICT,
  instancia_curso_id UUID NOT NULL REFERENCES instancias_curso(id) ON DELETE RESTRICT,
  estado estado_inscripcion NOT NULL DEFAULT 'preinscrita',
  fecha_inscripcion DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_retiro DATE,
  motivo_retiro TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(alumna_id, instancia_curso_id)
);

-- -----------------------------------------------------------------------------
-- MÓDULO 4: PLANIFICACIÓN, CLASES Y ASIGNACIÓN
-- -----------------------------------------------------------------------------

CREATE TABLE clases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instancia_curso_id UUID NOT NULL REFERENCES instancias_curso(id) ON DELETE RESTRICT,
  numero_sesion INTEGER NOT NULL,
  fecha DATE NOT NULL,
  hora_inicio TIME,
  hora_fin TIME,
  estado estado_clase NOT NULL DEFAULT 'programada',
  motivo_suspension TEXT,
  cerrada_para_edicion BOOLEAN NOT NULL DEFAULT false,
  registrada_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  fecha_realizacion TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(instancia_curso_id, numero_sesion),
  UNIQUE(instancia_curso_id, fecha)
);

CREATE TABLE planificacion_clases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID UNIQUE NOT NULL REFERENCES clases(id) ON DELETE CASCADE,
  tema_titulo VARCHAR(200) NOT NULL,
  descripcion_contenidos TEXT,
  publicado_para_alumnas BOOLEAN NOT NULL DEFAULT false,
  creado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE recursos_clase (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE CASCADE,
  titulo VARCHAR(120) NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  url TEXT NOT NULL,
  orden INTEGER DEFAULT 0
);

CREATE TABLE tareas_semanales_tutores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE CASCADE,
  tutor_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  tarea rol_tarea_tutor NOT NULL,
  observaciones TEXT,
  completada BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(clase_id, tutor_id, tarea)
);

-- -----------------------------------------------------------------------------
-- MÓDULO 5: ASISTENCIA, JUSTIFICATIVOS Y PARTICIPACIÓN
-- -----------------------------------------------------------------------------

CREATE TABLE asistencia_alumnas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE RESTRICT,
  inscripcion_id UUID NOT NULL REFERENCES inscripciones(id) ON DELETE RESTRICT,
  estado estado_asistencia NOT NULL DEFAULT 'presente',
  registrado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  registrado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  dispositivo_origen VARCHAR(100),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(clase_id, inscripcion_id)
);

CREATE TABLE justificativos_inasistencia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asistencia_alumna_id UUID UNIQUE NOT NULL REFERENCES asistencia_alumnas(id) ON DELETE CASCADE,
  motivo motivo_justificativo NOT NULL,
  explicacion TEXT,
  archivo_adjunto_url TEXT,
  estado estado_justificativo NOT NULL DEFAULT 'pendiente',
  subido_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  resuelto_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  fecha_resolucion TIMESTAMPTZ,
  observacion_resolucion TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE participacion_clase (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE RESTRICT,
  inscripcion_id UUID NOT NULL REFERENCES inscripciones(id) ON DELETE RESTRICT,
  ejercicios_completados INTEGER NOT NULL DEFAULT 0,
  participo_activa BOOLEAN NOT NULL DEFAULT false,
  podio_kahoot INTEGER,
  registrado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(clase_id, inscripcion_id)
);

CREATE TABLE asistencia_tutores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE RESTRICT,
  tutor_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  estado estado_asistencia NOT NULL DEFAULT 'presente',
  registrado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  registrado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(clase_id, tutor_id)
);

-- -----------------------------------------------------------------------------
-- MÓDULO 6: EVIDENCIA MULTIMEDIA Y PATROCINIOS
-- -----------------------------------------------------------------------------

CREATE TABLE evidencias_fotograficas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE CASCADE,
  archivo_url TEXT NOT NULL,
  tamano_bytes INTEGER,
  apta_para_evidencia BOOLEAN NOT NULL DEFAULT false,
  rostros_censurados BOOLEAN NOT NULL DEFAULT false,
  declaracion_consentimiento_completo BOOLEAN NOT NULL DEFAULT false,
  subida_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  subida_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- -----------------------------------------------------------------------------
-- MÓDULO 7: CALIDAD, ALERTAS, ENCUESTAS Y COMUNIDAD
-- -----------------------------------------------------------------------------

CREATE TABLE alertas_desercion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inscripcion_id UUID NOT NULL REFERENCES inscripciones(id) ON DELETE CASCADE,
  clase_id UUID NOT NULL REFERENCES clases(id) ON DELETE CASCADE,
  motivo_alerta VARCHAR(150) NOT NULL DEFAULT 'Acumulación de 3 inasistencias consecutivas sin justificar',
  atendida BOOLEAN NOT NULL DEFAULT false,
  fecha_contacto DATE,
  observacion_gestion TEXT,
  atendida_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE encuestas_satisfaccion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instancia_curso_id UUID NOT NULL REFERENCES instancias_curso(id) ON DELETE CASCADE,
  mes_periodo VARCHAR(20) NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  descripcion TEXT,
  abierta BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(instancia_curso_id, mes_periodo)
);

CREATE TABLE preguntas_encuesta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encuesta_id UUID NOT NULL REFERENCES encuestas_satisfaccion(id) ON DELETE CASCADE,
  enunciado TEXT NOT NULL,
  tipo tipo_pregunta_encuesta NOT NULL DEFAULT 'escala_1_a_5',
  orden INTEGER NOT NULL DEFAULT 1,
  es_obligatoria BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE respuestas_encuesta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pregunta_id UUID NOT NULL REFERENCES preguntas_encuesta(id) ON DELETE CASCADE,
  inscripcion_id UUID NOT NULL REFERENCES inscripciones(id) ON DELETE RESTRICT,
  valor_escala INTEGER,
  valor_texto TEXT,
  respondido_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(pregunta_id, inscripcion_id)
);

CREATE TABLE foro_preguntas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instancia_curso_id UUID NOT NULL REFERENCES instancias_curso(id) ON DELETE CASCADE,
  alumna_id UUID NOT NULL REFERENCES alumnas(id) ON DELETE RESTRICT,
  titulo VARCHAR(200) NOT NULL,
  contenido TEXT NOT NULL,
  ocultada BOOLEAN NOT NULL DEFAULT false,
  ocultada_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  motivo_ocultamiento TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE foro_respuestas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pregunta_id UUID NOT NULL REFERENCES foro_preguntas(id) ON DELETE CASCADE,
  autor_perfil_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  contenido TEXT NOT NULL,
  ocultada BOOLEAN NOT NULL DEFAULT false,
  ocultada_por UUID REFERENCES perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- -----------------------------------------------------------------------------
-- MÓDULO 8: AUDITORÍA Y CUMPLIMIENTO LEGAL (LEY 19.628 / 21.719)
-- -----------------------------------------------------------------------------

CREATE TABLE auditoria_cambios_datos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tabla_afectada VARCHAR(50) NOT NULL,
  registro_id UUID NOT NULL,
  accion tipo_accion_auditoria NOT NULL,
  valor_anterior JSONB,
  valor_nuevo JSONB,
  ejecutado_por UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  fecha_hora TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  ip_address VARCHAR(45),
  user_agent TEXT
);

CREATE TABLE auditoria_accesos_descargas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES perfiles(id) ON DELETE RESTRICT,
  tipo_operacion VARCHAR(50) NOT NULL,
  filtro_sede_id UUID REFERENCES sedes(id) ON DELETE SET NULL,
  filtro_curso_id UUID REFERENCES cursos(id) ON DELETE SET NULL,
  periodo_filtrado VARCHAR(20),
  formato_archivo VARCHAR(10),
  cantidad_registros INTEGER NOT NULL DEFAULT 0,
  fecha_hora TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
