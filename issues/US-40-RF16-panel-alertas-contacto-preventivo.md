---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-40: Panel de Gestión de Alertas de Deserción y Registro de Contacto Preventivo"
labels: ["user-story", "Should", "RF-16", "Gestion"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-16 · Alerta de inasistencias y prevención de deserción
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio territorial), RNF-S-5 (Ética, prevención de sesgo y no estigmatización), RNF-U-3 (Desktop para Directiva / Móvil para Gestión)
- **Reglas de negocio asociadas:** RB-6 (Confinamiento territorial), CI-3 (Acompañamiento preventivo no estigmatizante), RB-Roles (Directiva monitorea a nivel nacional en escritorio; Gestión atiende en móvil a nivel de sede)

---

### 👤 Historia de Usuario
> **Como** Directiva Nacional (en consola desktop) y Equipo de Gestión (en vista móvil de sede),  
> **queremos** monitorear las alertas tempranas de deserción (3 inasistencias consecutivas sin justificar, US-39) y registrar los contactos de acompañamiento realizados con las familias,  
> **para** brindar contención institucional oportuna sin exponer ni estigmatizar a las alumnas.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Monitoreo nacional para la Directiva):** La Directiva visualiza el panel consolidado de alertas de todas las sedes del país (Beauchef, San Joaquín, Valparaíso, Concepción), pudiendo filtrar por sede, y también puede registrar el contacto preventivo como Gestión.
- [ ] **Escenario 2 (Atención y registro en vista móvil para Equipo de Gestión):** Las coordinadoras de Gestión en su celular visualizan las alertas correspondientes a su sede territorial. Al presionar "Registrar Contacto Preventivo", ingresan observaciones sobre la llamada con el apoderado (ej. problemas de transporte, salud) y la alerta pasa a estado "contactada".
- [ ] **Escenario 3 (Nota metodológica y confidencialidad ética):** Ambas interfaces despliegan una nota metodológica destacando que las alertas son herramientas de acompañamiento humano y cuidado, no clasificaciones punitivas.
- [ ] **Escenario 4 (Protección contra estigmatización en Portal de la Alumna):** En ningún momento el sistema muestra avisos de "riesgo de deserción" en el portal de la estudiante; la alumna solo ve su porcentaje y mensajes de motivación.

---

### 🛠️ Tareas
- [ ] Frontend / UI: `AlertasDesercionView` (chips de sede para la Directiva, modal de contacto rápido), abierta desde la tarjeta y los Ajustes de Gestión y desde *Ajustes → Gestión en todas las sedes* de la Directiva.
- [ ] Backend / Lógica: Procedimiento de detección de 3 ausencias consecutivas (US-39) y actualización de `observacionesContacto` y `estado = 'contactada'`.
- [ ] Pruebas mínimas: TC-21 (Verificación de visualización en desktop para Directiva y en móvil para Gestión con cierre de alerta).

---

### 📝 Ajustes del MVP
- El criterio es solo 3 inasistencias seguidas sin justificar, **sin niveles de riesgo** ni umbral del 60 % (decidido el 2026-11-16).
- Gestión ve el contacto del apoderado y registra lo que se habló. La **Directiva puede hacer todo** lo de Gestión en cualquier sede, como entrada secundaria en *Ajustes → Gestión en todas las sedes* (decidido el 2026-11-16).
