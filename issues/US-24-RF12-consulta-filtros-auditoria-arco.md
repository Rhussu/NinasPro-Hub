---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-24: Consulta y Filtros de Auditoría para Cumplimiento y Derechos ARCO"
labels: ["user-story", "Must", "RF-12", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-12 · Registro de auditoría
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-S-4 (Auditoría trazable), RNF-S-5 (Derechos ARCO Ley 19.628 / 21.719)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** consultar la bitácora de auditoría mediante filtros avanzados por persona, alumna, tipo de acción y rango de fechas,  
> **para** atender solicitudes de derechos de acceso (ARCO) de apoderados que deseen conocer quién ha visualizado o modificado los datos de su hija.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Filtrado de bitácora por alumna para derecho de acceso):** Dado un apoderado que ejerce formalmente su derecho de acceso sobre los datos de su hija, cuando el Directorio filtra la auditoría por el RUT de la alumna, entonces el sistema despliega el historial completo de accesos, modificaciones y consultas vinculadas a esa menor.
- [ ] **Escenario 2 (Filtro por usuaria o voluntaria):** Dado un caso de sospecha de fuga de información o auditoría interna, cuando el Directorio filtra por el ID o correo de una voluntaria, entonces se listan todas las acciones ejecutadas por dicha cuenta en un rango de fechas.
- [ ] **Escenario 3 (Auditoría reservada a la Directiva):** Dado un usuario del Equipo de Gestión, Tutora o Alumna, cuando abre su pantalla o sus Ajustes, entonces no encuentra el visor de auditoría; si una tutora o alumna lo invoca por la API, el sistema responde 403 y registra el intento como *acceso denegado*.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Panel de visor de auditoría con filtros por fecha, usuario, tipo de acción y RUT de alumna.
- [ ] Backend / Lógica: Políticas RLS y consultas optimizadas sobre `auditoria_cambios_datos` y `auditoria_accesos_descargas`.
- [ ] Pruebas mínimas: TC-16 (Verificación de consulta de auditoría filtrada por alumna para responder a solicitud de derecho de acceso).

---

### 📝 Ajustes del MVP
- En la app, la auditoría es **solo de la Directiva**; Gestión no la tiene en Ajustes (decidido el 2026-11-16, PR 8). La base (`consultar_auditoria`) acotaría a su sede una consulta de Gestión, pero la app no le da esa vista.
- La auditoría registra cambios, descargas y accesos denegados; no registra cada apertura de ficha (las "consultas" del escenario 1) (decidido el 2026-11-16).
