---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-16: Vinculación de Justificativo a Inasistencia con Motivo Tipificado"
labels: ["user-story", "Must", "RF-08", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-8 · Vinculación de justificativos a clase
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-S-5 (Cumplimiento legal)
- **Reglas de negocio asociadas:** RB-6 (Acceso por rol/sede), RB-8 (Minimización y finalidad)

---

### 👤 Historia de Usuario
> **Como** integrante del Equipo de Gestión o tutora de la clase,  
> **quiero** vincular un justificativo (texto explicativo o archivo PDF/imagen) a una inasistencia previa seleccionando un motivo tipificado por catálogo,  
> **para** que el estado de la inasistencia cambie automáticamente a "justificada" y quede respaldada operativamente.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Vinculación de justificativo exitosa):** Dada una inasistencia previamente registrada para una alumna, cuando el usuario abre la inasistencia, selecciona un motivo del catálogo (salud, familiar, escolar u otro), adjunta un archivo (PDF/imagen) o escribe un texto y guarda, entonces el estado de la inasistencia pasa inmediatamente a "justificada".
- [ ] **Escenario 2 (Justificativo anticipado para clase futura):** Dado que un apoderado notifica con antelación una inasistencia para el próximo sábado, cuando el Equipo de Gestión ingresa el justificativo sobre la sesión programada, entonces al momento de pasar lista la alumna se precarga con estado "justificada".
- [ ] **Escenario 3 (Eliminación por error y reversión de estado):** Dado un justificativo vinculado erróneamente a una alumna, cuando la persona encargada lo elimina con confirmación, entonces el registro del justificativo se retira y el estado de asistencia revierte automáticamente a "ausente".

---

### 🛠️ Tareas
- [ ] Frontend / UI: Modal de carga de justificativo desde la lista de asistencia o ficha de clase.
- [ ] Backend / Lógica: Tabla `justificativos_inasistencia` vinculada 1:1 con `asistencia_alumnas` y trigger de actualización de estado.
- [ ] Pruebas mínimas: TC-11 (Prueba de vinculación de archivo/texto y transición de ausente a ausente justificada).
