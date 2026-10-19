---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-30: Carga Masiva e Individual de Fichas de Voluntariado vía CSV/XLSX"
labels: ["user-story", "Must", "RF-23", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-23 · Registro de voluntariado
- **Requisitos no funcionales (Indirectos):** RNF-C-2 (Formatos CSV UTF-8 / XLSX), RNF-S-5 (Cumplimiento datos de contacto)
- **Reglas de negocio asociadas:** RB-10 (Conservación por 5 años desde salida)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** incorporar voluntarias y tutores a la plataforma ya sea individualmente o mediante importación masiva en CSV/XLSX validando su RUT y datos de contacto,  
> **para** centralizar en una sola base común el padrón de voluntarias de todas las sedes de la corporación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Carga masiva con reporte de inconsistencias):** Dada una planilla de 8 filas donde 2 filas contienen RUTs inválidos, cuando el Directorio ejecuta la importación, entonces el sistema inscribe exitosamente a las 6 voluntarias válidas y genera un reporte descargable detallando las 2 filas rechazadas con su motivo.
- [ ] **Escenario 2 (Persistencia multi-sede y multi-año de la ficha):** Dado un tutor que colaboró en la sede A en 2025, cuando se registra su participación en la sede B en 2026, entonces el sistema mantiene su ficha de perfil única identificada por su RUT y añade su nueva asignación histórica sin duplicar registros.
- [ ] **Escenario 3 (Alta manual individual):** Dado que se incorpora una voluntaria fuera del período masivo, cuando el Directorio completa el formulario individual con nombre, RUT, correo, institución/ocupación y rol, entonces se crea su ficha en estado activo.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Módulo de carga masiva de voluntariado con previsualización y formulario de alta manual.
- [ ] Backend / Lógica: Validación de formato de RUT chileno (módulo 11) e inserción en tablas `perfiles` y `voluntarios_detalle`.
- [ ] Pruebas mínimas: TC-18 (Prueba con planilla de 8 filas con 2 RUTs inválidos verificando 6 creadas y 2 rechazadas).
