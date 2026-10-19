---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-26: Cronograma de Sesiones y Enlaces a Recursos Educativos Externos"
labels: ["user-story", "Must", "RF-14", "Alumna"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-14 · Portal de la alumna
- **Requisitos no funcionales (Indirectos):** RNF-U-3 (Diseño responsivo móvil prioritario 360px-430px), RNF-S-3 (Enlaces HTTPS seguros y validados)
- **Reglas de negocio asociadas:** RB-6 (Acceso según rol e instancia inscrita)

---

### 👤 Historia de Usuario
> **Como** alumna de Niñas Pro (vista móvil),  
> **quiero** consultar el cronograma de sesiones de los días sábados y acceder de forma directa y segura a los recursos educativos de cada clase (presentaciones, cuadernos Colab, guías y grabaciones),  
> **para** repasar los contenidos pedagógicos desde mi celular antes o después de cada jornada sin perder tiempo buscando enlaces dispersos.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Cronograma de sábados y estado de sesión):** Dada una alumna inscrita en un curso (ej. PCB-2026), cuando consulta su cronograma, visualiza la secuencia de 10 sesiones con fecha, número (#1 a #10), tema formativo e insignia de asistencia personal vinculada.
- [ ] **Escenario 2 (Explorador de recursos por clase en modal móvil):** Dada una clase con material educativo publicado, cuando la alumna presiona el botón "Ver Recursos (US-26)", se despliega una hoja inferior (bottom sheet) con la lista categorizada de recursos:
  - Diapositivas (`slides`, ej. Google Slides)
  - Código interactivo (`codigo`, ej. Google Colaboratory / GitHub)
  - Guías de problemas (`guia`, ej. Documentos PDF descargables)
  - Grabaciones de apoyo (`video`, ej. Sesiones Zoom / YouTube institucional)
- [ ] **Escenario 3 (Seguridad HTTPS y apertura externa):** Cada enlace despliega una insignia visual verde "HTTPS" y al presionarlo se abre en una pestaña externa segura mediante protocolo TLS verificado.
- [ ] **Escenario 4 (Persistencia para alumnas con retiro o egreso):** Dada una alumna retirada o que finaliza el curso, conserva acceso de solo lectura a los recursos educativos de su período hasta el cierre del ciclo anual.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Botón "Ver Recursos (US-26)" en cada tarjeta de sesión que activa un BottomSheet móvil con iconos temáticos y botón de apertura rápida.
- [ ] Backend / Lógica: Tabla `recursos_educativos` vinculada a `sesiones_clase` con validación estricta de URLs bajo esquema HTTPS.
- [ ] Pruebas mínimas: TC-17 (Validación de carga de recursos HTTPS por clase y respuesta en viewport móvil).
