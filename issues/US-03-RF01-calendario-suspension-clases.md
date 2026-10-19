---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-03: Gestión de Calendario de Clases y Suspensión de Sesiones"
labels: ["user-story", "Must", "RF-01", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-1 · Registro de nuevas sedes y cursos
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-U-3 (Responsivo)
- **Reglas de negocio asociadas:** RB-6 (Acceso por sede)

---

### 👤 Historia de Usuario
> **Como** integrante del Equipo de Gestión de una sede,  
> **quiero** consultar el cronograma de sesiones de mis cursos y marcar sesiones como suspendidas o agregar clases de recuperación,  
> **para** reflejar oportunamente feriados o contingencias locales sin alterar las métricas de asistencia del período.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización territorial de sesiones):** Dado un usuario del Equipo de Gestión autenticado en la sede Concepción, cuando accede al calendario del curso, entonces visualiza únicamente las sesiones correspondientes a su sede y ciclo académico vigente.
- [ ] **Escenario 2 (Suspensión de clase por feriado o contingencia):** Dada una sesión previamente programada para un día feriado, cuando el Equipo de Gestión marca la clase como "suspendida", entonces el sistema actualiza su estado, la desactiva del flujo diario de toma de asistencia y no la computa en los cálculos de porcentaje de asistencia del curso.
- [ ] **Escenario 3 (Incorporación de sesión especial):** Dado un curso con contingencias previas, cuando el Equipo de Gestión agrega una sesión especial con fecha y hora específicas, entonces la sesión queda programada y visible inmediatamente para las tutoras del curso.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista de calendario/listado de sesiones por curso con opciones de suspender y añadir sesión extraordinaria.
- [ ] Backend / Lógica: Actualización de estado en tabla `clases` (`programada`, `realizada`, `suspendida`).
- [ ] Backend / Lógica: Regla de exclusión de clases suspendidas en el cálculo agregado de asistencia y reportes.
- [ ] Pruebas mínimas: Prueba de integración comprobando que clases con estado `suspendida` tienen denominador 0 en asistencia de alumnas.
