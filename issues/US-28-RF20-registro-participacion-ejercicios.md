---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-28: Registro de Desempeño y Participación de Alumnas Presentes por Sesión"
labels: ["user-story", "Must", "RF-20", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-20 · Registro de participación, ejercicios y Kahoot
- **Requisitos no funcionales (Indirectos):** RNF-R-1 (Tiempo ≤ 1.5s), RNF-U-2 (Facilidad de uso en móvil), RNF-C-1 (Compatibilidad móvil)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad de cambios con autora y hora)

---

### 👤 Historia de Usuario
> **Como** tutora a cargo de la sesión práctica,  
> **quiero** registrar para cada alumna presente la cantidad de ejercicios completados y si tuvo participación activa en la clase,  
> **para** hacer seguimiento del avance pedagógico y mantener una constancia verificable del trabajo en aula.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Filtrado automático de alumnas presentes):** Dada una sesión cuya asistencia ya fue guardada (RF-5), cuando la tutora abre el formulario de registro de participación, entonces el sistema despliega únicamente a las alumnas que quedaron con estado "Presente".
- [ ] **Escenario 2 (Bloqueo de participación para alumnas ausentes o justificadas):** Dada una alumna marcada como "Ausente" o "Justificada", cuando se procesa el guardado de participación, entonces el sistema impide asociar registros de ejercicios o participación activa a su nombre.
- [ ] **Escenario 3 (Guardado de ejercicios y participación con autoría):** Dada la lista de presentes, cuando la tutora indica la cantidad de ejercicios resueltos y marca los checks de participación activa guardando los cambios, entonces los registros se persisten vinculados a la clase con la fecha, hora y tutora autora.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario móvil compacto con contadores de ejercicios y toggle de participación activa para alumnas presentes.
- [ ] Backend / Lógica: Inserción y actualización en tabla `participacion_clase` con validación de estado presente previo.
- [ ] Pruebas mínimas: TC-13 (Verificación de que solo las alumnas presentes admiten registro de participación).
