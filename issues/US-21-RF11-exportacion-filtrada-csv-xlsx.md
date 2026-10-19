---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-21: Exportación Filtrada de Asistencia, Nóminas y Participación en CSV/XLSX"
labels: ["user-story", "Must", "RF-11", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-11 · Exportación de datos
- **Requisitos no funcionales (Indirectos):** RNF-C-2 (CSV UTF-8 y XLSX sin pérdida de tildes ni RUT), RNF-S-2 (Mínimo privilegio)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede), RB-7 (Trazabilidad de cambios y descargas)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio o del Equipo de Gestión,  
> **quiero** seleccionar el tipo de reporte (asistencia, nómina o participación) y aplicar filtros por sede, curso y período para descargarlo en formato CSV (UTF-8) o XLSX,  
> **para** analizar la información sin intermediarios y consolidar planillas oficiales sin inconsistencias de conteo.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Generación de reporte filtrado en CSV/XLSX):** Dado el filtro seleccionado (ej. Sede Concepción, segundo semestre 2026, Asistencia), cuando el usuario pulsa descargar en XLSX o CSV, entonces el sistema genera el archivo en menos de 3 segundos con exactamente una fila por alumna y clase.
- [ ] **Escenario 2 (Integridad de caracteres especiales y RUT):** Dado un archivo exportado abierto en Microsoft Excel o Google Sheets, cuando se revisa su contenido, entonces los caracteres con tildes, diéresis, letra 'ñ' y los formatos de RUT chileno se muestran de manera íntegra y legible sin fallas de codificación.
- [ ] **Escenario 3 (Delimitación por sede para Equipo de Gestión):** Dado un usuario con rol Equipo de Gestión de la sede A, cuando ingresa al módulo de exportación, entonces el selector de sede queda fijado en la sede A sin opción de exportar datos de otras sedes regionales.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario de exportación con selectores de tipo de reporte, sede, curso, rango de fechas y formato (CSV/XLSX).
- [ ] Backend / Lógica: Generador de archivos estructurados en CSV con codificación UTF-8 con BOM y XLSX mediante librerías estándar.
- [ ] Pruebas mínimas: TC-14 (Exportación con filtros) y TC-15 (Apertura y validación de tildes, 'ñ' y formato de RUT en Excel y Google Sheets).
