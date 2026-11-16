---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-38: Visualización en Solo Lectura de Justificativos para Tutoras del Curso"
labels: ["user-story", "Should", "RF-07", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-7 · Aceptación de justificativos desde la plataforma
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio / RBAC), RNF-U-3 (Responsivo)
- **Reglas de negocio asociadas:** RB-6 (Acceso según rol: tutora no resuelve justificativos)

---

### 👤 Historia de Usuario
> **Como** tutora de un curso en desarrollo,  
> **quiero** consultar desde la vista de la clase el estado de los justificativos de mis alumnas (pendiente, aceptado o rechazado) en modo de solo lectura,  
> **para** estar informada sobre la situación de inasistencia de mis estudiantes sin tener la atribución de aprobar o rechazar formalmente las solicitudes.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización de badge de justificativo en lista de clase):** Dada una tutora asignada a un curso y una alumna con inasistencia que envió una justificación, cuando la tutora abre la sesión, entonces visualiza un icono o distintivo junto al nombre de la alumna indicando el estado del justificativo ("Pendiente", "Aceptado", "Rechazado").
- [ ] **Escenario 2 (Restricción de acciones de resolución):** Dada la vista de clase de la tutora, cuando hace clic en el estado del justificativo, entonces puede leer el motivo general (no el detalle) pero la interfaz no le muestra botones ni opciones de "Aceptar" o "Rechazar" (RB-6).
- [ ] **Escenario 3 (Intento de manipulación de estado por API bloqueado):** Dada una petición enviada con un token de rol Tutora intentando invocar el endpoint de resolución de justificativos, cuando el backend procesa la petición, entonces responde con HTTP 403 Forbidden.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Indicador visual de estado de justificativo en el pase de lista de tutoras sin controles de edición.
- [ ] Backend / Lógica: Políticas RLS y reglas de autorización que reservan las mutaciones sobre el estado del justificativo al rol Equipo de Gestión y Directorio.
- [ ] Pruebas mínimas: TC-20 (Verificación de visualización en solo lectura para tutoras sin capacidad de aprobar o rechazar).

---

### 📝 Ajustes del MVP
- La tutora no lee la tabla de justificativos (RLS): el estado y el motivo general le llegan en el pase de lista (`lista_asistencia_clase`), así que en Ajustes la entrada *Asistencia* lo menciona en vez de tener una propia (decidido el 2026-11-16, PR 8).
