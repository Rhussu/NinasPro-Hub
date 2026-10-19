---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-20: Monitoreo y Alerta de Clases con Evidencia Pendiente tras 48 Horas"
labels: ["user-story", "Must", "RF-09", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-9 · Registro de evidencia fotográfica
- **Requisitos no funcionales (Indirectos):** RNF-U-3 (Interfaz responsiva en español), RNF-S-2 (Mínimo privilegio)
- **Reglas de negocio asociadas:** RB-6 (Acceso por sede)

---

### 👤 Historia de Usuario
> **Como** integrante del Equipo de Gestión de una sede,  
> **quiero** visualizar de forma destacada aquellas clases realizadas que lleven más de 48 horas sin una fotografía de evidencia subida,  
> **para** recordar oportunamente a las tutoras responsables la carga de la foto y evitar retrasos en la rendición a los patrocinantes.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización de clases con evidencia pendiente):** Dada una sesión con asistencia guardada (estado "realizada") que no posee fotos vinculadas tras transcurrir más de 48 horas, cuando el Equipo de Gestión accede a su panel de sede, entonces la sesión aparece listada en la sección "Evidencias pendientes".
- [ ] **Escenario 2 (Eliminación de la alerta tras la carga):** Dada una clase catalogada con evidencia pendiente, cuando una tutora sube una fotografía válida y la asocia a la clase, entonces la sesión desaparece automáticamente de la lista de pendientes de la sede.
- [ ] **Escenario 3 (Aislamiento por sede):** Dado un usuario del Equipo de Gestión de la sede Concepción, cuando consulta las evidencias pendientes, entonces solo visualiza las clases de su sede sin acceder a las de otras sedes regionales.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Tarjeta y filtro de "Evidencias pendientes (> 48 hrs)" en el panel del Equipo de Gestión.
- [ ] Backend / Lógica: Consulta SQL optimizada que filtra clases realizadas con fecha anterior a `NOW() - INTERVAL '48 HOURS'` sin registros en `evidencias_fotograficas`.
- [ ] Pruebas mínimas: TC-12 (Prueba de clase realizada hace más de 48h verificando que figure como pendiente hasta que se sube una foto).
