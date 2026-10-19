---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-33: Pase de Lista Rápido de Tutores Asistentes a Clase"
labels: ["user-story", "Must", "RF-24", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-24 · Registro de asistencia de tutores por clase
- **Requisitos no funcionales (Indirectos):** RNF-R-1 (Tiempo respuesta ≤ 1.5s), RNF-U-2 (Completado en celular sin asistencia), RNF-U-3 (Responsivo)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad con autora y timestamp)

---

### 👤 Historia de Usuario
> **Como** tutora designada para el control de la clase,  
> **quiero** registrar la asistencia del equipo de tutoras asignadas a la sesión (marcando presente, ausente o justificado),  
> **para** mantener el registro formal del voluntariado que efectivamente participó en cada jornada formativa.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Pase de lista con equipo pre-cargado como presente):** Dada una sesión con 8 tutores asignados, cuando la tutora designada abre el registro de asistencia docente, entonces el sistema muestra la nómina de tutores con estado inicial "Presente".
- [ ] **Escenario 2 (Marcación rápida de ausencias y persistencia):** Dada la lista de tutores, cuando la encargada marca a 3 ausentes y pulsa guardar, entonces el sistema almacena 5 tutores presentes y 3 ausentes, guardando el identificador de la autora y la marca de tiempo exacta.
- [ ] **Escenario 3 (Edición posterior del listado docente):** Dada una sesión de clase ya realizada, cuando una tutora llega más tarde o se requiere corregir un estado antes del cierre del curso, entonces la tutora designada o el Equipo de Gestión puede reabrir el listado, actualizar el estado y registrar la corrección en la auditoría.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Pestaña o sección de "Asistencia Docente / Equipo" en la vista de la clase con interfaz táctil simplificada.
- [ ] Backend / Lógica: Inserción y actualización en tabla `asistencia_tutores` con clave única `(clase_id, tutor_id)`.
- [ ] Pruebas mínimas: TC-10 (Caso con 8 tutores y 3 ausentes verificando 5 presentes y 3 ausentes con autoría y timestamp).
