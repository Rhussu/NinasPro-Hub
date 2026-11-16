# Plan de pruebas · NiñasPro Hub

**Fuente de requisitos:** SRS «Grupo1_AvanceEscrito» (IEEE 830). Las secciones que usa este plan son:
- §4: RNF con su objetivo y su método de verificación.
- §10: DoD, criterios del MVP y validación con usuarios.
- §11: matriz de trazabilidad y catálogo TC-01 a TC-42.

**Resultados:** [`informe-resultados.md`](informe-resultados.md), y en HTML en `rhussu.github.io/NinasPro-Hub/beta/pruebas/`.

## 1. Objetivo y alcance

Demostrar, con pruebas ejecutadas y reproducibles, tres cosas:
1. Los RF Must cumplen sus criterios Gherkin.
2. Las reglas de negocio críticas están cubiertas.
3. Los RNF críticos (§10: **R-1, R-2, S-2, S-3, U-2, M-1, P-3** y el costo de **$0 USD/mes**) se cumplen.

Entra en el alcance:
- La app Flutter Web (`frontend/`).
- La base Supabase: esquema, RLS y RPC (`supabase/`).
- Los workflows de CI/CD.

Queda fuera: RF-13, RF-17, RF-19 y RF-22 (Won't), RF-18 (foro, Could, no implementado) y las encuestas (RF-21).

## 2. Ambientes

| Ambiente | Qué es | Datos | Para qué |
|---|---|---|---|
| **Local** | Docker en el PC: `npx supabase start` + imagen de Flutter | `supabase/seed.sql` (sintético) | Todas las pruebas automatizadas y una primera medición de los RNF |
| **Beta / QA** | Rama `premain` → `rhussu.github.io/NinasPro-Hub/beta/` + proyecto Supabase de prueba | Parte solo con `directiva@ninaspro.cl` (`supabase/beta/directiva.sql`, vía `cd-database.yml` con `crear_directiva=true`). El equipo crea a mano datos **ficticios**: nunca datos reales de alumnas | Medición oficial de los RNF (DoD 6: «desplegado en QA con datos sintéticos») y pruebas con personas |
| **Producción** | Rama `main` → `rhussu.github.io/NinasPro-Hub/` | Reales | **Nunca** se prueba ni se mide aquí |

El flujo de ramas es: `feature → premain` (PR con CI, despliegue a la beta y medición) → PR `premain → main`.

## 3. Niveles de prueba y herramientas

| Nivel | Herramienta | Dónde | Se ejecuta | Comando |
|---|---|---|---|---|
| Unitarias | `flutter test` | `frontend/test/` (rut, planilla, nombres, cola sin conexión) | Cada PR (`ci-flutter.yml`) | `cd frontend && flutter test` |
| Integración (cliente) | `flutter test` + cliente HTTP simulado | `frontend/test/*repository*_test.dart` | Cada PR | ídem |
| Integración (base de datos) | pgTAP | `supabase/tests/database/` (18 archivos, 547 pruebas) | Cada PR (`ci-database.yml`) | `supabase test db` |
| Widgets / UI | `flutter test` | `frontend/test/*screens*_test.dart`, `hub_screens_test.dart`… | Cada PR | `flutter test` |
| Extremo a extremo | `flutter drive` + Chrome headless | `frontend/integration_test/app_e2e_test.dart` | Cada PR (`ci-e2e.yml`) | `bash pruebas-rnf/e2e/correr.sh <salida>` |
| Dominio: responsivo y accesibilidad | `flutter test` | `frontend/test/responsivo_test.dart` | Cada PR | `flutter test test/responsivo_test.dart` |
| Seguridad: acceso cruzado | k6 sobre la API real | `pruebas-rnf/seguridad/acceso_cruzado.js` | Medición en la beta | ver `pruebas-rnf/README.md` |
| Seguridad: TLS | openssl | `pruebas-rnf/seguridad/tls.sh` | Medición en la beta | `bash pruebas-rnf/seguridad/tls.sh <hosts>` |
| Carga | k6 + `tc netem` | `pruebas-rnf/k6/carga_sesion.js` | Medición en la beta | `bash pruebas-rnf/k6/correr.sh <salida.json>` |
| Cobertura | `flutter test --coverage` + lcov/genhtml | `frontend/tool/cobertura.sh` | Cada PR (umbral 80 %) | `bash tool/cobertura.sh` |
| Despliegue (P-3) | `gh run list` | `pruebas-rnf/p3_tiempos.sh` | Medición en la beta | `bash pruebas-rnf/p3_tiempos.sh` |
| Manuales | Pautas | `kit-usabilidad/`, `lista-legal.md` | Antes de cerrar el sprint | — |

### Pruebas del dominio (específicas de NiñasPro)

Además de los niveles clásicos, el dominio exige probar:
- **Protección de menores:** una alumna solo ve su portal (TC-17, AT-8). Una foto no queda apta sin la autorización de imagen de todas las alumnas (RB-3, TC-12). Los justificativos no guardan diagnósticos (RB-8, TC-11). La exportación disociada no lleva nombre ni RUT (RB-9, TC-25).
- **Aislamiento por sede:** ninguna tutora ni Gestión ve otra sede (TC-32). La Directiva no ve datos sin MFA (TC-31).
- **La clase del sábado:** pase de lista en la clase de hoy, sin conexión y sin duplicados (TC-07, TC-08, TC-09). Asistencia de tutoras (TC-10). Participación solo de presentes (TC-13).
- **Reglas de permanencia:** meta de 80 %, o de 70 % con un justificativo aceptado. Recuperación con 25 y 50 ejercicios. Alerta con 3 inasistencias seguidas (pgTAP 16 y 17).
- **Formatos chilenos:** RUT con módulo 11, tildes y ñ en CSV UTF-8 con BOM y en XLSX (TC-04, TC-15).

## 4. RNF: objetivo, método y veredicto

El catálogo completo está en [`rnf.json`](rnf.json): objetivo, método reproducible, comando, interpretación y decisión de cada RNF.

El veredicto **no se escribe a mano**. `frontend/tool/generar_informe.dart` lo calcula desde la salida de cada herramienta en `resultados/<ambiente>/`, con la beta por sobre la local. Los veredictos posibles son:

| Veredicto | Significado |
|---|---|
| **Cumple** | Medido en la beta (o es un RNF que no depende del ambiente) y dentro del objetivo |
| **Cumple en local** | Dentro del objetivo en Docker; falta confirmarlo en la beta |
| **Parcial** | Una parte medida cumple; falta otra parte del método |
| **No cumple** | Medido y fuera del objetivo |
| **No medido** | Falta ejecutar el método |

Cada desviación tiene en el informe su **interpretación** (por qué ocurre y qué riesgo implica) y una **decisión**: corregir ahora, aceptar con justificación o diferir con un hito.

## 5. Criterios de entrada y de salida

**Entrada a la medición en la beta:**
- El CI está en verde en el PR hacia `premain`: analyze, `flutter test` con ≥ 80 %, pgTAP y E2E.
- La beta está desplegada y tiene los datos de prueba que necesita la medición: las cuentas de `BETA_CUENTAS_CARGA` y `BETA_CUENTAS_ACCESO` (ver `pruebas-rnf/README.md`).

**Salida (DoD del MVP, §10):**
1. Las pruebas automatizadas de todos los niveles pasan.
2. Los 8 RNF críticos tienen veredicto **Cumple** medido en la beta.
3. No hay defectos críticos ni bloqueantes sin verificar.
4. Se hizo la validación con usuarios (TC-36) y se pasó la lista legal (TC-34).

## 6. Gestión de defectos

Cada falla se registra en [`defectos.md`](defectos.md) con ID, caso que la detectó, severidad, estado y decisión. El ciclo es:

**Abierto** → **En corrección** → **Corregido** → **Verificado**: la prueba que lo detectó pasa con el arreglo y falla sin él.

**Verificado** → **Cerrado**: la misma prueba pasa en la beta.

Un defecto también puede quedar **Aceptado** (con su justificación) o **Diferido** (con un hito). Toda corrección lleva una prueba de regresión.

## 7. Casos de prueba

La matriz TC → tipo → RF → RNF → evidencia → estado está en [`casos.json`](casos.json) y se publica en el informe.

**Observación sobre el SRS:** la matriz del §11 cita **TC-35** (RF-14), pero el catálogo de casos no lo define. Se cubre con TC-17 hasta que el SRS lo aclare.

### Casos manuales

| Caso | Qué hace falta | Pauta |
|---|---|---|
| TC-08 | Un Android y un iPhone en la beta: pasar lista, cortar el wifi, guardar, reconectar y verificar que no haya duplicados | `kit-usabilidad/README.md`, sección «Corte de conexión» |
| TC-15 | Exportar un CSV y un XLSX desde la beta y abrirlos en Excel y Google Sheets; revisar tildes, ñ y RUT | Archivar capturas en `evidencias/` |
| TC-36 | 4 tutoras externas al desarrollo, un moderador y un observador | `kit-usabilidad/` |
| TC-38 | Chrome, Safari, Edge y Firefox (las 2 últimas versiones) en dispositivos físicos | Planilla en `kit-usabilidad/navegadores.csv` |
| TC-34 | Lista legal del §5.3 firmada por la Product Owner | `lista-legal.md` |

**Responsables:** por definir. Para TC-36 el SRS pide que conduzcan dos integrantes del equipo y que las participantes no hayan intervenido en el desarrollo.

## 8. Cómo regenerar el informe

```bash
# 1. Pruebas y cobertura (desde frontend/)
flutter analyze --fatal-infos --fatal-warnings > ../docs/pruebas/resultados/local/analyze.txt
flutter test --coverage --file-reporter json:../docs/pruebas/resultados/local/flutter-test.json
bash tool/cobertura.sh coverage/lcov.info ../docs/pruebas/resultados/local
# 2. Base de datos (desde la raíz)
supabase test db > docs/pruebas/resultados/local/pgtap.txt
# 3. E2E, carga, acceso cruzado y TLS: ver pruebas-rnf/README.md
# 4. Informe
cd frontend && dart run tool/generar_informe.dart ../docs/pruebas
```

En la beta, el workflow **«Medición de RNF (beta)»** hace los pasos 3 y 4, guarda los resultados en `resultados/beta/` y vuelve a publicar el informe.
