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
- **Registro cerrado (US-04, US-05):** solo crea su cuenta quien tenga su correo autorizado en la vista **Accesos**. Solo la Directiva la tiene (*Ajustes → Accesos*) y autoriza cualquier rol y sede, incluidas las alumnas y la líder de sede. La persona autorizada entra a *Primera vez: crear mi cuenta* con ese correo y activa la cuenta con el enlace que le llega. La autorización vence a los 30 días.
- **Intentos sin permiso:** si alguien que no es de la Directiva intenta autorizar un correo, la base responde `403` y registra el intento en `auditoria_seguridad`. Lo mismo pasa con los registros de correos no autorizados y con los bloqueos de cuenta. Solo la Directiva puede leer esa tabla y nadie puede modificarla.
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

Estas vistas ya leen y escriben en Supabase (`CatalogoRepository`). Las vistas sin repositorio propio siguen con los datos del mockup hasta sus PR.

- **Sedes y cursos (US-01):** la Directiva los administra en *Ajustes → Sedes* y *Ajustes → Cursos*. El nombre de la sede y el código del curso son únicos sin distinguir mayúsculas, tildes, espacios ni signos (`clave_nombre`). Si un nombre nuevo se parece mucho a otro (un error de tipeo o el prefijo "Sede"), la app pide confirmación. Una sede o un curso se puede eliminar mientras no tenga instancias, personas asignadas ni accesos pendientes. Si los tiene, el botón queda deshabilitado y explica qué lo usa. La coordinadora que se muestra es la líder de sede del Equipo de Gestión, asignada al autorizar su correo en **Accesos**.
- **Instancias (US-02):** en *Ajustes → Instancias y sesiones* la Directiva elige sede, curso, fechas, día y horario. La RPC `crear_instancia_curso` genera en la misma transacción una sesión `programada` por semana. No se pueden insertar instancias ni clases directamente. Si ya existe la misma instancia (curso, sede y período), la app pide confirmación y la crea como **sección paralela** (B, C…), con su propio cronograma.
- **Calendario (US-03):** Gestión lo abre desde *Ajustes → Administración → Calendario de clases* y ve solo los cursos vigentes de su sede. La Directiva lo abre al tocar una instancia. Una sesión programada se puede suspender con un motivo, y queda fuera del pase de lista y del porcentaje de asistencia (`asistencia_inscripcion`). También se puede reanudar o sumar una **sesión especial** con fecha y horario propios (RPC `agregar_sesion_especial`).

---

## 👧 Alumnas, cargas masivas y autorizaciones

La sección **Alumnas** de la Directiva ya usa Supabase (`AlumnasRepository`). **La gestión de las alumnas es solo de la Directiva:** fichas, inscripciones, cargas, retiros, autorizaciones, revocaciones y accesos. El Equipo de Gestión opera el semana a semana (clases y coordinación con las tutoras) y la base le responde `403` si intenta escribir datos de alumnas. Esto corrige un error de los requisitos que se arrastró a las historias US-04, US-10 y US-11.

- **Nómina:** una fila por inscripción (vista `nomina_alumnas`, solo para la Directiva). Muestra asistencia, consentimiento de datos, aptitud para fotos y estado.
- **Carga masiva (US-07, US-08):** *Carga masiva* acepta CSV UTF-8 (con coma o punto y coma) y XLSX. La app revisa la estructura: si las columnas no son exactamente las de la plantilla (*Descargar plantilla*), el archivo se rechaza completo y se informa qué falta o qué está desalineado. Luego la RPC `importar_alumnas` con `p_solo_validar` revisa cada fila sin guardar nada: **nueva**, **ya tiene ficha**, **ya inscrita** en el curso, **conflicto** o **con errores**.
  - Conflictos: RUT repetido en el archivo, RUT con ficha cuyos datos difieren de la planilla (se muestra cada diferencia), y correo de la alumna que ya usa otra persona.
  - Errores: RUT con dígito verificador incorrecto, falta el correo o el teléfono del apoderado/a, fecha de nacimiento no válida, etc.
  - Cada uno se avisa y se resuelve **ahí mismo** con el menú ⋯ de la fila: corregir datos, usar una de las filas repetidas, mantener o actualizar la ficha, inscribir sin correo o descartar. Las filas por resolver también se descargan como CSV.
  - *Confirmar carga* inscribe lo resuelto en una sola transacción como `preinscrita`. Lo que siga sin resolver queda en `conflictos_importacion` y se resuelve **después** desde *Alumnas → Conflictos de importación*: al quedar sin conflictos se inscribe en su curso.
- **Ficha única por RUT e inscripción individual (US-09):** el RUT se valida con módulo 11 y se compara sin puntos ni guion (`normalizar_rut`). Si ya existe, se reutiliza la ficha y solo se agrega la inscripción; si sus datos difieren, se avisa para mantenerla o actualizarla (también en la inscripción individual). Si la fila trae el correo de la alumna, ese correo queda autorizado para crear su cuenta. Alumnas, apoderados e inscripciones solo se crean con la RPC. El retiro (RPC `retirar_inscripcion`) exige fecha y motivo, y conserva la asistencia.
- **Autorizaciones (US-10, US-11):** en la ficha se registra el tratamiento de datos y cada canal de imagen (RPC `registrar_autorizaciones`). Un canal sin respuesta queda no autorizado. Para otorgar algo hay que adjuntar el documento firmado (PDF, PNG o JPG de hasta 5 MB). El documento se guarda en el bucket privado `autorizaciones` (`<alumna_id>/<archivo>`), que Storage cifra en reposo, y se abre con una URL firmada de 60 s. Al otorgar el tratamiento de datos, las preinscripciones pasan solas a `activa`. Sin él, la inscripción no puede activarse ni registrar asistencia. Las preinscritas que siguen sin consentimiento tras 2 sesiones desde su inscripción aparecen destacadas en la nómina.
- **Revocación (US-12):** *Revocar autorización* desactiva uno o varios canales desde la fecha de la solicitud y guarda el motivo. `evidencia_apta_canal(evidencia, canal)` calcula la aptitud de cada foto: las de clases desde esa fecha dejan de ser aptas para el canal revocado (salvo que los rostros estén censurados), y las anteriores conservan su aptitud.

---

## 👩‍🏫 La clase en el aula: asistencia, participación y podio

La clase de Tutora y de Gestión ya usa Supabase (`ClaseRepository`). La tutora ve los cursos a los que está asignada (`tutores_instancia`) y Gestión, los de su sede. Si opera más de uno, elige el curso arriba de la pantalla. La **clase actual** es la última no suspendida cuya fecha ya llegó: la de hoy o, durante la semana, la del último día de clases. Las alertas y los roles semanales siguen con los datos del mockup hasta sus PR.

- **Pase de lista (US-13):** todas parten como Presente y la tutora alterna Presente ↔ Ausente. Las Justificadas aparecen con 🔒 y solo las cambia el Equipo de Gestión de la sede. Las preinscritas sin consentimiento no aparecen. El primer guardado deja la clase en `realizada`. Ni las clases futuras ni las suspendidas admiten registros.
- **Correcciones (US-15, US-33 escenario 3):** en el historial semana a semana, *Corregir lista* reabre una clase anterior, o *Pasar lista* si quedó sin registrar. Cada lista muestra quién hizo la última edición y a qué hora.
- **Ejercicios, participación y podio (US-28, US-29):** se registran solo para las alumnas **presentes del pase de lista guardado**. El podio lleva un lugar por alumna presente, hasta tres y cada uno con una alumna distinta: con dos se elige quién quedó primera y quién segunda, y con una sola, queda primera (migración 17). Si una alumna pasa a ausente, pierde su participación y su lugar en el podio de esa clase.
- **Asistencia de tutoras (US-33):** Gestión la toma desde el Speed Dial con el equipo asignado al curso, que parte como presente.
- **Sin conexión (US-14, US-34):** cada guardado se escribe primero en el navegador (IndexedDB con `sembast_web`, `lib/data/offline/cola_sincronizacion.dart`) y se intenta subir de inmediato. Si no hay red, la lista muestra *Pendiente de envío por falta de conexión*. Se reenvía sola al volver internet (`connectivity_plus`), cada 30 s o al deslizar hacia abajo. Un guardado nuevo de la misma lista reemplaza al pendiente anterior, y los pendientes de una cuenta nunca se suben con la sesión de otra. Si la nube rechaza un cambio pendiente al subirlo (por ejemplo, la clase se suspendió mientras tanto), la nubecita lo avisa.
- **Reglas en la base (migración 15):** las tablas de la clase solo se escriben con las RPC `guardar_asistencia_clase`, `guardar_participacion_clase`, `guardar_podio_kahoot` y `guardar_asistencia_tutores`. Las RPC son idempotentes: reenviar una lista no duplica ni escribe nada. En cada registro gana el **último guardado según la hora del dispositivo** (`p_guardado_en`, sin pasar de la hora del servidor). Así, una lista que llega tarde por falta de conexión no pisa una corrección hecha después por otra persona. Las lecturas son `lista_asistencia_clase` y `lista_asistencia_tutores`, que respetan la RLS. Solo se asigna a un curso a una voluntaria con la adhesión firmada y vigente.
- **Auditoría (migración 16):** el trigger `auditar()` guarda en `auditoria_cambios_datos` cada alta, cambio y borrado de la asistencia de alumnas y tutoras y de la participación. Registra el valor anterior y el nuevo (JSONB), la autora, la IP y el navegador. Los cambios del sistema quedan con autora `NULL`. Nadie puede escribir, modificar ni borrar las bitácoras (ni siquiera la Directiva), que solo la Directiva lee.

---

## 📝 Justificativos y evidencia fotográfica

Los justificativos (`JustificativosRepository`) y las fotos de la clase (`EvidenciasRepository`) ya usan Supabase (migración 18).

- **La alumna justifica (US-35):** con *Justificar Falta* en su portal elige la clase a la que faltará o faltó (`clases_para_justificar`: las de sus cursos, no suspendidas, donde no figura presente), un motivo tipificado (Salud, Académico / Pruebas, Familiar / Personal, Transporte / Clima u Otro) y explica con sus palabras. Por ahora el justificativo es solo texto, sin archivos adjuntos (US-36 queda fuera). Queda **pendiente** (RPC `enviar_justificativo`) y ve su estado y la observación de Gestión en *Mis Justificativos*. Solo puede haber un pendiente o aprobado por clase; tras un rechazo puede enviar otro. El resto del portal sigue con los datos del mockup hasta el PR 7.
- **Gestión resuelve (US-16, US-37):** la bandeja de la pantalla de Gestión filtra Pendientes, Aprobados y Rechazados. *Aprobar* deja la asistencia de esa clase en **justificada**, y *Rechazar* exige una observación para la alumna (RPC `resolver_justificativo`). *Ingresar justificativo* del Speed Dial registra el aviso de la apoderada ya aprobado (`registrar_justificativo`), también para una clase futura. *Eliminar* (`eliminar_justificativo`) borra lo vinculado por error: si estaba aprobado, la asistencia vuelve a ausente. Cada cambio queda en la auditoría.
- **Justificativo por adelantado (US-16 escenario 2):** el justificativo se vincula a la clase y a la inscripción, no a la fila de asistencia. Al pasar lista, la alumna con un justificativo aprobado entra como justificada aunque la lista la traiga presente, y la tutora no puede cambiarla: para hacerlo, Gestión elimina el justificativo.
- **Tutoras, solo lectura (US-38):** en el pase de lista ven el estado del justificativo de cada alumna y, al tocarlo, el motivo general. No ven la explicación, y las RPC de resolución les responden `403`.
- **Privacidad (US-17, RB-8):** no hay campo de diagnóstico. La explicación es obligatoria, admite hasta 500 caracteres y lleva un aviso para no incluir datos de salud sensibles. Solo la leen la propia alumna, Gestión de la sede y la Directiva.
- **Foto de la clase (US-18, US-19):** después del pase de lista, *Fotos* abre la cámara o la galería del celular (`accept="image/*"`). La foto se comprime en el navegador con un canvas a JPEG de máximo 1920 px y menos de 1,5 MB (`services/compresion_imagen.dart`; el paquete `image` es el respaldo y lo usan las pruebas). Se sube al bucket privado `evidencias` (`<clase_id>/<archivo>`) y se registra con la fecha, la hora, el peso real del archivo y la tutora. Si hay presentes sin autorización de imagen, se listan, y para marcarla **apta** hay que confirmar que no son reconocibles o que sus rostros se cubrieron. Sin esa confirmación, la foto queda como respaldo interno (`apta_para_evidencia = false`). La base aplica la misma regla. Las fotos registradas no se borran (RB-10).
- **Evidencias pendientes (US-20):** la vista `evidencias_pendientes` lista las clases realizadas sin foto cuyo término (hora de Chile) fue hace más de 48 horas, con las tutoras del curso. Gestión las ve en su pantalla, solo las de su sede, y la clase sale de la lista al subir su foto.
- **Pendiente:** el umbral de aprobación al 70 % con un justificativo aprobado (US-37 escenario 2) se calcula con el portal de la alumna, en el PR 7.

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
