---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-43: Configuración y Distribución Semanal de Tareas Docentes por Clase"
labels: ["user-story", "Should", "RF-25", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-25 · Configuración de roles y tareas dinámicas docentes
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio territorial), RNF-U-3 (Desktop para Directiva / Móvil para Gestión)
- **Reglas de negocio asociadas:** RB-6 (Acceso territorial por sede), RB-Catalogo-Dinamico (Directiva define el catálogo nacional de roles; Gestión asigna semanalmente en cada sede), RB-Equipo-Gestion-Es-Tutora (Todas las integrantes de Gestión son tutoras, pero tienen facultades de asignación)

---

### 👤 Historia de Usuario
> **Como** Directiva Nacional (en consola desktop) y Equipo de Gestión (en vista móvil de sede),  
> **queremos** configurar un catálogo dinámico y flexible de roles docentes (Facilitadora, Co-facilitadora, Soporte Técnico, Logística) y distribuir semanalmente a las tutoras de aula,  
> **para** profesionalizar la operación docente de cada sábado adaptándonos a las necesidades de cada módulo de programación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Configuración del catálogo de roles dinámicos por Directiva):** La Directiva Nacional en su pantalla de escritorio administra el catálogo institucional de roles (`rol_tarea_tutor`), pudiendo dar de alta nuevos roles con nombre, código, descripción (ej. `Facilitadora Principal`, `Co-facilitadora`, `Soporte Técnico`, `Logística y Registro`).
- [ ] **Escenario 2 (Asignación semanal en interfaz móvil por Equipo de Gestión):** Las integrantes del Equipo de Gestión en su celular acceden a la pestaña "Roles Tutores" para la semana en curso (ej. Semana 4) y asignan a cada tutora disponible de la sede su rol pedagógico mediante selectores táctiles vinculados a `tareas_semanales_tutores`.
- [ ] **Escenario 3 (Control de unicidad y reasignación ante imprevistos):** El sistema garantiza la unicidad de la asignación `(clase_id, tutor_id, rol_tarea_tutor_id)` y permite a Gestión conmutar o reasignar en tiempo real a otra tutora si alguna docente notifica imposibilidad de asistir el sábado.
- [ ] **Escenario 4 (Visibilidad coordinada):** Las tutoras pueden revisar en su móvil el rol asignado para la jornada sabatina, asegurando que cada una conozca sus funciones con anticipación.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Pestaña "Roles Dinámicos" en `DirectorioDesktopScreen` con formulario modal para nuevos roles; pestaña "Roles Tutores" en `GestionMobileScreen` con asignación semanal táctil.
- [ ] Backend / Lógica: Tabla `rol_tarea_tutor` y relación en `tareas_semanales_tutores` con claves foráneas y políticas RLS (en `20261010000001_initial_schema.sql`).
- [ ] Pruebas mínimas: TC-23 (Verificación de alta de rol en catálogo por Directiva y asignación semanal en móvil por Equipo de Gestión).
