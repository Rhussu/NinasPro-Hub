---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-37: Bandeja de Gestión y Resolución de Justificativos de Alumnas"
labels: ["user-story", "Should", "RF-07", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-7 · Aceptación de justificativos desde la plataforma
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio territorial), RNF-S-4 (Auditoría inmutable), RNF-U-3 (Móvil prioritario 360px-430px)
- **Reglas de negocio asociadas:** RB-6 (Acceso territorial por sede), RB-8 (Minimización de datos), RB-Exclusividad-Gestion (Todas las integrantes de Gestión son tutoras, pero la resolución de justificativos es facultad exclusiva de Gestión, no de tutoras de aula)

---

### 👤 Historia de Usuario
> **Como** integrante del Equipo de Gestión de una sede territorial (vista móvil),  
> **quiero** disponer de una bandeja móvil de justificaciones recibidas donde pueda aprobar o rechazar cada solicitud de las alumnas de mi sede con observaciones de retroalimentación,  
> **para** actualizar automáticamente la asistencia a "Justificada" (bloqueada para el pase de lista de aula) y recalcular el umbral de aprobación de la alumna al 70%.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Bandeja reservada a Gestión y Directiva):** La bandeja de resolución es del Equipo de Gestión de la sede; la Directiva también la tiene, para todas las sedes, como entrada secundaria con filtro por sede. Las tutoras regulares de aula no tienen acceso a resolver justificativos.
- [ ] **Escenario 2 (Aprobación con impacto en asistencia y umbral):** Dado un justificativo en estado "pendiente" en la sede, cuando la coordinadora de Gestión presiona "Aprobar", el justificativo pasa a estado "aprobado", la asistencia de la alumna en esa sesión cambia automáticamente a "justificada" (bloqueada para edición de tutoras de aula; sigue contando como ausente) y el umbral de aprobación de la alumna se ajusta al 70% (una sola vez, aunque tenga varios).
- [ ] **Escenario 3 (Rechazo con motivo informado):** Dado un justificativo no admisible, cuando Gestión presiona "Rechazar" e ingresa una observación aclaratoria, el justificativo pasa a "rechazado", la inasistencia se mantiene en "ausente" y se registra la explicación para retroalimentación de la alumna.
- [ ] **Escenario 4 (Filtros móviles y trazabilidad inmutable):** La interfaz móvil de Gestión permite filtrar entre Pendientes, Aprobados y Rechazados, registrando en bitácora de auditoría la responsable, fecha, hora y comentarios.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Bandeja de justificativos (`justificativos_gestion.dart`) con chips de estado, tarjeta de detalle de alumna/sábado y acciones de Aprobar/Rechazar; se abre desde la pantalla y los Ajustes de Gestión, y desde *Ajustes → Gestión en todas las sedes* de la Directiva (cada justificativo muestra su sede).
- [ ] Backend / Lógica: Función transaccional que actualiza `justificativos.estado`, sincroniza `asistencia_alumnas.estado = 'justificada'` y activa la regla de umbral de aprobación al 70%.
- [ ] Pruebas mínimas: TC-20 (Prueba de resolución por Equipo de Gestión en vista móvil y verificación de sincronización de asistencia).

---

### 📝 Ajustes del MVP
- La **Directiva puede hacer todo** lo de Gestión en cualquier sede, como entrada secundaria en *Ajustes → Gestión en todas las sedes* (decidido el 2026-11-16).
- La pantalla principal de cada rol es un resumen con accesos rápidos (tarjetas y Speed Dial); **Ajustes** llega a todo lo que el rol puede ver o hacer, con las mismas vistas (decidido el 2026-11-16, PR 8).
