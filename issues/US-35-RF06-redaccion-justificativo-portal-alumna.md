---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-35: Redacción y Envío de Justificativo de Inasistencia desde el Portal"
labels: ["user-story", "Should", "RF-06", "Alumna"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-6 · Registro de justificativos
- **Requisitos no funcionales (Indirectos):** RNF-U-1 (Accesibilidad), RNF-U-3 (Español de Chile y diseño táctil móvil desde 360px)
- **Reglas de negocio asociadas:** RB-6 (Acceso a sus propios datos), RB-12 (Comunicación por espacios institucionales auditables), RB-Especificacion-Fecha (Selección obligatoria del sábado/clase a justificar), RB-Claridad-Medica (Sin advertencias prohibitivas sobre diagnósticos de salud)

---

### 👤 Historia de Usuario
> **Como** alumna que faltará o faltó a una jornada de clases (vista móvil),  
> **quiero** seleccionar la fecha exacta del sábado y la sesión de clase correspondiente para redactar mi justificativo con motivo tipificado y descripción clara, con un aviso breve de privacidad sobre datos de salud,  
> **para** informar oportunamente al Equipo de Gestión de mi sede sin barreras ni confusiones burocráticas.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Acceso y selección obligatoria del sábado de clase):** Al presionar "Justificar Falta" desde el botón flotante o tarjeta de sesión en su portal, el sistema despliega un modal móvil donde la alumna debe seleccionar obligatoriamente a qué clase faltará mediante un selector que detalla el número de sesión, tema y fecha del sábado (ej. `Clase #4 · 25/04/2026`).
- [ ] **Escenario 2 (Motivo tipificado y aviso de privacidad):** La alumna selecciona el motivo tipificado (`Salud`, `Académico / Pruebas`, `Familiar / Personal`, `Transporte / Clima`, `Otro`) y describe su situación en un campo de texto libre. El formulario muestra un aviso breve de privacidad ("no incluyas diagnósticos médicos ni datos de salud sensibles: basta con el motivo general") y no tiene campo de diagnóstico.
- [ ] **Escenario 3 (Envío y derivación a Equipo de Gestión):** Al enviar la solicitud, el sistema registra el justificativo en estado `pendiente`, notifica confirmación a la alumna e ingresa el ítem directamente a la bandeja de resolución del Equipo de Gestión de su sede territorial.
- [ ] **Escenario 4 (Prevención de duplicados):** Si ya existe un justificativo pendiente o aprobado para ese sábado y alumna, el sistema bloquea envíos redundantes para la misma fecha.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Modal Bottom Sheet en `PortalAlumnaScreen` con selector de fechas de sábados, desplegable de motivos tipificados y campo de detalle adaptado a teclado móvil.
- [ ] Backend / Lógica: Inserción en `justificativos` vinculando `alumna_id`, `sesion_id`, `fecha_clase`, `motivo_tipificado` y `estado = 'pendiente'`.
- [ ] Pruebas mínimas: TC-19 (Validación de selección de fecha de sábado, aviso de privacidad visible, sin campo de diagnóstico, y estado pendiente registrado).

---

### 📝 Ajustes del MVP
- El formulario lleva aviso de salud y **no** tiene campo de diagnóstico; el justificativo es solo texto, sin adjuntos (decidido el 2026-11-16).
- Una clase justificada sigue contando como ausente; el justificativo aceptado solo baja la meta al 70 % (ver US-25).
