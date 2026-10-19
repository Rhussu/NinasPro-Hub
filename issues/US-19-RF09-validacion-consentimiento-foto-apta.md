---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-19: Verificación de Autorizaciones de Imagen y Marcado de Foto Apta"
labels: ["user-story", "Must", "RF-09", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-9 · Registro de evidencia fotográfica
- **Requisitos no funcionales (Indirectos):** RNF-S-5 (Cumplimiento legal menores de edad), RNF-M-1 (Pruebas unitarias de reglas de negocio)
- **Reglas de negocio asociadas:** RB-2 (Autorización por canal), RB-3 (Verificación previa), RB-5 (Difusión sin identificación de alumnas)

---

### 👤 Historia de Usuario
> **Como** tutora que sube la evidencia de una clase,  
> **quiero** que el sistema me advierta si en el curso existen alumnas sin autorización de imagen y me exija declarar si sus rostros fueron cubiertos antes de marcar la foto como apta,  
> **para** evitar exponer indebidamente la imagen de menores de edad sin consentimiento explícito.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Advertencia de alumnas sin consentimiento):** Dada una clase donde participan alumnas que no cuentan con autorización de uso de imagen, cuando la tutora sube una fotografía, entonces el sistema despliega una advertencia listando los nombres de las alumnas sin autorización para ese canal.
- [ ] **Escenario 2 (Declaración de rostros cubiertos para marcar apta):** Dada la advertencia previa, cuando la tutora desea marcar la foto como `apta_para_evidencia`, entonces el sistema le exige marcar un checkbox declarando expresamente: "Confirmo que las alumnas sin autorización no son reconocibles o sus rostros fueron cubiertos/censurados".
- [ ] **Escenario 3 (Foto no apta por defecto):** Dada una fotografía donde no se pueda garantizar la censura de rostros de menores sin autorización, cuando la tutora guarda sin marcar la declaración, entonces la foto se conserva como respaldo interno pero con el indicador `apta_para_evidencia = false`.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Modal de verificación de autorizaciones de imagen con advertencia contextual y checkbox obligatorio de declaración de censura.
- [ ] Backend / Lógica: Validación de integridad en API para restringir el atributo `apta_para_evidencia = true` cuando existan menores sin consentimiento sin declaración confirmada.
- [ ] Pruebas mínimas: TC-12 / TC-34 (Verificación de bloqueo de foto como apta si falta consentimiento del apoderado y no se declaró censura).
