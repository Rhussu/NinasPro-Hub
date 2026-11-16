---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-10: Registro y Respaldo Documental de Autorizaciones del Apoderado"
labels: ["user-story", "Must", "RF-04", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-4 · Registro de autorizaciones del apoderado
- **Requisitos no funcionales (Indirectos):** RNF-S-3 (TLS y AES-256), RNF-S-4 (Auditoría), RNF-S-5 (Cumplimiento legal Ley 19.628 / 21.719)
- **Reglas de negocio asociadas:** RB-1 (Consentimiento informado previo), RB-2 (Autorización de imagen por canal)

---

### 👤 Historia de Usuario
> **Como** integrante de la Directiva,  
> **quiero** registrar las autorizaciones firmadas por el apoderado (tratamiento de datos y uso de imagen desglosado por canal) adjuntando el respaldo digital,  
> **para** respaldar legalmente la participación de las menores de edad conforme a la Ley N° 19.628 y su reforma Ley N° 21.719.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Registro de autorizaciones independientes):** Dada una alumna inscrita, cuando el usuario abre su ficha y marca como otorgada la autorización de tratamiento de datos y especifica el estado para cada canal de imagen (redes sociales, memoria anual, prensa, web institucional, patrocinadores), adjuntando el documento en PDF/imagen, entonces el registro se guarda con fecha, respaldo y usuario responsable.
- [ ] **Escenario 2 (Canal sin respuesta por defecto no autorizado):** Dado el registro de autorizaciones de imagen, cuando un canal no tiene respuesta explícita del apoderado en el consentimiento, entonces el sistema asigna automáticamente el valor `falso` (no autorizado) por defecto (RB-2).
- [ ] **Escenario 3 (Almacenamiento seguro del respaldo documental):** Dado el archivo firmado subido como respaldo, cuando se almacena en el repositorio en la nube, entonces se transfiere cifrado bajo TLS 1.3 y se almacena en reposo con cifrado AES-256.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario de autorizaciones con carga de documento firmado y lista de verificación por canal de imagen.
- [ ] Backend / Lógica: Tablas `autorizaciones_apoderado` y `autorizaciones_imagen_canales` con campos de auditoría y almacenamiento de URL segura.
- [ ] Pruebas mínimas: Verificación de estado no autorizado por defecto para canales sin selección explícita.

---

### 📝 Ajustes del MVP
- Las autorizaciones del apoderado y sus revocaciones son solo de la Directiva; Gestión no las edita (decidido el 2026-11-16).
