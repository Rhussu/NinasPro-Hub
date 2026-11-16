---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-13: Pase de Lista Rápido de Alumnas Optimizado para Móvil"
labels: ["user-story", "Must", "RF-05", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-5 · Registro de asistencia de alumnas por clase
- **Requisitos no funcionales (Indirectos):** RNF-R-1 (Tiempo de respuesta ≤ 1.5s), RNF-U-1 (Touch targets ≥ 44x44 px, WCAG 2.1 AA, SRS §4.4), RNF-U-2 (Completado en ≤ 3 min), RNF-U-3 (Móvil desde 360px)
- **Reglas de negocio asociadas:** RB-1 (Solo alumnas activas), RB-7 (Trazabilidad de cambios), RB-Separación-Roles (Tutora solo conmuta Presente ↔ Ausente; Justificada es gestionada exclusivamente por Equipo de Gestión)

---

### 👤 Historia de Usuario
> **Como** tutora en la sala de clases (vista móvil),  
> **quiero** abrir la lista de la clase desde mi teléfono celular para alternar de forma táctil el estado de las alumnas exclusivamente entre Presente y Ausente, visualizando bloqueadas las inasistencias previamente justificadas por Gestión,  
> **para** completar el pase de lista en menos de 3 minutos con total fluidez sin alterar justificaciones institucionales aprobadas.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Pase de lista con estados por defecto y separación de roles):** Dada una clase del día con alumnas activas, cuando la tutora abre la sesión en su celular, entonces el sistema despliega una lista vertical donde las alumnas parten marcadas como "Presente", excepto aquellas con justificativo aprobado por el Equipo de Gestión que aparecen marcadas como "Justificada" con un distintivo visual bloqueado (🔒).
- [ ] **Escenario 2 (Conmutación táctil P ↔ A únicamente):** Dada la lista abierta, cuando la tutora presiona sobre una alumna "Presente", esta conmuta inmediatamente a "Ausente". Si vuelve a presionar, retorna a "Presente". Si intenta presionar sobre una alumna "Justificada", el sistema no altera el estado e informa mediante un aviso breve que los justificativos son gestionados exclusivamente por el Equipo de Gestión.
- [ ] **Escenario 3 (Marcación de ausentes y guardado exitoso):** Dada la lista con ausencias marcadas, cuando la tutora presiona "Guardar Asistencia de la Clase", entonces el sistema persiste los registros presentes, ausentes y justificados en menos de 1,5 segundos (p95), registrando fecha, hora y tutora autora.
- [ ] **Escenario 4 (Marcación de clase como realizada):** Dado el guardado exitoso de la lista de asistencia, cuando finaliza la transacción, entonces la sesión de clase pasa automáticamente de estado "programada" a "realizada".

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista móvil vertical táctil adaptada a pantallas móviles (≥ 44×44 px touch targets según el SRS §4.4, paleta oficial `NinasProColors`) con interacción rápida Presente ↔ Ausente y badge bloqueado para Justificada.
- [ ] Backend / Lógica: Inserción por lotes en tabla `asistencia_alumnas` validando que las tutoras de aula no puedan sobreescribir estados 'justificada' gestionados por Gestión.
- [ ] Pruebas mínimas: TC-07 (Lista con conmutación P ↔ A y verificación de bloqueo en justificadas) y RNF-U-2 (Pase de lista en ≤ 3 min).
