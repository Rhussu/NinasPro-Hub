---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-31: Control de Declaración de Adhesión y Asignación Docente a Cursos"
labels: ["user-story", "Must", "RF-23", "Directorio"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-23 · Registro de voluntariado
- **Requisitos no funcionales (Indirectos):** RNF-S-2 (Mínimo privilegio), RNF-S-5 (Salvaguarda de menores de edad)
- **Reglas de negocio asociadas:** RB-11 (Adhesión previa del equipo adulto a protocolos institucionales)

---

### 👤 Historia de Usuario
> **Como** integrante del Directorio,  
> **quiero** verificar que una persona voluntaria tenga firmada su Declaración de Adhesión institucional antes de permitir asignarla como tutora a un curso o clase presencial,  
> **para** asegurar que todo el equipo adulto con contacto con las niñas conozca y suscriba formalmente los protocolos de interacción y protección de menores (REF-5 y REF-6).

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Bloqueo de asignación sin declaración firmada):** Dada una voluntaria registrada cuya ficha tiene `declaracion_adhesion_firmada = false`, cuando el Directorio o Equipo de Gestión intenta asignarla como tutora a una instancia de curso presencial, entonces el sistema bloquea la asignación y notifica que debe contar con la declaración firmada.
- [ ] **Escenario 2 (Habilitación tras registro de la adhesión):** Dada la ficha de la voluntaria, cuando el Directorio marca que suscribió la Declaración de Conocimiento y Adhesión vigente (Anexo A de REF-5/REF-6) registrando la fecha de firma, entonces el sistema habilita su asignación a instancias de cursos.
- [ ] **Escenario 3 (Asignación docente a instancia de curso):** Dada una tutora habilitada, cuando se la asigna a una instancia de curso en una sede, entonces se crea el registro correspondiente en `tutores_instancia` quedando disponible para el pase de lista docente.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Campo y switch de estado de declaración firmada en la ficha del voluntario con indicador visual de aptitud docente.
- [ ] Backend / Lógica: Constraint / validación en API antes de insertar en `tutores_instancia` verificando `declaracion_adhesion_firmada = true`.
- [ ] Pruebas mínimas: Verificación de rechazo de asignación docente si no existe constancia de declaración firmada (RB-11).
