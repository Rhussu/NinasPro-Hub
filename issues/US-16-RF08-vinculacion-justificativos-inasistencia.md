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
> **Como** integrante del Equipo de Gestión de la sede,  
> **quiero** vincular un justificativo (texto explicativo, sin archivos adjuntos) a una inasistencia previa seleccionando un motivo tipificado por catálogo,  
> **para** que el estado de la inasistencia cambie automáticamente a "justificada" y quede respaldada operativamente.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Vinculación de justificativo exitosa):** Dada una inasistencia previamente registrada para una alumna, cuando el usuario abre la inasistencia, selecciona un motivo del catálogo (salud, académico, familiar, transporte u otro), escribe un texto y guarda, entonces el justificativo queda aceptado y el estado de la inasistencia pasa inmediatamente a "justificada". Si la alumna ya envió uno pendiente para esa clase, Gestión lo resuelve en la bandeja (US-37) en vez de registrar otro.
- [ ] **Escenario 2 (Justificativo anticipado para clase futura):** Dado que un apoderado notifica con antelación una inasistencia para el próximo sábado, cuando el Equipo de Gestión ingresa el justificativo sobre la sesión programada, entonces al momento de pasar lista la alumna se precarga con estado "justificada".
- [ ] **Escenario 3 (Eliminación por error y reversión de estado):** Dado un justificativo vinculado erróneamente a una alumna, cuando la persona encargada lo elimina con confirmación, entonces el registro del justificativo se retira y el estado de asistencia revierte automáticamente a "ausente".

---

### 🛠️ Tareas
- [ ] Frontend / UI: Acción *Ingresar justificativo* en la bandeja de Gestión (`justificativos_gestion.dart`), con aviso de privacidad.
- [ ] Backend / Lógica: RPC `registrar_justificativo` y `eliminar_justificativo` (Gestión de la sede) sobre la tabla `justificativos`, con sincronización del estado en `asistencia_alumnas`.
- [ ] Pruebas mínimas: TC-11 (Prueba de vinculación de texto y transición de ausente a ausente justificada).

---

### 📝 Ajustes del MVP
- Quién justifica: la alumna (queda pendiente, US-35) y Gestión (queda aceptado). Las tutoras no registran justificativos (decidido el 2026-11-16).
- Los justificativos son **solo texto, sin archivos adjuntos** (US-36 fuera por ahora).
- Una clase justificada **sigue contando como ausente**; el justificativo aceptado solo baja la meta al 70 % (ver US-25).
- La **Directiva puede hacer todo** lo de Gestión en cualquier sede, como entrada secundaria en *Ajustes → Gestión en todas las sedes* (decidido el 2026-11-16).
