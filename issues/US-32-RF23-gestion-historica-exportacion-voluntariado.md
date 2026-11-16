---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-32: Gestión Histórica y Exportación de la Red de Voluntariado por Sede"
labels: ["user-story", "Must", "RF-23", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-23 · Registro de voluntariado
- **Requisitos no funcionales (Indirectos):** RNF-C-2 (Exportación CSV y XLSX), RNF-S-2 (Mínimo privilegio)
- **Reglas de negocio asociadas:** RB-10 (Ciclo de vida y retención de voluntariado)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** consultar el directorio general de voluntariado filtrando por sede, rol, curso y estado (activo/retirado), y exportar los datos consolidados,  
> **para** gestionar el capital humano de la corporación y generar los informes institucionales para la memoria anual.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Filtrado de voluntariado por sede y período):** Dado el módulo de voluntariado, cuando el Directorio aplica filtros por sede (ej. Valparaíso) y rol (ej. Tutora), entonces el sistema lista a todas las personas asignadas con sus fechas de ingreso y cursos en que han participado.
- [ ] **Escenario 2 (Registro de fecha de salida y estado retirado):** Dada una voluntaria que culmina su participación en la corporación, cuando el Directorio registra su fecha de desvinculación, entonces su estado pasa a retirado conservando su trayectoria histórica (la fecha de salida debe ser mayor o igual a la de ingreso).
- [ ] **Escenario 3 (Exportación del listado de voluntariado):** Dado el listado filtrado de voluntariado, cuando el Directorio pulsa "Exportar", entonces se descarga un archivo CSV/XLSX con los datos institucionales correspondientes.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista de directorio de voluntarias con filtros facetados por sede, rol, período y estado.
- [ ] Backend / Lógica: Endpoint de consulta con agregación de cursos cursados y soporte de exportación a CSV/XLSX.
- [ ] Pruebas mínimas: TC-18 (Prueba de exportación de listado de voluntariado por sede, rol y período).

---

### 📝 Ajustes del MVP
- La exportación del voluntariado es solo de la Directiva; Gestión ve el voluntariado de su sede en solo lectura, sin exportar (decidido el 2026-11-16, PR 8).
