---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-01: Gestión del Catálogo de Sedes y Cursos Formativos"
labels: ["user-story", "Must", "RF-01", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-1 · Registro de nuevas sedes y cursos
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-U-3 (Español y responsivo)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio de Niñas Pro,  
> **quiero** registrar y administrar el catálogo maestro de sedes regionales (y modalidad online) junto a los cursos formativos vigentes,  
> **para** disponer de la estructura institucional base sobre la cual se planificarán las clases y se organizará la operación territorial de la corporación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Creación exitosa de sede):** Dado que un usuario con rol Directorio ingresa al panel de sedes, cuando completa los datos de nombre, modalidad (presencial/online) e institución anfitriona y confirma, entonces la sede queda registrada como activa y disponible para vincular cursos.
- [ ] **Escenario 2 (Validación de nombre único):** Dado que ya existe una sede registrada con el nombre "Concepción", cuando el Directorio intenta guardar otra sede con el mismo nombre, entonces el sistema rechaza la operación e indica que el nombre ya se encuentra registrado.
- [ ] **Escenario 3 (Alta de curso con código único):** Dado que el Directorio crea un nuevo curso, cuando ingresa un código institucional único (ej. `PCB-2026`) y un nombre no vacío, entonces el curso queda habilitado en el catálogo para generar futuras instancias.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario y vista de administración de sedes e instituciones anfitrionas.
- [ ] Frontend / UI: Formulario y listado del catálogo general de cursos.
- [ ] Backend / Lógica: Endpoints y modelos para entidades `sedes` y `cursos` con restricciones `UNIQUE` y validaciones en Supabase/PostgreSQL.
- [ ] Pruebas mínimas: Verificación de unicidad de código/nombre y restricción de acceso solo a rol Directorio (HTTP 403 para otros roles).
