---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-41: Notificación y Respuesta de Encuesta Mensual en Portal de Alumna"
labels: ["user-story", "Should", "RF-21", "Alumna"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-21 · Encuestas de percepción y retroalimentación
- **Requisitos no funcionales (Indirectos):** RNF-U-1 (Accesibilidad), RNF-U-3 (Vocabulario adaptado a jóvenes de 13 a 18 años), RNF-S-5 (Carácter voluntario)
- **Reglas de negocio asociadas:** RB-6 (Portal de alumna)

---

### 👤 Historia de Usuario
> **Como** alumna que cursa activamente en Niñas Pro,  
> **quiero** recibir un aviso mensual en mi portal y responder una breve encuesta de percepción con preguntas de escala y comentarios libres sobre mi bienestar en el curso,  
> **para** expresar de manera honesta y protegida cómo me siento con las clases y tutoras.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Aviso de encuesta mensual activa):** Dada una alumna autenticada y una encuesta mensual abierta para su curso, cuando ingresa a su portal a fin de mes, entonces visualiza un banner amigable informando que la encuesta del mes está disponible y recordando que su participación es voluntaria.
- [ ] **Escenario 2 (Respuesta de escala y campos opcionales):** Dada la encuesta abierta, cuando la alumna califica los enunciados de escala (1 a 5) y escribe un comentario libre opcional, entonces el sistema guarda sus respuestas asociadas a su inscripción asegurando una única respuesta por mes.
- [ ] **Escenario 3 (Cierre de encuesta completada):** Dado el envío exitoso de la encuesta, cuando la alumna regresa a la vista general, entonces el banner se oculta y la encuesta queda marcada como completada para dicho período.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Modal o vista interactiva de encuesta mensual con componentes tipo Likert (1-5 estrellas o emojis) y campo de texto.
- [ ] Backend / Lógica: Inserción en `respuestas_encuesta` con restricción de clave única compuesta `(pregunta_id, inscripcion_id)`.
- [ ] Pruebas mínimas: TC-22 (Verificación de recepción de encuesta mensual en portal de alumna y guardado de respuestas).
