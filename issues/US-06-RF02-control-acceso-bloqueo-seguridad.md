---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-06: Control de Acceso por Sede (RLS) y Bloqueo por Intentos Fallidos"
labels: ["user-story", "Must", "RF-02", "Seguridad"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-2 · Definición de permisos en cuentas y roles
- **Requisitos no funcionales (Indirectos):** RNF-S-1 (MFA directorio), RNF-S-2 (Mínimo privilegio / RLS), RNF-S-4 (Auditoría)
- **Reglas de negocio asociadas:** RB-6 (Acceso a datos según rol y sede)

---

### 👤 Historia de Usuario
> **Como** administradora de seguridad del sistema,  
> **quiero** que el sistema aplique políticas estrictas de control de acceso territorial (RLS) y bloquee cuentas tras 3 intentos fallidos de autenticación,  
> **para** evitar accesos no autorizados a datos de menores y mitigar ataques de fuerza bruta.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Acceso territorial legítimo):** Dado un usuario autenticado con rol Tutora o Gestión en la sede A, cuando consulta la lista de asistencia o recursos de su curso, entonces el sistema le entrega los datos de su sede sin permitir visibilidad sobre sedes ajenas.
- [ ] **Escenario 2 (Intento de acceso cruzado denegado):** Dado un usuario autenticado de la sede A, cuando intenta consultar o manipular por API/URL un recurso perteneciente a la sede B, entonces el sistema deniega la acción retornando HTTP 403 Forbidden y registra el incidente en la auditoría.
- [ ] **Escenario 3 (Bloqueo automático tras 3 intentos fallidos):** Dado un usuario que ingresa consecutivamente 3 contraseñas erróneas, cuando se produce el tercer fallo, entonces la cuenta se bloquea preventivamente, se envía un correo con instrucciones de desbloqueo y se registra el evento en la bitácora de seguridad.

---

### 🛠️ Tareas
- [ ] Backend / Lógica: Definición e implementación de políticas Row Level Security (RLS) en PostgreSQL/Supabase por sede y rol.
- [ ] Backend / Lógica: Manejador de intentos de autenticación fallidos con bloqueo de cuenta al 3er fallo consecutivo.
- [ ] Pruebas mínimas: Pruebas de penetración automatizadas verificando respuestas 403 Forbidden ante manipulaciones directas de IDs en endpoints.
