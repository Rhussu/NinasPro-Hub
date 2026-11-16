---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-36: Adjuntar Evidencia Documental con Minimización de Datos Sensibles de Salud"
labels: ["user-story", "Should", "RF-06", "Seguridad", "fuera-del-MVP"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-6 · Registro de justificativos
- **Requisitos no funcionales (Indirectos):** RNF-S-3 (TLS y almacenamiento cifrado), RNF-S-5 (Cumplimiento de datos de salud Ley 19.628 / 21.719)
- **Reglas de negocio asociadas:** RB-8 (Minimización y finalidad: no solicitar diagnósticos clínicos médicos)

---

### 👤 Historia de Usuario
> **Como** alumna o apoderada que adjunta un documento de respaldo para justificar una falta,  
> **quiero** subir un archivo PDF o imagen con una advertencia clara de no ingresar recetas con diagnósticos médicos reservados,  
> **para** respaldar documentalmente la ausencia cumpliendo estrictamente con la normativa de privacidad y protección de la intimidad.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Carga segura de archivo de respaldo):** Dada una alumna que redacta su justificativo, cuando adjunta una fotografía o archivo PDF de constancia (médica general, escolar o familiar) de hasta 5 MB, entonces el sistema lo sube a un bucket privado cifrado con AES-256.
- [ ] **Escenario 2 (Aviso explícito de minimización de datos):** Dado el formulario de adjuntos, cuando el usuario va a subir un documento, entonces el sistema muestra una advertencia destacada: "Por tu privacidad y conforme a la ley, no ingreses diagnósticos médicos ni datos de salud sensibles. Solo se requiere constancia de atención o motivo general".
- [ ] **Escenario 3 (Validación de tipos de archivo permitidos):** Dado un intento de subir archivos ejecutables o no admitidos, cuando el sistema valida la extensión, entonces rechaza el archivo y permite únicamente formatos seguros (`.pdf`, `.png`, `.jpg`, `.jpeg`).

---

### 🛠️ Tareas
- [ ] Frontend / UI: Campo de subida con filtro MIME, barra de progreso y cartel institucional de privacidad.
- [ ] Backend / Lógica: Validación de formato y almacenamiento en Supabase Storage con políticas privadas.
- [ ] Pruebas mínimas: TC-19 / TC-34 (Verificación de subida cifrada y cumplimiento de directrices de minimización de salud).

---

### 📝 Ajustes del MVP
- **Fuera del MVP por ahora:** los justificativos son solo texto, sin archivos adjuntos; no hay bucket `justificativos` (decidido el 2026-11-16). El aviso de privacidad del escenario 2 sí está, en el formulario de US-35.
