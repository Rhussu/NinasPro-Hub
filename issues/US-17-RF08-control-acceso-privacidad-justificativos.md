---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-17: Control de Acceso y Minimización de Datos en Justificativos"
labels: ["user-story", "Must", "RF-08", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-8 · Vinculación de justificativos a clase
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-S-3 (TLS y AES-256), RNF-S-5 (Protección de datos sensibles Ley 19.628 / 21.719)
- **Reglas de negocio asociadas:** RB-6 (Acceso según rol/sede), RB-8 (Minimización: prohibido almacenar diagnósticos médicos clínicos)

---

### 👤 Historia de Usuario
> **Como** oficial de privacidad y seguridad de Niñas Pro,  
> **quiero** que los justificativos solo sean visibles para el Equipo de Gestión de la sede y la Directiva, y que el sistema no almacene diagnósticos médicos clínicos sensibles,  
> **para** resguardar la intimidad y los datos de salud de las menores de edad.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Acceso restringido al justificativo):** Dado un justificativo registrado para una inasistencia, cuando una usuaria del Equipo de Gestión de la sede o de la Directiva lo consulta, entonces ve su detalle; la tutora solo ve el estado y el motivo general en el pase de lista (US-38) y ninguna otra persona puede leerlo.
- [ ] **Escenario 2 (Bloqueo de acceso entre alumnas y pares):** Dada una alumna autenticada que consulta su asistencia, cuando visualiza que su falta está justificada, entonces puede ver su propio motivo pero bajo ninguna circunstancia puede ver ni acceder a los documentos o justificaciones de otras alumnas.
- [ ] **Escenario 3 (Minimización y exclusión de diagnósticos clínicos):** Dado el formulario de justificativo por salud, cuando el usuario registra la justificación, entonces la interfaz y el backend impiden campos de diagnóstico médico clínico limitándose a motivos generales tipificados (RB-8).

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Políticas RLS sobre `justificativos` (Gestión de la sede, Directiva y la propia alumna); sin bucket de archivos.
- [ ] Backend / Lógica: Validación en esquema de base de datos impidiendo almacenamiento de atributos médicos clínicos.
- [ ] Pruebas mínimas: TC-11 (Prueba de seguridad validando que una alumna, una tutora o un rol externo no puede leer el justificativo ajeno).

---

### 📝 Ajustes del MVP
- Los justificativos son solo texto, sin archivos adjuntos: no hay bucket `justificativos` y `archivo_adjunto_url` queda sin uso (decidido el 2026-11-16).
