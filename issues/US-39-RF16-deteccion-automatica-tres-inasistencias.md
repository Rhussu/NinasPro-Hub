---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-39: Detección Automática de Patrón de 3 Inasistencias Consecutivas"
labels: ["user-story", "Should", "RF-16", "Sistema"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Should (Valor operativo alto)
- **Requisito funcional (Base):** RF-16 · Alerta de inasistencias
- **Requisitos no funcionales (Indirectos):** RNF-M-1 (≥ 80% cobertura de pruebas unitarias en reglas críticas), RNF-S-2 (Mínimo privilegio)
- **Reglas de negocio asociadas:** RB-6 (Alerta confinada a sede), CI-3 (Estadística de inasistencias para prevenir deserción)

---

### 👤 Historia de Usuario
> **Como** algoritmo de monitoreo preventivo del sistema,  
> **quiero** evaluar automáticamente el historial de asistencia tras cada guardado de clase y detectar si una alumna acumula 3 faltas consecutivas sin justificación,  
> **para** generar oportunamente una alerta de riesgo de deserción antes de que la alumna se desvincule definitivamente del programa.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Disparo de alerta al registrar la 3ra inasistencia consecutiva):** Dada una alumna que acumula 2 inasistencias consecutivas previas sin justificar en su curso, cuando la tutora guarda la lista de la clase del día marcándola nuevamente como "Ausente", entonces el sistema crea automáticamente una alerta en la tabla `alertas_desercion` asociada a su inscripción y clase.
- [ ] **Escenario 2 (Interrupción de la racha por asistencia o justificación):** Dada una alumna con 2 inasistencias consecutivas no justificadas, cuando en la siguiente sesión asiste ("Presente") o su falta anterior es marcada como "Justificada", entonces el contador de ausencias consecutivas se reinicia a 0 y no se dispara la alerta.
- [ ] **Escenario 3 (Evitar alertas duplicadas sin atender):** Dada una alumna para la cual ya existe una alerta activa sin atender para la misma racha de inasistencias, cuando se guarda una nueva sesión donde sigue ausente, entonces el sistema actualiza la referencia de la última clase sin generar múltiples alertas redundantes que saturen a la coordinación.

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Trigger / función en PostgreSQL ejecutada tras inserción/actualización en `asistencia_alumnas` que calcula inasistencias consecutivas no justificadas ordenadas por fecha.
- [ ] Backend / Lógica: Inserción en tabla `alertas_desercion` con campos `(inscripcion_id, clase_id, atendida = false)`.
- [ ] Pruebas mínimas: TC-21 (Simulación de 3 inasistencias seguidas sin justificar verificando generación automática de la alerta).

---

### 📝 Ajustes del MVP
- Una sola alerta sin atender por inscripción; si la racha se corta (se justifica o corrige una falta), la alerta sin atender se elimina, y una contactada no se repite para la misma racha (PR 7).
