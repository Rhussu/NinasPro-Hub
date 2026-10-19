---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-29: Registro de Podio Kahoot y Visualización Privada en Portal de la Alumna"
labels: ["user-story", "Must", "RF-20", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-20 · Registro de participación, ejercicios y Kahoot
- **Requisitos no funcionales (Indirectos):** RNF-U-1 (Accesibilidad), RNF-S-5 (Protección psicológica, sin rankings públicos ni estigmatización)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad), RB-Podio-Privado (Historial acumulativo privado; cada alumna solo ve sus propios conteos)

---

### 👤 Historia de Usuario
> **Como** tutora en el aula de clases (vista móvil),  
> **quiero** registrar los lugares del podio Kahoot (1°, 2° y 3°) al finalizar la actividad mediante un modal rápido, y que cada alumna vea en su portal su historial acumulado de podios (conteo de veces en 1°, 2° y 3° lugar),  
> **para** incentivar el entusiasmo y esfuerzo formativo sin exponer tablas de clasificación pública ni generar comparaciones lesivas entre compañeras.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Modal móvil de registro Kahoot para tutoras):** Al finalizar la dinámica de juego, la tutora presiona el botón flotante (FAB) de podio en su pantalla móvil. El sistema despliega un modal donde selecciona del listado de alumnas **únicamente presentes** quién obtuvo el 1° lugar (🥇), 2° lugar (🥈) y 3° lugar (🥉).
- [ ] **Escenario 2 (Persistencia e integridad del podio):** Al presionar "Guardar Podio de la Sesión", el sistema valida que las tres alumnas seleccionadas sean distintas y almacena la tupla `(primer_lugar_id, segundo_lugar_id, tercer_lugar_id)` asociada a la sesión de clase.
- [ ] **Escenario 3 (Historial acumulativo privado en Portal de la Alumna):** Cuando la alumna ingresa a su portal, visualiza una tarjeta dedicada "Historial de Podios Kahoot (US-29)" con tres contadores acumulados de todo el semestre:
  - 🥇 1° Lugar: X veces
  - 🥈 2° Lugar: Y veces
  - 🥉 3° Lugar: Z veces
- [ ] **Escenario 4 (Privacidad absoluta sin rankings):** En ningún punto la alumna ni terceras personas pueden ver las posiciones de sus compañeras de clase, asegurando un ambiente de aprendizaje seguro y colaborativo.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Modal Bottom Sheet en `PaseListaScreen` con selectores de dropdown para alumnas presentes; tarjeta de contadores 🥇, 🥈, 🥉 con estilos oficiales en `PortalAlumnaScreen`.
- [ ] Backend / Lógica: Entidad `podios_kahoot_sesion` y agregación de conteos en `PortalAlumnaData`.
- [ ] Pruebas mínimas: TC-13 (Comprobación de registro de podio por tutora y conteo acumulativo privado en la sesión de alumna).
