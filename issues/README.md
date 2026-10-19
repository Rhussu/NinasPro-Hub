# 📋 Catálogo de Historias de Usuario (Product Backlog) — Niñas Pro Hub

Este directorio contiene las historias de usuario atómicas e independientes derivadas de la **Especificación de Requisitos de Software (SRS IEEE 830 v0.2)** del proyecto *Niñas Pro Hub*.

En esta primera fase se han generado exclusivamente las historias asociadas a los requerimientos priorizados como **Must (M)** y **Should (S)**, cumpliendo con la estructura de la plantilla oficial de GitHub Issues (`.github/ISSUE_TEMPLATE/user_story.md`) y etiquetadas según su prioridad MoSCoW.

---

## 🏷️ Convención de Etiquetas (Labels)

- `Must`: Requisito imprescindible del MVP (semana 13).
- `Should`: Requisito de alto valor operativo.
- `user-story`: Clasificación del artefacto ágil.
- `RF-XX`: Requisito funcional trazado de la especificación SRS.
- `[Rol]`: Rol principal involucrado (`Directorio`, `Gestion`, `Tutora`, `Alumna`, `Seguridad`, `Sistema`).

---

## 🚀 Requisitos Must (M) — 13 Requerimientos (34 Historias de Usuario)

| ID | Título de la Historia de Usuario | RF Base | Prioridad | Archivo |
| :--- | :--- | :---: | :---: | :--- |
| **US-01** | Gestión del Catálogo de Sedes y Cursos Formativos | RF-1 | `Must` | [US-01-RF01-catalogo-sedes-cursos.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-01-RF01-catalogo-sedes-cursos.md) |
| **US-02** | Programación de Instancias de Curso y Generación Automática de Sesiones | RF-1 | `Must` | [US-02-RF01-programacion-instancias-sesiones.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-02-RF01-programacion-instancias-sesiones.md) |
| **US-03** | Gestión de Calendario de Clases y Suspensión de Sesiones | RF-1 | `Must` | [US-03-RF01-calendario-suspension-clases.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-03-RF01-calendario-suspension-clases.md) |
| **US-04** | Invitación y Creación de Cuentas por Rol y Sede | RF-2 | `Must` | [US-04-RF02-invitacion-creacion-cuentas.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-04-RF02-invitacion-creacion-cuentas.md) |
| **US-05** | Activación de Cuenta mediante Enlace de Un Solo Uso y Autenticación Segura | RF-2 | `Must` | [US-05-RF02-activacion-cuenta-autenticacion.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-05-RF02-activacion-cuenta-autenticacion.md) |
| **US-06** | Control de Acceso por Sede (RLS) y Bloqueo por Intentos Fallidos | RF-2 | `Must` | [US-06-RF02-control-acceso-bloqueo-seguridad.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-06-RF02-control-acceso-bloqueo-seguridad.md) |
| **US-07** | Carga Masiva de Nómina de Alumnas vía CSV/XLSX con Previsualización | RF-3 | `Must` | [US-07-RF03-carga-masiva-nomina-alumnas.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-07-RF03-carga-masiva-nomina-alumnas.md) |
| **US-08** | Validación Estricta de Formato, Columnas y RUT Chileno (Módulo 11) | RF-3 | `Must` | [US-08-RF03-validacion-rut-formato-nomina.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-08-RF03-validacion-rut-formato-nomina.md) |
| **US-09** | Unificación de Ficha Histórica de Alumna por RUT e Inscripción Individual | RF-3 | `Must` | [US-09-RF03-ficha-unica-alumna-retiro.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-09-RF03-ficha-unica-alumna-retiro.md) |
| **US-10** | Registro y Respaldo Documental de Autorizaciones del Apoderado | RF-4 | `Must` | [US-10-RF04-registro-autorizaciones-apoderado.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-10-RF04-registro-autorizaciones-apoderado.md) |
| **US-11** | Activación de Matrícula Condicionada y Alertas por Consentimiento Pendiente | RF-4 | `Must` | [US-11-RF04-activacion-matricula-condicionada.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-11-RF04-activacion-matricula-condicionada.md) |
| **US-12** | Revocación de Autorizaciones de Imagen y Actualización de Aptitud | RF-4 | `Must` | [US-12-RF04-revocacion-autorizaciones-imagen.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-12-RF04-revocacion-autorizaciones-imagen.md) |
| **US-13** | Pase de Lista Rápido de Alumnas Optimizado para Móvil | RF-5 | `Must` | [US-13-RF05-pase-lista-alumnas-movil.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-13-RF05-pase-lista-alumnas-movil.md) |
| **US-14** | Almacenamiento Local Offline y Sincronización Automática de Asistencia | RF-5 | `Must` | [US-14-RF05-asistencia-offline-sincronizacion.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-14-RF05-asistencia-offline-sincronizacion.md) |
| **US-15** | Edición Posterior y Resolución Concurrente de Asistencia | RF-5 | `Must` | [US-15-RF05-edicion-asistencia-concurrencia.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-15-RF05-edicion-asistencia-concurrencia.md) |
| **US-16** | Vinculación de Justificativo a Inasistencia con Motivo Tipificado | RF-8 | `Must` | [US-16-RF08-vinculacion-justificativos-inasistencia.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-16-RF08-vinculacion-justificativos-inasistencia.md) |
| **US-17** | Control de Acceso y Minimización de Datos en Justificativos | RF-8 | `Must` | [US-17-RF08-control-acceso-privacidad-justificativos.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-17-RF08-control-acceso-privacidad-justificativos.md) |
| **US-18** | Subida Móvil de Evidencia Fotográfica con Compresión en Cliente | RF-9 | `Must` | [US-18-RF09-subida-evidencia-fotografica-compresion.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-18-RF09-subida-evidencia-fotografica-compresion.md) |
| **US-19** | Verificación de Autorizaciones de Imagen y Marcado de Foto Apta | RF-9 | `Must` | [US-19-RF09-validacion-consentimiento-foto-apta.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-19-RF09-validacion-consentimiento-foto-apta.md) |
| **US-20** | Monitoreo y Alerta de Clases con Evidencia Pendiente tras 48 Horas | RF-9 | `Must` | [US-20-RF09-alerta-evidencias-pendientes-48h.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-20-RF09-alerta-evidencias-pendientes-48h.md) |
| **US-21** | Exportación Filtrada de Asistencia, Nóminas y Participación en CSV/XLSX | RF-11 | `Must` | [US-21-RF11-exportacion-filtrada-csv-xlsx.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-21-RF11-exportacion-filtrada-csv-xlsx.md) |
| **US-22** | Exportación Disociada de Registros y Trazabilidad de Descargas | RF-11 | `Must` | [US-22-RF11-exportacion-disociada-auditoria.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-22-RF11-exportacion-disociada-auditoria.md) |
| **US-23** | Registro Automático e Inmutable de Modificaciones y Accesos a Datos | RF-12 | `Must` | [US-23-RF12-registro-automatico-inmutable-auditoria.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-23-RF12-registro-automatico-inmutable-auditoria.md) |
| **US-24** | Consulta y Filtros de Auditoría para Cumplimiento y Derechos ARCO | RF-12 | `Must` | [US-24-RF12-consulta-filtros-auditoria-arco.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-24-RF12-consulta-filtros-auditoria-arco.md) |
| **US-25** | Dashboard de Asistencia y Progreso Académico de la Alumna | RF-14 | `Must` | [US-25-RF14-dashboard-asistencia-progreso-alumna.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-25-RF14-dashboard-asistencia-progreso-alumna.md) |
| **US-26** | Cronograma de Sesiones y Enlaces a Recursos Educativos Externos | RF-14 | `Must` | [US-26-RF14-cronograma-recursos-educativos-alumna.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-26-RF14-cronograma-recursos-educativos-alumna.md) |
| **US-27** | Seguridad y Aislamiento Estricto del Portal de la Alumna | RF-14 | `Must` | [US-27-RF14-seguridad-aislamiento-portal-alumna.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-27-RF14-seguridad-aislamiento-portal-alumna.md) |
| **US-28** | Registro de Desempeño y Participación de Alumnas Presentes por Sesión | RF-20 | `Must` | [US-28-RF20-registro-participacion-ejercicios.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-28-RF20-registro-participacion-ejercicios.md) |
| **US-29** | Registro de Podio Kahoot y Visualización Privada en Portal de la Alumna | RF-20 | `Must` | [US-29-RF20-podio-kahoot-visualizacion-privada.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-29-RF20-podio-kahoot-visualizacion-privada.md) |
| **US-30** | Carga Masiva e Individual de Fichas de Voluntariado vía CSV/XLSX | RF-23 | `Must` | [US-30-RF23-carga-fichas-voluntariado.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-30-RF23-carga-fichas-voluntariado.md) |
| **US-31** | Control de Declaración de Adhesión y Asignación Docente a Cursos | RF-23 | `Must` | [US-31-RF23-declaracion-adhesion-asignacion-docente.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-31-RF23-declaracion-adhesion-asignacion-docente.md) |
| **US-32** | Gestión Histórica y Exportación de la Red de Voluntariado por Sede | RF-23 | `Must` | [US-32-RF23-gestion-historica-exportacion-voluntariado.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-32-RF23-gestion-historica-exportacion-voluntariado.md) |
| **US-33** | Pase de Lista Rápido de Tutores Asistentes a Clase | RF-24 | `Must` | [US-33-RF24-pase-lista-tutores-clase.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-33-RF24-pase-lista-tutores-clase.md) |
| **US-34** | Modo Offline y Trazabilidad de Asistencia Docente | RF-24 | `Must` | [US-34-RF24-modo-offline-asistencia-docente.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-34-RF24-modo-offline-asistencia-docente.md) |

---

## 🌟 Requisitos Should (S) — 5 Requerimientos (10 Historias de Usuario)

| ID | Título de la Historia de Usuario | RF Base | Prioridad | Archivo |
| :--- | :--- | :---: | :---: | :--- |
| **US-35** | Redacción y Envío de Justificativo de Inasistencia desde el Portal | RF-6 | `Should` | [US-35-RF06-redaccion-justificativo-portal-alumna.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-35-RF06-redaccion-justificativo-portal-alumna.md) |
| **US-36** | Adjuntar Evidencia Documental con Minimización de Datos Sensibles de Salud | RF-6 | `Should` | [US-36-RF06-evidencia-justificativo-privacidad-salud.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-36-RF06-evidencia-justificativo-privacidad-salud.md) |
| **US-37** | Bandeja de Gestión y Resolución de Justificativos de Alumnas | RF-7 | `Should` | [US-37-RF07-bandeja-resolucion-justificativos.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-37-RF07-bandeja-resolucion-justificativos.md) |
| **US-38** | Visualización en Solo Lectura de Justificativos para Tutoras del Curso | RF-7 | `Should` | [US-38-RF07-visualizacion-justificativos-tutoras.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-38-RF07-visualizacion-justificativos-tutoras.md) |
| **US-39** | Detección Automática de Patrón de 3 Inasistencias Consecutivas | RF-16 | `Should` | [US-39-RF16-deteccion-automatica-tres-inasistencias.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-39-RF16-deteccion-automatica-tres-inasistencias.md) |
| **US-40** | Panel de Gestión de Alertas de Deserción y Registro de Contacto Preventivo | RF-16 | `Should` | [US-40-RF16-panel-alertas-contacto-preventivo.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-40-RF16-panel-alertas-contacto-preventivo.md) |
| **US-41** | Notificación y Respuesta de Encuesta Mensual en Portal de Alumna | RF-21 | `Should` | [US-41-RF21-notificacion-respuesta-encuesta-alumna.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-41-RF21-notificacion-respuesta-encuesta-alumna.md) |
| **US-42** | Consolidación Agregada y Anónima de Métricas de Percepción | RF-21 | `Should` | [US-42-RF21-metricas-percepcion-anonimas-agregadas.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-42-RF21-metricas-percepcion-anonimas-agregadas.md) |
| **US-43** | Configuración y Distribución Semanal de Tareas Docentes por Clase | RF-25 | `Should` | [US-43-RF25-configuracion-tareas-semanales-docentes.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-43-RF25-configuracion-tareas-semanales-docentes.md) |
| **US-44** | Consulta Móvil y Marcado de Cumplimiento de Tareas Asignadas | RF-25 | `Should` | [US-44-RF25-marcado-cumplimiento-tareas.md](file:///c:/Users/Walter/Desktop/NinasPro-Hub/issues/US-44-RF25-marcado-cumplimiento-tareas.md) |
