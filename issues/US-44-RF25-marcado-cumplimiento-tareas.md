---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-44: Consulta Móvil y Marcado de Cumplimiento de Tareas Asignadas"
labels: ["user-story", "Should", "RF-25", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-25 · Registro de tareas semanales por tutor
- **Requisitos no funcionales (Indirectos):** RNF-U-1 (Accesibilidad móvil), RNF-U-3 (Pantallas desde 360px)
- **Reglas de negocio asociadas:** RB-6 (Acceso según rol)

---

### 👤 Historia de Usuario
> **Como** tutora voluntaria de Niñas Pro,  
> **quiero** consultar desde mi teléfono móvil las tareas que me fueron asignadas para la clase de la semana y marcar su cumplimiento conforme las vaya completando,  
> **para** tener total claridad de mis responsabilidades antes de llegar al laboratorio y transparentar el estado del equipo docente.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización de tareas pendientes en el panel de la tutora):** Dada una tutora autenticada con cuenta activa, cuando ingresa a la sesión de su clase, entonces visualiza una sección destacada con sus responsabilidades asignadas para el próximo sábado.
- [ ] **Escenario 2 (Marcación de tarea como completada):** Dada una tarea asignada (ej. "Preparar guía de ejercicios"), cuando la tutora finaliza la actividad y presiona el checkbox de cumplimiento, entonces el sistema actualiza el campo `completada = true` en tiempo real.
- [ ] **Escenario 3 (Visibilidad compartida para el equipo docente):** Dado que una tutora marca una tarea como completada, cuando sus compañeras o la líder de sede abren la sesión, entonces visualizan inmediatamente que la tarea se encuentra lista.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Lista interactiva de tareas tipo checklist en la cabecera de la vista de clase de la tutora.
- [ ] Backend / Lógica: Endpoint patch ligero para alternar el booleano `completada` en `tareas_semanales_tutores`.
- [ ] Pruebas mínimas: TC-23 (Verificación de consulta y actualización de estado de cumplimiento de tarea docente).
