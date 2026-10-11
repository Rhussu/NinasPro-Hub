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
│   │   ├── services/             # Servicios de salud y conectividad BaaS
│   │   ├── widgets/              # Componentes de UI y Healthchecker en tiempo real
│   │   └── main.dart             # Punto de entrada de la aplicación
│   ├── test/                     # Pruebas unitarias y de widgets (cobertura >= 80%)
│   ├── .env.example              # Plantilla de variables de entorno
│   ├── pubspec.yaml              # Dependencias de Flutter
│   └── Dockerfile.web            # Servidor Nginx ligero para despliegue local/contenedor
│
├── supabase/                     # Configuración del BaaS e Infraestructura de Datos
│   ├── config.toml               # Configuración del CLI local de Supabase
│   ├── migrations/               # Scripts SQL versionados (tablas 3NF, RLS, triggers)
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
