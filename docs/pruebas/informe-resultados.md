# Informe de resultados de pruebas · NiñasPro Hub

> Generado por `frontend/tool/generar_informe.dart` el 2026-11-16 23:22 UTC a partir de `docs/pruebas/resultados/`. No editar a mano: corregir los catálogos (`rnf.json`, `casos.json`, `defectos.md`) y volver a generar.

## Resumen

- **Pruebas ejecutadas:** 880 pasan · 0 fallan.
- **RNF críticos:** 1 de 8 cumplen.
- **Defectos:** 6 registrados, 1 abiertos.
- **Conclusión:** El MVP todavía no cumple la DoD (§10, punto 3): faltan RNF-R-1 (cumple en local), RNF-R-2 (cumple en local), RNF-S-2 (cumple en local), RNF-S-3 (parcial), RNF-U-2 (no medido), RNF-P-3 (no medido), COSTO-0 (no medido). Ningún RNF crítico medido falla; los pendientes son mediciones en la beta y pruebas con personas.

## Niveles de prueba ejecutados

| Nivel | Herramienta | Pasan | Fallan | Qué cubre | Ambiente | Evidencia |
|---|---|---|---|---|---|---|
| Unitaria | flutter test | 35 | 0 | Reglas puras: RUT módulo 11, planilla CSV/XLSX, cola sin conexión, nombres | local | `resultados/local/flutter-test.json` |
| Integración (HTTP simulado) | flutter test | 128 | 0 | Repositorios Supabase contra un cliente HTTP simulado: RPC, filtros, errores 403 | local | `resultados/local/flutter-test.json` |
| Widget / UI | flutter test | 135 | 0 | Pantallas de cada rol con repositorios falsos | local | `resultados/local/flutter-test.json` |
| Dominio | flutter test | 13 | 0 | Responsivo 360–1920 px y áreas táctiles de 44 px (RNF-U-1, U-3) | local | `resultados/local/flutter-test.json` |
| Integración (base de datos) | pgTAP (supabase test db) | 547 | 0 | 18 archivos: esquema, RLS por rol, reglas de clase, auditoría, alertas | local | `resultados/local/pgtap.txt` |
| Extremo a extremo | flutter drive + Chrome headless | 3 | 0 | Tutora pasa lista · Alumna ve solo su portal · Directiva sin MFA queda bloqueada | local | `resultados/local/e2e.txt` |
| Seguridad (acceso cruzado) | k6 sobre PostgREST/RPC | 19 | 0 | Intentos con JWT de otra sede, otra alumna, anónimo y Directiva sin MFA | local | `resultados/local/acceso-cruzado.json` |
| Carga | k6 · 30 VUs · netem | 16040 | 0 | Comprobaciones HTTP durante la carga del sábado (TC-27); no se suman al total de pruebas | local | `resultados/local/k6-carga.json` |

## RNF críticos

| RNF | Objetivo | Método reproducible | Valor obtenido | Veredicto |
|---|---|---|---|---|
| **RNF-R-1** Tiempo de respuesta | p95 ≤ 1.500 ms al guardar asistencia o cargar los datos de la sesión | k6 con 30 tutoras concurrentes durante 10 min, con las mismas llamadas REST/RPC que hace la app (instancias → sesiones → lista_asistencia_clase → guardar_asistencia_clase) y latencia de red simulada con tc netem (100 ms ± 20 ms). Se mide el p95 por operación. `SUPABASE_URL=… SUPABASE_ANON_KEY=… CLAVE=… bash pruebas-rnf/k6/correr.sh docs/pruebas/resultados/<ambiente>/k6-carga.json` | p95 cargar sesión 185 ms · guardar asistencia 146 ms _(local)_<br>Repetir en la beta (Supabase Cloud) con el workflow «Medición de RNF (beta)»: en local la base corre en el mismo PC y solo la latencia es simulada. | **Cumple en local** |
| **RNF-R-2** Throughput sostenido | ≥ 15 solicitudes por segundo sostenidas con 30 usuarias concurrentes durante 10 min, sin errores | La misma corrida de k6 de RNF-R-1: tasa media de solicitudes HTTP (http_reqs) y tasa de errores (http_req_failed < 1 %). `Ver RNF-R-1 (misma corrida)` | 26,4 req/s · 16068 solicitudes · 0,0 % de errores _(local)_<br>Repetir en la beta. | **Cumple en local** |
| **RNF-S-2** Mínimo privilegio (RBAC por rol y sede) | Ninguna cuenta accede a registros de otra sede u otra alumna; el intento se rechaza | 1) 547 pruebas pgTAP de RLS y reglas por rol (supabase test db). 2) Prueba de acceso cruzado sobre la API real: con JWT de tutora, Gestión, alumna, anónimo y Directiva sin MFA se piden IDs legítimos de otra sede u otra alumna (19 intentos). `SUPABASE_URL=… SUPABASE_ANON_KEY=… CLAVE=… k6 run pruebas-rnf/seguridad/acceso_cruzado.js` | 19/19 intentos denegados _(local)_<br>Repetir en la beta para confirmar que las políticas desplegadas son las mismas. | **Cumple en local** |
| **RNF-S-3** Protección de datos en tránsito y en reposo | TLS 1.2+ obligatorio en tránsito (TLS 1.0 y 1.1 rechazados) y AES-256 en reposo | Handshake con openssl por versión de TLS contra GitHub Pages y el host de Supabase (el cliente puede negociar TLS 1.0, así que un rechazo es del servidor). El cifrado en reposo no se mide desde afuera: se verifica en la documentación de seguridad del proveedor y se adjunta la evidencia. `bash pruebas-rnf/seguridad/tls.sh rhussu.github.io <proyecto>.supabase.co` | rhussu.github.io: TLS 1.0 rechazado, 1.1 rechazado, 1.2 aceptado, 1.3 aceptado _(local)_<br>Falta el host de Supabase de la beta (se agrega solo en la medición de la beta) y adjuntar la evidencia del proveedor sobre AES-256 en reposo. | **Parcial** |
| **RNF-U-2** Tarea principal sin ayuda | ≥ 80 % de las tutoras de prueba (mínimo 4) registran asistencia y foto sin ayuda técnica en ≤ 3 min | Prueba de usabilidad presencial del §10.3 del SRS: moderador y observador, guion de tareas, planilla de observación y SUS, con tutoras que no participaron en el desarrollo y datos ficticioscos en la beta (docs/pruebas/kit-usabilidad/). `Manual: docs/pruebas/kit-usabilidad/` | Sin sesiones de usabilidad todavía _(local)_<br>Proxy E2E (no reemplaza la prueba con personas): tarea completa de la tutora en 8633 ms | **No medido** |
| **RNF-M-1** Cobertura de pruebas en reglas críticas | ≥ 80 % de cobertura de líneas en las reglas de negocio críticas (asistencia, autorizaciones, cálculo de porcentajes) | flutter test --coverage + lcov; tool/cobertura.sh filtra los 10 archivos de Dart con reglas críticas y genera el HTML con genhtml. Las reglas que viven en la base (porcentajes, meta 80/70 %, recuperación por ejercicios, alertas) se cubren con pgTAP: lcov no mide SQL. `cd frontend && flutter test --coverage && bash tool/cobertura.sh` | 96,6 % en reglas críticas · 92,8 % global (lcov) _(local)_ | **Cumple** |
| **RNF-P-3** Tiempo de despliegue y de rollback | Despliegue automatizado ≤ 10 min y rollback ≤ 5 min | Se hace un commit a premain y luego su git revert. Se mide la duración de cada run del workflow cd-frontend.yml en GitHub Actions, desde que se crea hasta que la versión queda publicada. `bash pruebas-rnf/p3_tiempos.sh premain cd-frontend.yml` | Sin corridas en premain todavía | **No medido** |
| **COSTO-0** Restricción de costo | $0 USD/mes (capas gratuitas de GitHub y Supabase) | Revisión mensual de Billing en GitHub (Actions y Pages) y en Supabase (plan Free y uso de la organización). Se archivan capturas con fecha en docs/pruebas/evidencias/. `Manual` | Sin captura de billing archivada | **No medido** |

## Desviaciones: interpretación y decisión

### RNF-R-1 · Tiempo de respuesta — Cumple en local

- **Interpretación:** En local el p95 queda cerca de 8 veces bajo el límite y casi todo el tiempo es la latencia simulada (≈ 120 ms de ida y vuelta): la base responde en pocos milisegundos. El riesgo real está en la nube: la distancia a la región del proyecto Supabase y el plan gratuito (CPU compartida) pueden sumar cientos de milisegundos.
- **Decisión:** Se acepta como evidencia preliminar. El veredicto final sale de la medición en la beta. Si allí el p95 supera 1.500 ms: revisar la región del proyecto (elegir la más cercana a Chile), índices de clases e inscripciones y el tamaño de la respuesta de lista_asistencia_clase.

### RNF-R-2 · Throughput sostenido — Cumple en local

- **Interpretación:** La tasa la fija el ritmo de las usuarias simuladas (pausas de 1 a 3 s entre acciones, como una tutora real), no un tope del servidor: con 30 tutoras se generan ≈ 26 req/s y la base no se satura (CPU de Postgres bajo 80 % y 0 % de errores). La prueba demuestra el escenario del sábado, no la capacidad máxima.
- **Decisión:** Se acepta. Si en la beta aparecen errores 429 o 5xx, revisar los límites del plan gratuito antes de subir a producción.

### RNF-S-2 · Mínimo privilegio (RBAC por rol y sede) — Cumple en local

- **Interpretación:** Desviación de forma, no de fondo: el SRS espera «HTTP 403» y 9 de los 19 intentos responden 200 con una lista vacía. Son lecturas directas a tablas o vistas, donde RLS filtra las filas ajenas en vez de rechazar la consulta (así funciona PostgREST). Las RPC que reciben un ID explícito (lista de asistencia, guardar, exportar, portal) sí responden 403 y dejan el intento en la auditoría. En ningún caso se entregó un dato ajeno.
- **Decisión:** Se acepta (DEF-02). Se propone ajustar el método del SRS a «403, o respuesta vacía cuando la lectura pasa por RLS».

### RNF-S-3 · Protección de datos en tránsito y en reposo — Parcial

- **Interpretación:** GitHub Pages rechaza TLS 1.0 y 1.1 y acepta 1.2 y 1.3 con un certificado válido. Se comprobó que el cliente sí negocia TLS 1.0 contra un servidor que lo permite (badssl.com), así que el rechazo es del servidor y no del cliente.
- **Decisión:** Parcial hasta medir el host de la base y archivar la evidencia del cifrado en reposo. No hay nada que corregir en el código.

### RNF-U-2 · Tarea principal sin ayuda — No medido

- **Interpretación:** Falta lo esencial: personas reales. La E2E automatizada hace la misma tarea (entrar, abrir la lista, marcar 3 ausentes y guardar) en ≈ 9 s, en una compilación de depuración. Eso muestra que el sistema no pone tiempo de espera relevante, pero no mide si una tutora entiende la interfaz sin ayuda, que es lo que pide el RNF.
- **Decisión:** Bloquea el cierre del MVP (DoD 10, punto 3). Agendar 4 tutoras externas en la beta con el kit, con una cuenta de tutora por participante creada en la beta. Mientras tanto el veredicto queda «No medido».

### RNF-M-1 · Cobertura de pruebas en reglas críticas — Cumple

- **Interpretación:** Cumple con holgura en el total, pero un archivo por separado quedaba bajo el umbral: clase_repository.dart, con 79,4 %. Le faltaban pruebas de la asistencia de tutoras, «mi asistencia», las sesiones y el envío de la participación. Al agregarlas apareció DEF-01: el orden de las sesiones era descendente.
- **Decisión:** Corregido: 4 pruebas nuevas suben clase_repository.dart a 93,6 %. El CI ahora exige ≥ 80 % en las reglas críticas y en el total (tool/cobertura.sh).

### RNF-P-3 · Tiempo de despliegue y de rollback — No medido

- **Interpretación:** Riesgo identificado antes de medir: el rollback por git revert recorre el mismo pipeline que un despliegue. Ese pipeline ahora compila dos versiones (producción y beta) y corre las pruebas para el informe, así que podría pasar de 5 min.
- **Decisión:** Medir apenas exista premain. Si el rollback pasa de 5 min: sacar las pruebas del job de publicación (usar el informe del último run del CI) o volver a desplegar el artefacto anterior sin recompilar.

### COSTO-0 · Restricción de costo — No medido

- **Interpretación:** La beta suma un segundo proyecto de Supabase. El plan Free admite 2 proyectos activos por organización: con producción y beta se llega al límite.
- **Decisión:** Archivar las capturas de billing al cerrar el sprint. No crear un tercer proyecto (por ejemplo, de staging).

### RNF-R-3 · Volumen de datos — No medido

- **Interpretación:** La compresión en el dispositivo deja cada foto bajo 1,5 MB y 1920 px (prueba automatizada). Con 178 fotos al año, eso es menos de 0,3 GB. El plan Free trae 1 GB de Storage: hay margen, pero poco.
- **Decisión:** Postergado a la siguiente iteración. No es crítico.

### RNF-D-1 · Disponibilidad mensual — No medido

- **Interpretación:** El plan Free de Supabase pausa los proyectos después de 7 días sin actividad. La beta puede estar pausada justo cuando se la necesite.
- **Decisión:** Configurar el monitor contra producción. En la beta, el mismo monitor la mantiene activa.

### RNF-D-2 · RPO / RTO — Parcial

- **Interpretación:** La pérdida de la sesión en curso está cubierta: lo guardado sin conexión queda en el navegador y se sube solo al volver la red. Falta comprobar qué respaldos ofrece el plan contratado y cronometrar una restauración.
- **Decisión:** Revisar en el panel de Supabase si el plan incluye respaldos diarios descargables. Si no, programar un pg_dump diario con GitHub Actions y cronometrar la restauración en la beta.

### RNF-S-5 · Cumplimiento legal (Ley 19.628 / 21.719) — Parcial

- **Interpretación:** Lo que el sistema puede impedir, lo impide (pgTAP 14 y 09, pruebas de exportación). Falta la parte organizacional: quién firma la lista y la revisión de los ambientes.
- **Decisión:** Completar la lista con la Product Owner en la revisión del sprint.

### RNF-U-1 · Accesibilidad — Parcial

- **Interpretación:** Flutter Web dibuja en canvas: Lighthouse solo ve el árbol de semántica, así que el puntaje depende de que la semántica esté activa. Se mide sobre la beta publicada.
- **Decisión:** Correr Lighthouse contra /beta/ cuando esté publicada.

### RNF-C-1 · Navegadores y plataformas — No medido

- **Interpretación:** Safari en iPhone es el riesgo principal del proyecto (riesgo R-1 del SRS: almacenamiento sin conexión). La E2E solo cubre Chrome.
- **Decisión:** Conseguir al menos un iPhone y un Android para la sesión de usabilidad y probar ahí TC-08 y TC-38.

### RNF-C-2 · APIs y formatos — Parcial

- **Interpretación:** El archivo sale bien (UTF-8 con BOM, que es lo que Excel necesita para reconocer las tildes). Falta comprobarlo en las aplicaciones reales.
- **Decisión:** Abrir un CSV y un XLSX exportados desde la beta en Excel y en Sheets y archivar las capturas.

### RNF-M-3 · Observabilidad — No cumple

- **Interpretación:** La app no tiene FlutterError.onError ni PlatformDispatcher.onError: un error en el celular de una tutora se pierde (DEF-03).
- **Decisión:** Abierto: capturar los errores no controlados y enviarlos a una tabla de errores con su RPC. No bloquea el MVP porque M-3 no es crítico.

### RNF-P-1 · Entornos reproducibles — Parcial

- **Interpretación:** Las imágenes de Docker (pruebas-rnf/e2e/Dockerfile y la de Flutter) hacen reproducible el entorno de pruebas. Falta cronometrar con alguien que siga el README desde cero.
- **Decisión:** Que la próxima persona nueva del equipo lo cronometre.

### RNF-P-2 · Límites de recursos — Parcial

- **Interpretación:** En local cada servicio queda bajo 512 MiB. En la nube los límites son los del plan Free y se leen en su panel.
- **Decisión:** Leer el panel de Supabase durante la medición en la beta.

## Todos los RNF

| RNF | Crítico | Objetivo | Valor obtenido | Veredicto | Casos |
|---|---|---|---|---|---|
| RNF-R-1 Tiempo de respuesta | Sí | p95 ≤ 1.500 ms al guardar asistencia o cargar los datos de la sesión | p95 cargar sesión 185 ms · guardar asistencia 146 ms | Cumple en local | TC-27 |
| RNF-R-2 Throughput sostenido | Sí | ≥ 15 solicitudes por segundo sostenidas con 30 usuarias concurrentes durante 10 min, sin errores | 26,4 req/s · 16068 solicitudes · 0,0 % de errores | Cumple en local | TC-27 |
| RNF-S-2 Mínimo privilegio (RBAC por rol y sede) | Sí | Ninguna cuenta accede a registros de otra sede u otra alumna; el intento se rechaza | 19/19 intentos denegados | Cumple en local | TC-02, TC-17, TC-32 |
| RNF-S-3 Protección de datos en tránsito y en reposo | Sí | TLS 1.2+ obligatorio en tránsito (TLS 1.0 y 1.1 rechazados) y AES-256 en reposo | rhussu.github.io: TLS 1.0 rechazado, 1.1 rechazado, 1.2 aceptado, 1.3 aceptado | Parcial | TC-33 |
| RNF-U-2 Tarea principal sin ayuda | Sí | ≥ 80 % de las tutoras de prueba (mínimo 4) registran asistencia y foto sin ayuda técnica en ≤ 3 min | Sin sesiones de usabilidad todavía | No medido | TC-36 |
| RNF-M-1 Cobertura de pruebas en reglas críticas | Sí | ≥ 80 % de cobertura de líneas en las reglas de negocio críticas (asistencia, autorizaciones, cálculo de porcentajes) | 96,6 % en reglas críticas · 92,8 % global (lcov) | Cumple | TC-39 |
| RNF-P-3 Tiempo de despliegue y de rollback | Sí | Despliegue automatizado ≤ 10 min y rollback ≤ 5 min | Sin corridas en premain todavía | No medido | TC-42 |
| COSTO-0 Restricción de costo | Sí | $0 USD/mes (capas gratuitas de GitHub y Supabase) | Sin captura de billing archivada | No medido |  |
| RNF-R-3 Volumen de datos | No | ≥ 1 GB anual de fotos y ≥ 5.000 registros de asistencia | No ejecutado | No medido | TC-28 |
| RNF-D-1 Disponibilidad mensual | No | ≥ 99,0 % global y ≥ 99,5 % los sábados de 09:30 a 13:30 | Sin monitor configurado | No medido | TC-29 |
| RNF-D-2 RPO / RTO | No | RPO ≤ 24 h y RTO ≤ 2 h en la ventana de clases | Retención sin conexión: 10 pruebas pasan (sin duplicados al reconectar). Restauración: no ejecutada | Parcial | TC-08, TC-30 |
| RNF-S-1 Autenticación OIDC/OAuth2 y MFA para la Directiva | No | JWT estándar de Supabase Auth; la Directiva no accede a datos sin segundo factor (aal2) | 2/2 intentos sin MFA denegados; la E2E-03 se detiene en «Verificar» | Cumple | TC-31 |
| RNF-S-4 Auditoría trazable e inmutable | No | Quién, qué, cuándo y valor previo en cada modificación o descarga; los registros no se pueden alterar | pgTAP 12 y 06 pasan; la exportación queda registrada (directorio_screens_test) | Cumple | TC-16 |
| RNF-S-5 Cumplimiento legal (Ley 19.628 / 21.719) | No | Cumplir la lista de verificación del §5.3 | Puntos automatizables cubiertos; faltan la revisión de ambientes y la firma | Parcial | TC-34 |
| RNF-U-1 Accesibilidad | No | Contraste y áreas táctiles de al menos 44×44 px (WCAG 2.1 AA); Lighthouse Accessibility ≥ 85 | Botones ≥ 44 px en 360, 375 y 430 px de ancho; Lighthouse sin correr | Parcial | TC-37 |
| RNF-U-3 Dispositivos e idioma | No | Español de Chile; móvil desde 360 px y escritorio 1080p | 13/13 pruebas pasan, sin desbordes | Cumple | TC-37 |
| RNF-C-1 Navegadores y plataformas | No | Las 2 últimas versiones mayores de Chrome, Safari, Edge y Firefox | Solo Chrome headless (E2E). Sin dispositivos físicos | No medido | TC-38, TC-08 |
| RNF-C-2 APIs y formatos | No | JSON/HTTPS; CSV UTF-8 y XLSX sin pérdida de tildes, ñ ni RUT | Pruebas automatizadas pasan; falta abrir los archivos en Excel y Sheets | Parcial | TC-14, TC-15 |
| RNF-M-2 Estilo y linting | No | 0 errores y 0 advertencias en flutter analyze | 0 errores, 0 advertencias, 0 infos | Cumple | TC-40 |
| RNF-M-3 Observabilidad | No | Registro centralizado de errores no capturados del frontend y del backend, con marca de tiempo y mensaje | El backend queda en los logs de Supabase; el frontend no reporta sus errores no capturados | No cumple | TC-41 |
| RNF-P-1 Entornos reproducibles | No | Levantar el entorno local en una máquina limpia en ≤ 30 min siguiendo el README | En este PC todo corrió en Docker (Flutter, Supabase, k6, Chrome) sin instalar el SDK; no se cronometró en una máquina limpia | Parcial | TC-42 |
| RNF-P-2 Límites de recursos | No | < 512 MB de RAM y CPU dentro de la capa gratuita durante la carga de 30 usuarias | Local bajo carga: Postgres ≈ 249 MiB, Kong ≈ 185 MiB, PostgREST ≈ 75 MiB, Storage ≈ 78 MiB (cada uno < 512 MiB) | Parcial | TC-27 |

## Cobertura de reglas críticas (local)

Herramienta: `flutter test --coverage + lcov`. Reporte navegable: [`cobertura/`](cobertura/index.html).

| Archivo | Líneas | Cubiertas | Cobertura |
|---|---|---|---|
| `lib/data/offline/cola_sincronizacion.dart` | 109 | 107 | 98,2 % |
| `lib/repositories/alumnas_repository.dart` | 325 | 311 | 95,7 % |
| `lib/utils/calendario.dart` | 15 | 15 | 100,0 % |
| `lib/repositories/clase_repository.dart` | 218 | 204 | 93,6 % |
| `lib/repositories/justificativos_repository.dart` | 69 | 69 | 100,0 % |
| `lib/utils/exportacion.dart` | 17 | 17 | 100,0 % |
| `lib/utils/rut.dart` | 24 | 24 | 100,0 % |
| `lib/utils/planilla.dart` | 117 | 112 | 95,7 % |
| `lib/repositories/portal_repository.dart` | 89 | 89 | 100,0 % |
| `lib/screens/tutora/clase_sesion_controller.dart` | 122 | 119 | 97,5 % |

## Defectos

| ID | Caso | Severidad | Estado | Descripción | Decisión / arreglo |
|---|---|---|---|---|---|
| DEF-01 | TC-07 (E2E-01) | Crítico | Verificado | La «clase de hoy» de Tutora y Gestión era la **primera** sesión del curso: la E2E guardó la asistencia en la clase 1 (3 de octubre) en vez de la 7 (14 de noviembre). Causa: en postgrest-dart 2.9, `.order(columna)` ordena **descendente** por defecto, y `elegirSesionActual` toma la última sesión registrable. El mismo supuesto dejaba invertidas (Z→A) 14 consultas: sedes, cursos, nómina, voluntariado, roles, fotos, pendientes de importación y el cronograma. | Arreglado: `ascending: true` explícito en las 14 consultas de `lib/repositories/`. Además, las pruebas exigen `fecha.asc.nullslast` y la E2E-01 comprueba que los 3 ausentes quedan en la última clase ya realizada. Sin el arreglo la E2E falla (`resultados/local/def-01-antes/e2e.txt`); con él pasa. Pasa a Cerrado cuando la E2E pase en la beta. |
| DEF-02 | TC-02, TC-32 | Menor | Aceptado | El SRS pide «HTTP 403» ante un acceso cruzado. 9 de los 19 intentos responden **200 con una lista vacía**: son lecturas directas a tablas o vistas, donde RLS filtra las filas ajenas. | Se acepta: no se entrega ningún dato ajeno, y las RPC con un ID explícito responden 403 y registran el intento. Se propone ajustar el método del SRS a «403, o respuesta vacía cuando la lectura pasa por RLS». |
| DEF-03 | TC-41 | Mayor | Diferido | El frontend no captura los errores no controlados (no hay `FlutterError.onError` ni `PlatformDispatcher.onError`), así que un error en el celular de una tutora no queda en ningún registro centralizado. | Se difiere a la siguiente iteración (M-3 no es crítico): capturar los errores y enviarlos a una tabla de errores con su RPC y su marca de tiempo. |
| DEF-04 | TC-37 | Menor | Cerrado | US-13 pedía áreas táctiles de 48×48 px, pero el SRS (§4.4) fija 44×44 px. | US-13 se alineó con el SRS. `responsivo_test.dart` verifica los 44 px. |
| DEF-05 | TC-34 | Menor | Cerrado | En el diseño inicial, la beta cargaba `seed.sql`, cuyas cuentas usan una contraseña publicada en el repositorio: cualquiera que la leyera podía entrar a la beta. | Se rediseñó: la beta no carga `seed.sql`. Solo se crea la cuenta `directiva@ninaspro.cl` (`supabase/beta/directiva.sql`), con la clave del secreto `BETA_CLAVE_CUENTAS`; el resto de los datos lo crea el equipo. |
| DEF-06 | — | Menor | Cerrado | `CLAUDE.md` describía un mockup con datos en memoria y decía «no tocar supabase/», pero la app ya usa Supabase real. | Se actualizó `CLAUDE.md`. |

## Casos de prueba (SRS §11)

| TC | Tipo | RF | RNF | Qué verifica | Evidencia | Estado |
|---|---|---|---|---|---|---|
| TC-01 | I | RF-1 | S-2, U-3 | La instancia curso–sede genera sus sesiones; duplicado avisa; término antes del inicio se rechaza; clase suspendida no cuenta | pgTAP 07_catalogo_calendario · catalogo_repository_test · calendario_screen_test | Pasa |
| TC-02 | I/S | RF-2 | S-1, S-2, S-4 | Acceso a recursos propios permitido y a ajenos denegado (403 + registro) | pgTAP 04_auth_rls, 18_accesos_por_rol · acceso_cruzado.js (19/19) | Pasa — Las lecturas filtradas por RLS responden 200 con [] (DEF-02, aceptado) |
| TC-03 | I | RF-2 | S-1 | Invitación de un solo uso, bloqueo tras 3 intentos y cuentas según rol | pgTAP 05, 06 · auth_test | Pasa |
| TC-04 | U/I | RF-3 | C-2, S-5 | Planilla con RUT inválidos: se inscriben las válidas y las rechazadas llevan su motivo; columnas distintas rechazan el archivo | planilla_test · rut_test · alumnas_screens_test (carga masiva) · pgTAP 10 | Pasa |
| TC-05 | U | RF-3 | S-5 | Alumna de otra sede o año: una ficha, dos inscripciones | pgTAP 09_alumnas_autorizaciones · alumnas_screens_test (inscripción individual) | Pasa |
| TC-06 | I | RF-4 | S-4, S-5 | Autorizaciones de datos e imagen: activación, revocación y pendientes | pgTAP 09 · alumnas_repository_test · alumnas_screens_test (ficha) | Pasa |
| TC-07 | E | RF-5 | R-1, U-2 | Pase de lista con 3 ausentes, con autora y hora, en la clase de hoy; editable | E2E-01 (app_e2e_test.dart) · clase_repository_test · pgTAP 11 | Pasa — Encontró DEF-01 (lista guardada en la clase 1 en vez de la de hoy). Corregido y verificado |
| TC-08 | E/M | RF-5, 9, 20, 24 | D-2, C-1 | Corte de conexión: pendiente de envío y reenvío automático sin duplicados, en Android e iPhone | cola_sincronizacion_test · clase_repository_test (sin red) · hub_screens_test (nube) | Parcial — Automatizado en la lógica; falta la prueba en dispositivos físicos |
| TC-09 | I | RF-5 | — | Dos tutoras guardan la misma lista: prevalece la última y la anterior queda en el historial | clase_repository_test (US-15) · pgTAP 11_reglas_clase | Pasa |
| TC-10 | E | RF-24 | R-1, D-2 | Asistencia de 8 tutoras con 3 ausentes: 5/3 con autora y hora | clase_repository_test (TC-10) · pgTAP 15 · hub_screens_test (Gestión) | Pasa — Cubierto a nivel de integración y de widgets; no hay E2E propia |
| TC-11 | I/S | RF-8 | S-2, S-5 | Justificativo: estado, visibilidad restringida y sin diagnóstico | pgTAP 14_justificativos_evidencias · justificativos_evidencias_test · acceso_cruzado S2-07, S2-13 | Pasa |
| TC-12 | E | RF-9 | R-3, S-5 | Foto ligada a la clase, reducida, pendiente tras 48 h y advertencia por falta de autorización | justificativos_evidencias_test (compresión < 1,5 MB, pendientes) · pgTAP 14 · hub_screens_test (fotos) | Pasa — Sin E2E de subida real de la foto |
| TC-13 | I | RF-20 | — | Participación solo de presentes; sin Kahoot es «no aplica», no cero | pgTAP 13_podio_segun_presentes, 11 · clase_repository_test | Pasa |
| TC-14 | I | RF-11 | C-2, S-4 | Exportación CSV/XLSX con filtros, versión disociada y descarga registrada | directorio_screens_test (US-21, US-22) · reportes_portal_alertas_test · pgTAP 16 | Pasa |
| TC-15 | M | RF-11 | C-2 | Tildes, ñ y RUT íntegros en Excel y Google Sheets | planilla_test (UTF-8 con BOM) · voluntariado_roles_repository_test (CSV/XLSX) | Parcial — Falta abrir los archivos en Excel y Sheets |
| TC-16 | I/S | RF-12 | S-4 | Auditoría: valor anterior, autora, fecha, inmutabilidad y accesos denegados | pgTAP 12_auditoria, 06 · directorio_screens_test (auditoría) | Pasa |
| TC-17 | E/S | RF-14 | S-2, U-1, U-3 | Portal: solo datos propios, 403 al cambiar el ID y sin comparación entre compañeras | E2E-02 · acceso_cruzado S2-09 a S2-16 · reportes_portal_alertas_test · pgTAP 16 | Pasa |
| TC-18 | I | RF-23 | C-2, S-2 | Voluntariado: filas inválidas rechazadas, una ficha con dos participaciones y listado exportable | pgTAP 15_voluntariado_roles · voluntariado_roles_screens_test | Pasa |
| TC-19 | I/E | RF-6 | S-3, S-5 | Justificativo redactado por la alumna en su portal | pgTAP 14 · justificativos_evidencias_test · hub_screens_test (portal) | Pasa |
| TC-20 | I/E | RF-7 | S-2, S-4 | Bandeja de resolución de justificativos | pgTAP 14 · justificativos_evidencias_test (403 a la tutora) · hub_screens_test (Gestión) | Pasa |
| TC-21 | I/E | RF-16 | M-1, S-2 | Alerta automática con 3 inasistencias seguidas | pgTAP 16, 17_justificada_cuenta_ausente · reportes_portal_alertas_test | Pasa |
| TC-22 | I/E | RF-21 | S-5, U-1 | Encuestas de percepción | — | No aplica — Encuestas fuera del alcance de esta entrega |
| TC-23 | I/E | RF-25 | S-2, U-3 | Roles y tareas semanales de las tutoras | pgTAP 03, 15 · voluntariado_roles_repository_test · voluntariado_roles_screens_test | Pasa |
| TC-24 | I/E | RF-10 | R-1, U-3 | Dashboard por sede | directorio_screens_test (dashboard, gráfico) · pgTAP 16 | Pasa |
| TC-25 | I/E | RF-15 | S-2, S-5 | Reporte agregado para patrocinantes sin nombre ni RUT | directorio_screens_test (exportación disociada) · pgTAP 16 | Pasa |
| TC-26 | I/E | RF-18 | S-2, S-5 | Foro de consultas | — | No aplica — RF-18 (Could) no implementado |
| TC-27 | C | — | R-1, R-2, P-2 | Carga con 30 usuarias por 10 min: p95 ≤ 1,5 s, ≥ 15 req/s, RAM < 512 MB | k6 carga_sesion.js · resultados/<ambiente>/k6-carga.json | Pasa (local) — Falta repetirla en la beta |
| TC-28 | C | — | R-3 | ≈ 1 GB de fotos y 5.000 registros de asistencia | — | Pendiente |
| TC-29 | M | — | D-1 | Monitor externo de disponibilidad | — | Pendiente |
| TC-30 | M | — | D-2 | Restauración desde respaldo, midiendo RPO y RTO | — | Pendiente |
| TC-31 | S | RF-2 | S-1 | OIDC y bloqueo de la consola de la Directiva sin segundo factor | E2E-03 · acceso_cruzado S1-01, S1-02 · pgTAP 06 · auth_test | Pasa |
| TC-32 | S | RF-2, RF-14 | S-2 | Acceso cruzado entre sedes y roles | acceso_cruzado.js · pgTAP 18_accesos_por_rol | Pasa |
| TC-33 | S | RF-4, 6, 8 | S-3 | TLS 1.2+ y cifrado en reposo | tls.sh · resultados/<ambiente>/tls.json | Parcial — GitHub Pages cumple; faltan el host de Supabase y la evidencia de AES-256 |
| TC-34 | M | RF-4, RF-9 | S-5 | Lista legal del §5.3 y datos sintéticos fuera de producción | lista-legal.md | Parcial |
| TC-36 | M | RF-5, 9, 20, 24 | U-2 | Prueba de usabilidad con tutoras (§10.3) | kit-usabilidad/ | Pendiente — Faltan participantes y dispositivos |
| TC-37 | M | — | U-1, U-3 | Responsivo desde 360 px, en español | responsivo_test.dart (13 pruebas) | Pasa — Automatizada en vez de manual |
| TC-38 | M | — | C-1 | Dos últimas versiones de Chrome, Safari, Edge y Firefox en dispositivos físicos | — | Pendiente |
| TC-39 | U | — | M-1 | Cobertura ≥ 80 % en reglas críticas | tool/cobertura.sh · resultados/<ambiente>/cobertura.json · cobertura/ | Pasa |
| TC-40 | CI | — | M-2 | flutter analyze con 0 errores en cada PR | ci-flutter.yml · resultados/<ambiente>/analyze.txt | Pasa |
| TC-41 | I | — | M-3 | Error provocado y registrado con marca de tiempo | — | Falla — DEF-03: no hay captura de errores no controlados en el frontend |
| TC-42 | CI/M | — | P-1, P-3 | Despliegue ≤ 10 min y rollback ≤ 5 min | p3_tiempos.sh | Pendiente — Requiere la rama premain en GitHub |
