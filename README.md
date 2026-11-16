# 💜 NiñasPro Hub

Plataforma integral web para la gestión académica, asistencia, seguimiento y coordinación de talleres de **NiñasPro**.

---

## 🏗️ Arquitectura y Tecnologías

- **Frontend:** Flutter Web (Dart 3.x / Flutter 3.x)
- **Backend as a Service:** Supabase (PostgreSQL 15/17 + Row Level Security + GoTrue Auth)
- **Infraestructura de Datos:** Migraciones versionadas en SQL + Pruebas unitarias de esquema y RLS con pgTAP
- **CI/CD:** GitHub Actions (Validación estricta en Pull Requests y despliegue automatizado a GitHub Pages y Supabase Cloud tras merge)

---

## 📁 Estructura del Proyecto

```text
ninas-pro-hub/
│
├── .github/                      # Automatización y CI/CD
│   ├── workflows/                # Pipelines de GitHub Actions
│   │   ├── ci-flutter.yml        # CI: Análisis estático, cobertura (>=80%) y build web
│   │   ├── ci-database.yml       # CI: Entorno local efímero y tests pgTAP
│   │   ├── cd-frontend.yml       # CD: Despliegue a GitHub Pages (solo si cambia frontend/**)
│   │   └── cd-database.yml       # CD: Despliegue a Supabase Cloud (solo si cambia supabase/**)
│   ├── ISSUE_TEMPLATE/           # Plantillas estandarizadas para User Stories
│   └── pull_request_template.md  # Template para asegurar DoD y checklist
│
├── frontend/                     # Aplicación Flutter Web (código cliente)
│   ├── lib/                      # Código fuente Dart/Flutter
│   │   ├── config/               # Configuración dinámica y resolución de entornos
│   │   ├── models/               # Modelos de dominio y sesión de la usuaria
│   │   ├── repositories/         # Acceso a datos (Supabase y mock del mockup)
│   │   ├── screens/              # Vistas por rol, acceso (auth/), Accesos (accesos/) y calendario de clases (calendario/)
│   │   ├── services/             # Autenticación (Supabase Auth) y salud del BaaS
│   │   ├── widgets/              # Componentes de UI y Healthchecker en tiempo real
│   │   └── main.dart             # Punto de entrada de la aplicación
│   ├── test/                     # Pruebas unitarias y de widgets (cobertura >= 80%)
│   ├── .env.example              # Plantilla de variables de entorno
│   ├── pubspec.yaml              # Dependencias de Flutter
│   └── Dockerfile.web            # Servidor Nginx ligero para despliegue local/contenedor
│
├── supabase/                     # Configuración del BaaS e Infraestructura de Datos
│   ├── config.toml               # Configuración del CLI local de Supabase (Auth, hooks, MFA)
│   ├── migrations/               # Scripts SQL versionados (tablas 3NF, RLS, triggers)
│   ├── templates/                # Correos de activación y recuperación
│   ├── seed.sql                  # Datos demo y cuentas por rol (solo local)
│   └── tests/database/           # Batería de pruebas unitarias de BD con pgTAP
│
├── .gitignore
├── LICENSE
└── README.md                     # Guía principal de inicio rápido
```

---

## ⚡ Inicio Rápido en Desarrollo Local

### Requisitos previos
- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x o superior)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Node.js](https://nodejs.org/) (incluye `npx` para ejecutar Supabase CLI)

### 1. Iniciar Base de Datos Local (Supabase CLI)
```bash
# Levantar contenedores locales (PostgreSQL, Auth, Storage, Studio)
npx supabase start

# Ejecutar la batería de pruebas de base de datos con pgTAP
npx supabase test db
```
> El panel visual de administración local (Supabase Studio) estará disponible en `http://127.0.0.1:54323`.

### 2. Iniciar el Frontend (Flutter Web)
```bash
cd frontend

# Instalar dependencias
flutter pub get

# Ejecutar análisis estático (0 advertencias requeridas)
flutter analyze --fatal-infos --fatal-warnings

# Ejecutar pruebas unitarias con reporte de cobertura
flutter test --coverage

# Iniciar aplicación en Chrome (se conecta automáticamente a tu Supabase local)
flutter run -d chrome
```

> Después de cambiar `supabase/config.toml` o las plantillas de `supabase/templates/`, reinicia el stack (`npx supabase stop && npx supabase start`) para que Auth las tome. Las migraciones nuevas se aplican sin borrar datos con `npx supabase migration up`.

---

## 🔐 Autenticación y Accesos

### Cuentas demo (solo en local)
`supabase/seed.sql` crea estas cuentas, todas con la contraseña `NinasPro2026`:

| Correo | Rol |
|---|---|
| `directiva@ninaspro.cl` | Directiva (nacional). La primera vez inscribe su autenticador (MFA) |
| `camila.sepulveda@ninaspro.cl` | Equipo de Gestión, Sede Beauchef |
| `daniela.valenzuela@ninaspro.cl` | Tutora, Sede Beauchef |
| `valentina.soto@correo.cl` | Alumna, PCB Beauchef |

Los correos que envía Auth (activación y códigos de recuperación) llegan a **Mailpit**: `http://127.0.0.1:54324`.

### Flujos
- **Registro cerrado (US-04, US-05):** solo crea su cuenta quien tenga su correo autorizado en la vista **Accesos**. La Directiva la abre desde *Ajustes → Accesos* y autoriza cualquier rol y sede (incluida la líder de sede). El Equipo de Gestión la abre desde *Ajustes → Administración → Accesos* y solo autoriza alumnas inscritas en su sede. La persona autorizada entra a *Primera vez: crear mi cuenta* con ese correo y activa la cuenta con el enlace que le llega. La autorización vence a los 30 días.
- **Intentos sin permiso:** si Gestión intenta autorizar otro rol u otra sede, la base responde `403` y registra el intento en `auditoria_seguridad`. Lo mismo pasa con los registros de correos no autorizados y con los bloqueos de cuenta. Solo la Directiva puede leer esa tabla y nadie puede modificarla.
- **Recuperar la contraseña:** *¿Olvidaste tu contraseña?* envía un **código de 6 dígitos** que se ingresa en la misma pantalla. Funciona aunque el correo se abra en otro dispositivo. Hasta guardar la contraseña nueva, la sesión no da acceso a datos.
- **Bloqueo tras 3 intentos fallidos (US-06):** el tercer intento bloquea la cuenta y la app envía en ese momento un código de recuperación. Al definir la contraseña nueva, la cuenta queda desbloqueada.
- **Segundo factor de la Directiva (RNF-S-1):** la Directiva solo accede a los datos con un código TOTP verificado en la sesión (`aal2`). La primera vez escanea un QR con una app autenticadora (Google Authenticator, Microsoft Authenticator o similar). Después ingresa el código en cada inicio de sesión. Para volver a inscribirlo en local, borra su factor en *Studio → Authentication → Users*.

### Configuración manual en Supabase Cloud
`cd-database.yml` aplica las migraciones (`supabase db push`), pero **no** sube `config.toml`. Ese archivo tiene valores de desarrollo, como `site_url = localhost:3000` y `max_frequency = 1s`. Por eso, en el panel del proyecto hay que configurar a mano:

1. **Authentication → Hooks:**
   - *Before User Created* → `public.hook_before_user_created`.
   - *Password Verification Attempt* → `public.hook_password_verification_attempt`.
2. **Authentication → Email Templates:**
   - *Confirm signup* con el contenido de `supabase/templates/confirmacion.html`.
   - *Reset password* con el contenido de `supabase/templates/recuperacion.html`, que usa `{{ .Token }}`.
   - Los asuntos están en `config.toml`.
3. **Authentication → Multi-Factor:** TOTP habilitado (inscripción y verificación).
4. **Authentication → URL Configuration:**
   - *Site URL* = `https://rhussu.github.io/NinasPro-Hub/`.
   - La misma URL en *Redirect URLs*.
5. **Authentication → Providers → Email:**
   - Confirmación de correo activa.
   - OTP de 6 dígitos con vencimiento de 3600 s.
   - Contraseña mínima de 10 caracteres con minúsculas, mayúsculas y dígitos.
6. **SMTP propio** (*Authentication → SMTP Settings*). El SMTP de Supabase solo envía unos pocos correos por hora y únicamente al equipo del proyecto.

---

## 🗓️ Catálogo, instancias y calendario

Estas vistas ya leen y escriben en Supabase (`CatalogoRepository`). El resto de las vistas sigue con los datos del mockup hasta sus PR.

- **Sedes y cursos (US-01):** la Directiva los administra en *Ajustes → Sedes* y *Ajustes → Cursos*. El nombre de la sede y el código del curso son únicos, sin distinguir mayúsculas. La coordinadora que se muestra es la líder de sede del Equipo de Gestión, asignada al autorizar su correo en **Accesos**.
- **Instancias (US-02):** en *Ajustes → Instancias y sesiones* la Directiva elige sede, curso, fechas, día y horario. La RPC `crear_instancia_curso` genera en la misma transacción una sesión `programada` por semana. No se pueden insertar instancias ni clases directamente. Si ya existe la misma instancia (curso, sede y período), la app pide confirmación y la crea como **sección paralela** (B, C…), con su propio cronograma.
- **Calendario (US-03):** Gestión lo abre desde *Ajustes → Administración → Calendario de clases* y ve solo los cursos vigentes de su sede. La Directiva lo abre al tocar una instancia. Una sesión programada se puede suspender con un motivo, y queda fuera del pase de lista y del porcentaje de asistencia (`asistencia_inscripcion`). También se puede reanudar o sumar una **sesión especial** con fecha y horario propios (RPC `agregar_sesion_especial`).

---

## 🔄 Estrategia de CI/CD y Calidad

Para garantizar estabilidad y seguridad, el repositorio implementa una política de **Pull Requests protegidos**:

1. **Pull Requests hacia `main` (CI - Pruebas Selectivas):**
   - En cada PR hacia `main` se ejecutan únicamente los pipelines correspondientes al código afectado mediante filtros de ruta (`paths`):
     - **`CI - Flutter Web`**: Se dispara si se modificó `frontend/**`, validando análisis estático estricto, 100% de tests unitarios aprobados con **cobertura `>= 80%`** y compilación web.
     - **`CI - Supabase Database`**: Se dispara si se modificó `supabase/**`, levantando una base de datos efímera local y ejecutando las pruebas de integridad y políticas RLS con pgTAP.
   - **Bloqueo:** Si algún test falla, GitHub bloquea el botón de Merge para proteger la rama principal.
2. **Merge a `main` (CD - Despliegue Selectivo e Inteligente):**
   - Una vez revisado y aprobado el PR, al hacer merge se activan únicamente los despliegues de las áreas afectadas mediante filtros de rutas (`paths`):
     - **`CD - Deploy Supabase`**: Se dispara **únicamente** si se modificaron archivos en `supabase/**` (migraciones, RLS o funciones), aplicando los cambios a **Supabase Cloud**.
     - **`CD - Deploy GitHub Pages`**: Se dispara **únicamente** si se modificaron archivos en `frontend/**`, compilando y publicando la web en **GitHub Pages**.
     - *Si solo se modificó documentación (ej. `README.md`), ningún despliegue innecesario se ejecuta.*

---


## 🔒 Privacidad de Datos y Buenas Prácticas
> **IMPORTANTE:** NUNCA almacenar ni commitear datos reales de alumnas, tutores o voluntarias en el repositorio. Utilizar siempre datos sintéticos y mantener las credenciales privadas exclusivamente en variables de entorno locales (`.env`) o secretos de GitHub Actions.
