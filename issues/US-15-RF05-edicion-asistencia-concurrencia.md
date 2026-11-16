---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-15: Edición Posterior y Resolución Concurrente de Asistencia"
labels: ["user-story", "Must", "RF-05", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-5 · Registro de asistencia de alumnas por clase
- **Requisitos no funcionales (Indirectos):** RNF-S-4 (Auditoría), RNF-M-1 (Cobertura en reglas críticas)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad de cambios: valor anterior, autora y fecha)

---

### 👤 Historia de Usuario
> **Como** tutora o integrante del Equipo de Gestión,  
> **quiero** reabrir la lista de una clase para corregir el estado de una alumna que llegó tarde o corregir errores posteriores antes del cierre del período,  
> **para** mantener actualizada y veraz la asistencia oficial sin que guardados simultáneos corrompan los datos.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Corrección por llegada tardía):** Dada una alumna marcada inicialmente como "Ausente", cuando llega atrasada y la tutora reabre la lista, cambia su estado a "Presente" y guarda, entonces el registro se actualiza y la auditoría registra la modificación con la autora y la hora.
- [ ] **Escenario 2 (Resolución de guardado concurrente entre dos tutoras):** Dado que dos tutoras abren y modifican simultáneamente la misma lista de clase, cuando ambas presionan guardar, entonces prevalece el último guardado en la tabla operativa y el estado inmediatamente anterior queda preservado en la bitácora de auditoría.
- [ ] **Escenario 3 (Edición extemporánea hasta el cierre del ciclo):** Dado un reclamo justificado de asistencia formulado semanas después, cuando el Equipo de Gestión de la sede edita el registro antes del cierre del semestre, entonces el sistema permite la actualización y genera el evento de auditoría correspondiente.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista de reapertura y modificación de asistencia con visualización de última persona que editó.
- [ ] Backend / Lógica: Operación transaccional con trigger que registra el valor anterior en `auditoria_cambios_datos`.
- [ ] Pruebas mínimas: TC-09 (Simulación de dos guardados concurrentes verificando persistencia del último guardado e inserción en auditoría).

---

### 📝 Ajustes del MVP
- La **Directiva puede hacer todo** lo de Gestión en cualquier sede, como entrada secundaria en *Ajustes → Gestión en todas las sedes* (decidido el 2026-11-16).
