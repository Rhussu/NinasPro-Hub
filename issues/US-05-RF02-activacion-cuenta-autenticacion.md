---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-05: Activación de Cuenta mediante Enlace de Un Solo Uso y Autenticación Segura"
labels: ["user-story", "Must", "RF-02", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-2 · Definición de permisos en cuentas y roles
- **Requisitos no funcionales (Indirectos):** RNF-S-1 (OIDC / OAuth2, MFA para Directorio), RNF-U-3 (Español y responsivo)
- **Reglas de negocio asociadas:** RB-6 (Control de acceso por rol)

---

### 👤 Historia de Usuario
> **Como** persona invitada a la plataforma (tutora, líder de sede o alumna),  
> **quiero** activar mi cuenta a través del enlace de un solo uso recibido en mi correo y establecer mi contraseña personal,  
> **para** acceder de forma segura y personalizada a las funciones del sistema.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Activación con enlace válido):** Dada una persona usuaria que recibe un enlace de invitación vigente, cuando ingresa al enlace, define una contraseña que cumpla con las políticas de complejidad y confirma, entonces su cuenta pasa a estado activa y se inicia su sesión automáticamente.
- [ ] **Escenario 2 (Enlace de un solo uso ya consumido o expirado):** Dada una invitación cuyo enlace ya fue utilizado o superó el tiempo límite, cuando la persona intenta abrirlo nuevamente, entonces el sistema muestra un mensaje indicando que el enlace es inválido y ofrece la opción de solicitar reenvío.
- [ ] **Escenario 3 (Recuperación de contraseña):** Dado un usuario con cuenta activa que olvida su contraseña, cuando solicita el restablecimiento desde el login ingresando su correo, entonces recibe un correo seguro para redefinir su clave.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Vistas de bienvenida / establecimiento de contraseña y formulario de restablecimiento.
- [ ] Backend / Lógica: Configuración de flujo Supabase Auth (invitaciones seguras y magic links / recovery tokens).
- [ ] Pruebas mínimas: Verificación de un solo uso del token de activación e invalidación inmediata tras el primer cambio de contraseña.
