---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-34: Modo Offline y Trazabilidad de Asistencia Docente"
labels: ["user-story", "Must", "RF-24", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-24 · Registro de asistencia de tutores por clase
- **Requisitos no funcionales (Indirectos):** RNF-D-2 (Recuperación y continuidad), RNF-U-2 (Autonomía de uso en celular)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad)

---

### 👤 Historia de Usuario
> **Como** tutora designada registrando la asistencia de tutores con conexión móvil intermitente,  
> **quiero** que el registro de asistencia docente se conserve localmente si se corta la red y se envíe automáticamente al restablecerse,  
> **para** asegurar que la asistencia de voluntarias quede registrada sin interrupciones operativas en la sala.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Retención local por corte de conectividad):** Dado que la tutora guarda la lista de asistencia docente y el celular pierde conexión a internet, cuando se presiona confirmar, entonces la información queda asegurada en el navegador y se muestra la etiqueta "Pendiente de envío".
- [ ] **Escenario 2 (Sincronización automática sin reingreso):** Dado el registro retenido en el navegador, cuando el dispositivo vuelve a conectarse a wifi o datos móviles, entonces el sistema reenvía automáticamente la lista sin requerir que la tutora vuelva a pasar lista.
- [ ] **Escenario 3 (Resolución de guardados simultáneos):** Dado que dos tutoras guardan concurrentemente la asistencia del equipo, cuando ambas peticiones llegan al servidor, entonces prevalece el último guardado registrando la versión previa en la auditoría.

---

### 🛠️ Tareas
- [ ] Frontend / Lógica: Integración de la asistencia docente al manejador unificado de sincronización offline en cliente.
- [ ] Backend / Lógica: Manejo idempotente de inserciones en `asistencia_tutores` para evitar duplicidad tras reintentos de red.
- [ ] Pruebas mínimas: TC-08 / TC-09 aplicados a asistencia docente con verificación de reenvío automático tras corte de conexión.
