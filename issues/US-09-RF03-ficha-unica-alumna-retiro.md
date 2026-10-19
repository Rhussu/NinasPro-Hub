---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-09: Unificación de Ficha Histórica de Alumna por RUT e Inscripción Individual"
labels: ["user-story", "Must", "RF-03", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-3 · Ingreso de nueva nómina de alumnas
- **Requisitos no funcionales (Indirectos):** RNF-S-5 (Protección de datos), RNF-R-3 (Volumen de datos)
- **Reglas de negocio asociadas:** RB-10 (Conservación y ciclo de vida de matrícula)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** que una alumna que se inscribe en múltiples cursos o años conserve una única ficha personal vinculada a su RUT y poder inscribir o retirar alumnas individualmente,  
> **para** mantener la trazabilidad de su trayectoria educativa en Niñas Pro sin duplicar datos ni perder su historial.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Reutilización de ficha existente multi-sede/multi-año):** Dada una alumna que cursó en la sede A en 2025, cuando se inscribe en la sede B en 2026 mediante su RUT, entonces el sistema no crea una nueva ficha en `alumnas`, sino que asocia una nueva tupla en `inscripciones` vinculada a la misma entidad.
- [ ] **Escenario 2 (Inscripción individual vía formulario):** Dado que se requiere matricular a una alumna fuera de la carga masiva, cuando el Directorio completa el formulario individual con su RUT, datos personales y apoderado, entonces se crea su registro de forma exitosa.
- [ ] **Escenario 3 (Gestión de retiro de alumna):** Dada una alumna con inscripción activa que decide abandonar el curso, cuando la persona encargada marca su inscripción como "retirada" indicando fecha y motivo formal, entonces se actualiza el estado de la matrícula preservando su historial previo de asistencia.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario de inscripción manual individual y acción de registrar retiro en la ficha de inscripción.
- [ ] Backend / Lógica: Lógica de upsert en base de datos para la entidad `alumnas` con restricción de unicidad en campo `rut`.
- [ ] Pruebas mínimas: TC-05 (Prueba con alumna de otra sede/año verificando una sola ficha y dos inscripciones independientes).
