---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-04: Invitación y Creación de Cuentas por Rol y Sede"
labels: ["user-story", "Must", "RF-02", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-2 · Definición de permisos en cuentas y roles
- **Requisitos no funcionales (Indirectos):** RNF-S-1 (Autenticación OIDC/OAuth2), RNF-S-2 (Mínimo privilegio), RNF-S-4 (Auditoría)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede), RB-11 (Adhesión previa del equipo adulto)

---

### 👤 Historia de Usuario
> **Como** administrador del Directorio o integrante del Equipo de Gestión,  
> **quiero** invitar y crear cuentas para nuevas personas usuarias asignando su rol y alcance de sede correspondiente,  
> **para** asegurar que cada integrante acceda únicamente a las funcionalidades y datos que le competen según su responsabilidad.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Directorio crea cuentas de voluntariado):** Dado un usuario autenticado con rol Directorio, cuando registra el correo institucional (`@ninaspro.cl`), nombre y rol de una voluntaria (tutora, líder de sede o comunicación) asignándola a una sede, entonces el sistema genera el perfil y despacha un correo de invitación con enlace de un solo uso.
- [ ] **Escenario 2 (Equipo de Gestión crea cuentas de alumnas):** Dado un usuario con rol Equipo de Gestión de la sede A, cuando crea la cuenta para una alumna previamente inscrita en un curso de su sede, entonces el sistema despacha exitosamente la invitación al correo registrado.
- [ ] **Escenario 3 (Restricción de privilegios en creación de cuentas):** Dado un usuario con rol Equipo de Gestión de la sede A, cuando intenta crear un usuario con rol Directorio, Tutora o Comunicación, entonces el sistema rechaza la solicitud (HTTP 403) y registra el intento no autorizado en la auditoría.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Formulario de invitación de usuarios con selectores condicionales según los privilegios del actor.
- [ ] Backend / Lógica: Políticas RLS y servicio de invitaciones Auth de Supabase con asignación en tabla `perfiles` y `usuarios_sedes`.
- [ ] Pruebas mínimas: Verificación de rechazo de creación de perfiles administrativos por parte de usuarios sin permisos suficientes.
