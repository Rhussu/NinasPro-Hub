---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-23: Registro Automático e Inmutable de Modificaciones y Accesos a Datos"
labels: ["user-story", "Must", "RF-12", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-12 · Registro de auditoría
- **Requisitos no funcionales (Indirectos):** RNF-S-4 (Auditoría y trazabilidad quién/qué/cuándo), RNF-S-3 (Cifrado AES-256 en reposo)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad de cambios), RB-10 (Conservación por 5 años), RB-13 (Preservación de evidencia)

---

### 👤 Historia de Usuario
> **Como** oficial de seguridad y auditoría de la plataforma,  
> **quiero** que el sistema registre de forma automática, estructurada e inmutable cada modificación, creación, eliminación o intento fallido de acceso sobre los datos de las alumnas,  
> **para** garantizar la integridad forense de los registros y responder con certeza ante disputas o requerimientos legales.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Captura de valor anterior y nuevo en formato JSONB):** Dada una corrección en la asistencia de una alumna o en sus datos personales, cuando la modificación se persiste en la base de datos, entonces el trigger de auditoría inserta un registro en `auditoria_cambios_datos` con el identificador del usuario ejecutor, marca de tiempo y las estructuras JSONB con los valores previos y posteriores.
- [ ] **Escenario 2 (Inmutabilidad estricta de la bitácora):** Dado un registro existente en las tablas de auditoría, cuando cualquier usuario (incluso con privilegios de administrador o desarrollador) intente ejecutar operaciones de `UPDATE` o `DELETE`, entonces la base de datos rechaza la instrucción mediante políticas y revocación estricta de permisos (RB-13).
- [ ] **Escenario 3 (Registro de accesos no autorizados o denegados):** Dado un intento de consulta o manipulación de un registro fuera del alcance de la sede o perfil del usuario, cuando el sistema deniega el acceso con error HTTP 403, entonces se genera una entrada de auditoría registrando el intento y los parámetros solicitados.

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Tablas `auditoria_cambios_datos` y `auditoria_accesos_descargas` con campos JSONB para deltas.
- [ ] Backend / Lógica: Triggers en PostgreSQL para capturar eventos de inserción, actualización y eliminación en tablas sensibles (`alumnas`, `asistencia_alumnas`, `justificativos_inasistencia`).
- [ ] Pruebas mínimas: TC-16 (Verificación de conservación de valor anterior, autora y fecha en modificación de asistencia, y comprobación de inmutabilidad ante intento de UPDATE/DELETE).
