---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-08: Validación Estricta de Formato, Columnas y RUT Chileno (Módulo 11)"
labels: ["user-story", "Must", "RF-03", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-3 · Ingreso de nueva nómina de alumnas
- **Requisitos no funcionales (Indirectos):** RNF-C-2 (APIs y formatos), RNF-S-5 (Cumplimiento legal)
- **Reglas de negocio asociadas:** RB-8 (Minimización y finalidad)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** que el sistema valide estrictamente la estructura de columnas y el dígito verificador del RUT de cada alumna y apoderado reportando errores fila a fila,  
> **para** evitar el ingreso de datos corruptos o identidades inconsistentes a la base corporativa.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Rechazo de archivo por estructura de columnas no conforme):** Dado un archivo subido cuyas cabeceras no coinciden exactamente con la plantilla estándar descargable del sistema, cuando se procesa el archivo, entonces el sistema rechaza la carga completa y notifica qué columnas faltan o están desalineadas.
- [ ] **Escenario 2 (Detección de RUT inválido o duplicado en la misma planilla):** Dada una planilla de 30 filas donde 2 filas contienen RUTs con dígito verificador inválido (falla módulo 11) o repetidos dentro del archivo, cuando se analiza la planilla, entonces el sistema inscribe a las 28 válidas y genera una tabla descargable con las 2 filas rechazadas indicando número de fila y motivo específico.
- [ ] **Escenario 3 (Validación de datos obligatorios de contacto del apoderado):** Dada una fila donde faltan los datos requeridos de contacto del apoderado (correo y teléfono), cuando se procesa, entonces esa fila se rechaza informando que los datos de contacto son obligatorios por protocolo institucional.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Tabla interactiva con desglose de filas con advertencias y errores descargable en CSV/XLSX.
- [ ] Backend / Lógica: Algoritmo de validación de RUT chileno (módulo 11) estricto y validador de esquema de columnas de la plantilla.
- [ ] Pruebas mínimas: TC-04 (Prueba unitaria/integración con 30 filas y 2 RUTs inválidos verificando resultado 28 inscritas / 2 rechazadas).
