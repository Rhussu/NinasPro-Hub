---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-07: Carga Masiva de Nómina de Alumnas vía CSV/XLSX con Previsualización"
labels: ["user-story", "Must", "RF-03", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-3 · Ingreso de nueva nómina de alumnas
- **Requisitos no funcionales (Indirectos):** RNF-C-2 (Formatos CSV UTF-8 y XLSX), RNF-S-5 (Cumplimiento legal menores)
- **Reglas de negocio asociadas:** RB-1 (Consentimiento previo), RB-8 (Minimización de datos)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** cargar archivos de nómina de alumnas preseleccionadas en formatos CSV (UTF-8) o XLSX y previsualizar un resumen antes de guardar,  
> **para** matricular de forma rápida y masiva a las beneficiarias de una sección sin cometer errores de importación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Previsualización de carga masiva):** Dado un archivo de nómina válido con 30 registros, cuando el Directorio lo sube a la instancia del curso, entonces el sistema procesa el archivo y despliega una pantalla de confirmación desglosando alumnas nuevas por crear, alumnas ya existentes en el sistema y filas inválidas.
- [ ] **Escenario 2 (Confirmación e inserción de matrículas):** Dado el resumen de previsualización con 28 filas válidas, cuando el usuario presiona "Confirmar Carga", entonces el sistema registra las 28 inscripciones en estado "preinscrita" asociadas a la instancia del curso.
- [ ] **Escenario 3 (Soporte de caracteres especiales en importación):** Dado un archivo CSV codificado en UTF-8 o planilla XLSX que contiene nombres con tildes, diéresis y la letra 'ñ', cuando se completa la carga, entonces todos los caracteres se almacenan de forma íntegra sin corrupción ni pérdida.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Componente de arrastrar y soltar archivo (Drag & Drop) y modal de previsualización y resumen de importación.
- [ ] Backend / Lógica: Parser de archivos CSV y XLSX con validación de codificación UTF-8 e inserción transaccional por lotes.
- [ ] Pruebas mínimas: Prueba de carga con archivo XLSX conteniendo acentos, 'ñ' y nombres compuestos verificando persistencia íntegra.
