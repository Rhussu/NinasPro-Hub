---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-12: Revocación de Autorizaciones de Imagen y Actualización de Aptitud"
labels: ["user-story", "Must", "RF-04", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-4 · Registro de autorizaciones del apoderado
- **Requisitos no funcionales (Indirectos):** RNF-S-4 (Auditoría), RNF-S-5 (Cumplimiento legal y derechos ARCO)
- **Reglas de negocio asociadas:** RB-3 (Verificación previa), RB-4 (Revocación de autorización)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** registrar la revocación de una autorización de imagen solicitada por el apoderado registrando la fecha exacta,  
> **para** que las fotografías donde la alumna sea reconocible dejen de ser aptas para difusión desde dicha fecha en adelante, respetando los derechos de la menor.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Registro formal de revocación):** Dado un apoderado que solicita revocar el uso de imagen de su hija para uno o todos los canales, cuando el Directorio actualiza el estado a "revocada" ingresando la fecha de solicitud, entonces el sistema guarda la modificación e inhabilita dicho consentimiento para publicaciones futuras.
- [ ] **Escenario 2 (Impacto en la aptitud de evidencias):** Dada una alumna cuya autorización fue revocada con fecha D, cuando el sistema evalúa las fotos de clases tomadas a partir de la fecha D donde la alumna esté registrada sin rostro cubierto, entonces el sistema las desmarca automáticamente como aptas para el canal correspondiente (RB-4).
- [ ] **Escenario 3 (Conservación de usos históricos anteriores):** Dado que la revocación rige a partir de su fecha de notificación, cuando se consultan reportes o evidencias cerradas antes de la fecha D, entonces se mantienen los registros históricos inmutables en concordancia con los protocolos institucionales (REF-5).

---

### 🛠️ Tareas
- [ ] Frontend / UI: Opción de "Revocar Autorización" con registro de fecha y motivo en la ficha de la alumna.
- [ ] Backend / Lógica: Actualización de estado en `autorizaciones_apoderado` y reclasificación de aptitud en `evidencias_fotograficas`.
- [ ] Pruebas mínimas: TC-06 / TC-12 (Verificación de revocación y cambio de aptitud de evidencias posteriores).

---

### 📝 Ajustes del MVP
- Las revocaciones son solo de la Directiva; Gestión no las edita (decidido el 2026-11-16).
