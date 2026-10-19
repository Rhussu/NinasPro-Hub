---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-11: Activación de Matrícula Condicionada y Alertas por Consentimiento Pendiente"
labels: ["user-story", "Must", "RF-04", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-4 · Registro de autorizaciones del apoderado
- **Requisitos no funcionales (Indirectos):** RNF-S-5 (Cumplimiento normativo menores), RNF-M-1 (Pruebas unitarias de reglas críticas)
- **Reglas de negocio asociadas:** RB-1 (Consentimiento informado previo)

---

### 👤 Historia de Usuario
> **Como** integrante del Equipo de Gestión de sede,  
> **quiero** que el sistema active la matrícula de la alumna únicamente tras registrar el consentimiento de datos y me alerte sobre autorizaciones pendientes tras dos sesiones,  
> **para** asegurar que ninguna menor participe sin respaldo legal y realizar gestiones de regularización a tiempo.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Transición automática a activa):** Dada una alumna en estado "preinscrita", cuando se registra su autorización de tratamiento de datos como "otorgada", entonces su inscripción transiciona automáticamente a estado "activa", permitiendo su inclusión en las listas de asistencia.
- [ ] **Escenario 2 (Bloqueo de pase de lista sin consentimiento):** Dada una alumna cuya autorización de tratamiento de datos sigue en estado "pendiente" o "no otorgada", cuando una tutora abre la lista de asistencia del curso, entonces la alumna no aparece como activa para ser evaluada ni listada para asistencia ordinaria (RB-1).
- [ ] **Escenario 3 (Alerta por consentimiento pendiente tras 2 sesiones):** Dada una alumna preinscrita cuya autorización permanece pendiente luego de transcurridas 2 sesiones del curso, cuando el Equipo de Gestión abre el panel de sede, entonces la alumna figura destacada en la lista de pendientes de regularización.

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Trigger / función en base de datos para actualizar `estado` de la tabla `inscripciones` a `activa` cuando `autoriza_tratamiento_datos = true`.
- [ ] Frontend / UI: Vista de resumen de autorizaciones pendientes en el panel del Equipo de Gestión de sede.
- [ ] Pruebas mínimas: TC-06 (Caso de prueba que verifica que la inscripción no pasa a activa sin autorización previa de datos).
