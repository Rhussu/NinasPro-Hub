---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-02: Programación de Instancias de Curso y Generación Automática de Sesiones"
labels: ["user-story", "Must", "RF-01", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-1 · Registro de nuevas sedes y cursos
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-U-3 (Responsivo)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** programar una instancia de curso para una sede y período académico indicando rango de fechas y día de impartición,  
> **para** que el sistema genere automáticamente el calendario de sesiones semanales correspondiente y asigne la instancia al equipo de gestión local.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Generación automática de sesiones):** Dado un curso y una sede seleccionados, cuando el Directorio define una fecha de inicio (ej. 1 de agosto), fecha de término (ej. 28 de noviembre) y día de clases (ej. sábados), entonces el sistema genera automáticamente las 18 sesiones semanales con estado "programada", numeradas secuencialmente.
- [ ] **Escenario 2 (Validación de fechas de instancia):** Dado el formulario de creación de instancia, cuando la fecha de término ingresada es anterior o igual a la de inicio, entonces el sistema rechaza la creación, resalta el campo con error y no inserta registros de clases.
- [ ] **Escenario 3 (Control de instancias duplicadas):** Dado que ya existe una instancia para el mismo curso, sede y período académico, cuando el Directorio intenta crearla nuevamente, entonces el sistema notifica la duplicidad (409) y solicita confirmación explícita; si la Directiva confirma, la nueva instancia se crea como **sección paralela** (columna `seccion`) con su propio cronograma.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Asistente para creación de instancia con selector de sede, curso, rango de fechas y día/horario.
- [ ] Backend / Lógica: Función / trigger de generación por lotes de registros en `clases` basados en la recurrencia semanal.
- [ ] Backend / Lógica: Validación en base de datos de clave única compuesta `(curso_id, sede_id, periodo_academico, seccion)` y RPC `crear_instancia_curso` (409 `PT409` si ya existe y no se confirmó la sección paralela).
- [ ] Pruebas mínimas: Prueba unitaria para cálculo correcto de cantidad de sábados entre dos fechas y test de validación de orden de fechas.

---

### 📝 Ajustes del MVP
- Las instancias repetidas (mismo curso, sede y período) se permiten como secciones paralelas tras confirmar (decidido el 2026-11-16).
