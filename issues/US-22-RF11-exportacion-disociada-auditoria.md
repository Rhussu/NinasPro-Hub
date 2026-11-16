---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-22: Exportación Disociada de Registros y Trazabilidad de Descargas"
labels: ["user-story", "Must", "RF-11", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-11 · Exportación de datos
- **Requisitos no funcionales (Indirectos):** RNF-S-4 (Auditoría trazable), RNF-S-5 (Disociación y minimización Ley 19.628 / 21.719)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad de cambios y descargas), RB-9 (Solo cifras disociadas a terceros)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** generar exportaciones con datos disociados (reemplazando nombres y RUTs por códigos únicos anónimos) y que toda descarga quede registrada en la bitácora de auditoría,  
> **para** compartir datos estadísticos con investigadoras o patrocinadores sin vulnerar la privacidad de las menores y mantener la trazabilidad de la fuga de datos.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Exportación anonimizada / disociada):** Dado que el Directorio selecciona la opción "Modo disociado / anónimo", cuando descarga el archivo de asistencia o participación, entonces los campos `nombres`, `apellidos` y `rut` son sustituidos por un identificador sintético consistente (ej. `ALUMNA-001`), preservando la capacidad de análisis estadístico.
- [ ] **Escenario 2 (Registro automático en auditoría de descargas):** Dado que cualquier usuario autorizado completa una exportación de datos, cuando se genera el archivo, entonces el sistema inserta de inmediato una fila inmutable en `auditoria_accesos_descargas` con usuario, sede, curso, formato, cantidad de filas y fecha/hora exacta.
- [ ] **Escenario 3 (Manejo de filtros sin registros):** Dado un filtro de consulta que no contiene registros (ej. curso sin clases en el rango), cuando se solicita la exportación, entonces el sistema entrega un archivo conteniendo únicamente los encabezados de columna acompañado de un mensaje informativo claro.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Checkbox "Exportar con datos disociados (anonimizado)" en el diálogo de exportación.
- [ ] Backend / Lógica: Transformador de datos disociados y trigger/servicio de registro en tabla `auditoria_accesos_descargas`.
- [ ] Pruebas mínimas: TC-14 (Verificación de generación de evento en auditoría con filtros y cantidad de filas tras descarga).

---

### 📝 Ajustes del MVP
- La vista previa no queda en la auditoría; la descarga se registra en la misma llamada a `exportar_reporte` (PR 7).
