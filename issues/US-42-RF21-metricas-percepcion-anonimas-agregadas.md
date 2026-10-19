---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-42: Consolidación Agregada y Anónima de Métricas de Percepción"
labels: ["user-story", "Should", "RF-21", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-21 · Encuestas de percepción y retroalimentación
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-S-5 (Disociación y protección de anonimato)
- **Reglas de negocio asociadas:** RB-6 (Acceso por rol/sede), RB-9 (Datos agregados)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio o Equipo de Gestión,  
> **quiero** consultar los resultados consolidados de las encuestas mensuales en forma de promedios agregados y comentarios anónimos por curso y sede,  
> **para** identificar oportunamente oportunidades de mejora pedagógica o clima grupal sin vulnerar el anonimato de las alumnas participantes.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización de promedios agregados):** Dado que se han registrado respuestas para una encuesta mensual en una sede, cuando el Directorio o Equipo de Gestión abre el informe del mes, entonces visualiza el promedio general de satisfacción por pregunta en escala 1 a 5 y el porcentaje de participación del curso.
- [ ] **Escenario 2 (Disociación estricta de respuestas cualitativas):** Dado el listado de comentarios cualitativos abiertos, cuando el equipo docente los lee, entonces el sistema los presenta desvinculados de cualquier dato de identidad (sin RUT, nombre, ni identificador de inscripción).
- [ ] **Escenario 3 (Resguardo en grupos pequeños):** Dado un curso con muy pocas respuestas recopiladas (ej. menos de 5), cuando se visualizan los resultados, entonces el sistema advierte que la muestra reducida requiere cautela interpretativa para resguardar la confidencialidad.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista de métricas de satisfacción con gráficos de distribución y comentarios anónimos desglosados por curso/mes.
- [ ] Backend / Lógica: Query SQL analítica con funciones de agregación `AVG()` y desvinculación selectiva de campos identificatorios.
- [ ] Pruebas mínimas: TC-22 (Verificación de entrega de datos agregados y disociados sin exposición de identidad de alumnas).
