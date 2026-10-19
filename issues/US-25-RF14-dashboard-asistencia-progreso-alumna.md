---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-25: Dashboard de Asistencia y Progreso Académico de la Alumna"
labels: ["user-story", "Must", "RF-14", "Alumna"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-14 · Portal de la alumna
- **Requisitos no funcionales (Indirectos):** RNF-U-1 (Accesibilidad visual WCAG AA, paleta `NinasProColors`), RNF-U-3 (Móvil prioritario 360px-430px)
- **Reglas de negocio asociadas:** RB-6 (Acceso exclusivo a sus propios datos), RB-Umbral-Asistencia (80% estándar; 70% si registra ≥ 1 justificativo aprobado por Gestión), RB-Recuperacion-Ejercicios (25 ejercicios = +1 clase justificada computada como presente; 50 ejercicios = +2 clases, tope máx. 2)

---

### 👤 Historia de Usuario
> **Como** alumna inscrita en un curso de Niñas Pro (vista móvil),  
> **quiero** acceder a mi portal personal para consultar mi porcentaje acumulado de asistencia frente a la meta (80% estándar o 70% con inasistencia justificada) y ver mi progreso de recuperación de clases mediante ejercicios resueltos,  
> **para** tener certidumbre inmediata sobre mi permanencia y certificación del ciclo formativo de 10 sesiones sin depender de consultas manuales.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Visualización de asistencia y umbral dinámico):** Dada una alumna autenticada, cuando ingresa a su portal, entonces visualiza su porcentaje acumulado de asistencia, la cantidad de sesiones asistidas sobre el total realizadas (ej. 7 de 8) y el umbral exigido: 80% por defecto, o 70% si cuenta con al menos un justificativo formalmente aprobado por el Equipo de Gestión.
- [ ] **Escenario 2 (Indicador visual de estado de certificación):** Dado el porcentaje calculado, si la alumna supera o iguala el umbral (≥ 80% o ≥ 70%), el sistema muestra una insignia verde de "Cumple meta para certificar". Si está por debajo, muestra una advertencia preventiva amigable indicando cuántas clases requiere asistir.
- [ ] **Escenario 3 (Mecanismo de recuperación por ejercicios):** Dada una alumna con inasistencias justificadas y ejercicios resueltos, cuando acumula 25 ejercicios, el sistema convalida automáticamente +1 clase justificada a su cómputo presencial; con 50 ejercicios convalida +2 clases (tope máximo institucional de 2 clases). El portal despliega una barra de progreso que indica cuántos ejercicios faltan para el siguiente hito de recuperación.
- [ ] **Escenario 4 (Cronograma y desglose por sesión de sábado):** Dada la lista de sesiones de sábados del semestre, la alumna visualiza el estado de cada una: "Presente" (verde), "Ausente" (rojo), "Justificada" (amarillo/naranja) o "Pendiente" (futuras clases programadas).

---

### 🛠️ Tareas
- [ ] Frontend / UI: Tarjeta de asistencia con porcentaje grande, barra de progreso con gradiente y umbral visible (80% / 70%), sección de recuperación por ejercicios (25 ej. / 50 ej.) y lista de sábados.
- [ ] Backend / Lógica: Función SQL / RPC que calcula asistencia ponderando clases justificadas aprobadas para aplicar umbral del 70% y suma de ejercicios resueltos para bonificación (máx +2).
- [ ] Pruebas mínimas: TC-17 (Validación de cálculo con 80% base, 70% con justificación y bonificación por 25/50 ejercicios resueltos).
