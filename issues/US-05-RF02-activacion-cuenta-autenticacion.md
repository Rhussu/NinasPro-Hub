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
> **quiero** crear mi cuenta con mi correo autorizado, activarla con el enlace de un solo uso que recibo y establecer mi contraseña personal,  
> **para** acceder de forma segura y personalizada a las funciones del sistema.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Activación con enlace válido):** Dada una persona con correo autorizado que se registra y recibe el enlace de activación vigente, cuando ingresa al enlace, define una contraseña que cumpla con las políticas de complejidad y confirma, entonces su cuenta pasa a estado activa y se inicia su sesión automáticamente.
- [ ] **Escenario 2 (Enlace de un solo uso ya consumido o expirado):** Dada una invitación cuyo enlace ya fue utilizado o superó el tiempo límite, cuando la persona intenta abrirlo nuevamente, entonces el sistema muestra un mensaje indicando que el enlace es inválido y ofrece la opción de solicitar reenvío.
- [ ] **Escenario 3 (Recuperación de contraseña):** Dado un usuario con cuenta activa que olvida su contraseña, cuando solicita el restablecimiento desde el login ingresando su correo, entonces recibe un **código de 6 dígitos** por correo, lo ingresa en la app y define una nueva clave.

---

### 🛠️ Tareas
- [ ] Frontend / UI: `AccesoScreen` (ingreso y registro), `CodigoRecuperacionScreen`, `NuevaContrasenaScreen` y `VerificacionMfaScreen`.
- [ ] Backend / Lógica: Supabase Auth con registro cerrado, enlace de activación con `token_hash`, recuperación por código (plantilla con `{{ .Token }}`) y MFA TOTP para la Directiva.
- [ ] Pruebas mínimas: Verificación de un solo uso del token de activación e invalidación inmediata tras el primer cambio de contraseña.

---

### 📝 Ajustes del MVP
- No hay invitación: la persona se registra con su correo autorizado (ver US-04). La recuperación es con código de 6 dígitos y la Directiva entra con MFA TOTP (decidido en el PR 1).
