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
> **Como** integrante de la Directiva,  
> **quiero** autorizar el correo de cada nueva persona usuaria asignando su rol y alcance de sede correspondiente, para que solo ella pueda crear su cuenta,  
> **para** asegurar que cada integrante acceda únicamente a las funcionalidades y datos que le competen según su responsabilidad.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Directiva autoriza correos del voluntariado):** Dado un usuario autenticado con rol Directiva, cuando registra en *Accesos* el correo, nombre y rol de una voluntaria (Tutora, Equipo de Gestión o Comunicación) asignándola a una sede, entonces el correo queda autorizado y la voluntaria puede crear su cuenta con ese correo; un correo no autorizado no puede registrarse.
- [ ] **Escenario 2 (Directiva autoriza cuentas de alumnas):** Dada una alumna inscrita en un curso, cuando la Directiva autoriza su correo vinculándolo a su ficha, entonces la alumna puede crear su cuenta y entra a su portal.
- [ ] **Escenario 3 (Restricción de privilegios en la autorización de correos):** Dado un usuario sin rol Directiva (Equipo de Gestión, Tutora, Alumna), cuando intenta autorizar un correo por la API, entonces el sistema rechaza la solicitud (HTTP 403) y registra el intento como evento de seguridad (`autorizacion_denegada`).

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vista *Accesos* (`accesos_view.dart`), solo para la Directiva, con el formulario para autorizar correos por rol y sede.
- [ ] Backend / Lógica: RPC `autorizar_correo` (solo `is_directorio()`) y hook de registro cerrado en Supabase Auth que asigna rol y sede al crear la cuenta.
- [ ] Pruebas mínimas: Verificación de rechazo de creación de perfiles administrativos por parte de usuarios sin permisos suficientes.

---

### 📝 Ajustes del MVP
- Registro cerrado: solo la Directiva autoriza correos, para alumnas y staff; Gestión no crea ni autoriza cuentas (decidido el 2026-11-16).
- Al dar de alta o importar una ficha de voluntariado (US-30), su correo queda autorizado automáticamente.
- El correo de invitación automático queda fuera del MVP: la persona autorizada crea su cuenta ella misma.
