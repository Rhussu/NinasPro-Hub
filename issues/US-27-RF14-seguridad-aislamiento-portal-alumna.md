---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-27: Seguridad y Aislamiento Estricto del Portal de la Alumna"
labels: ["user-story", "Must", "RF-14", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-14 · Portal de la alumna
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio / RLS), RNF-S-4 (Auditoría de eventos críticos)
- **Reglas de negocio asociadas:** RB-6 (Una alumna solo puede acceder a sus propios datos)

---

### 👤 Historia de Usuario
> **Como** oficial de seguridad de la información,  
> **quiero** que la plataforma impida de forma absoluta que una alumna pueda ver la asistencia, notas o datos personales de otras compañeras mediante manipulación de URLs o parámetros de API,  
> **para** salvaguardar la privacidad de las menores y evitar la comparación de pares o discriminación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Aislamiento de datos propios):** Dada una alumna autenticada con su usuario en el sistema, cuando consulta sus endpoints de asistencia o perfil, entonces la respuesta de la base de datos contiene exclusivamente sus propios registros.
- [ ] **Escenario 2 (Intento de alteración de ID en URL denegado):** Dada una alumna que intenta acceder al portal o datos de otra alumna modificando el parámetro de ID en la barra de direcciones o en una petición HTTP, cuando el servidor procesa la solicitud, entonces retorna inmediatamente HTTP 403 Forbidden y bloquea la entrega de datos.
- [ ] **Escenario 3 (Registro del incidente en auditoría):** Dado el intento denegado del Escenario 2, cuando se produce la respuesta 403, entonces el sistema genera automáticamente un registro en la auditoría indicando la cuenta que originó el intento y el recurso ajeno solicitado.

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Políticas RLS estrictas en PostgreSQL basadas en `auth.uid() = alumna.perfil_id` para todas las lecturas de la alumna.
- [ ] Backend / Lógica: Middleware/Interceptors que capturen peticiones de recursos con IDs ajenos y generen logs de seguridad.
- [ ] Pruebas mínimas: TC-17 / TC-32 / AT-8 (Prueba de cambio intencional de identificador en URL verificando HTTP 403 y registro en auditoría).
