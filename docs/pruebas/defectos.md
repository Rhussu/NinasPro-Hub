# Registro de defectos

Cada falla que encuentran las pruebas entra aquí, con su estado. Este archivo es
la fuente de verdad: `frontend/tool/generar_informe.dart` lo lee para armar el informe.

**Severidad**
- **Bloqueante:** impide usar el sistema.
- **Crítico:** produce datos incorrectos o expone datos.
- **Mayor:** incumple un requisito sin dañar datos.
- **Menor:** forma, documentación o un riesgo bajo.

**Estados**
- Flujo normal: `Abierto` → `En corrección` → `Corregido` → `Verificado` → `Cerrado`.
- `Aceptado`: se decide convivir con el defecto, con justificación.
- `Diferido`: se corrige en una iteración posterior, con fecha o hito.

Un defecto queda **Cerrado** cuando la prueba que lo detectó pasa en la beta.

| ID | Fecha | Caso | US / RNF | Severidad | Estado | Descripción | Decisión / arreglo |
|---|---|---|---|---|---|---|---|
| DEF-01 | 2026-11-16 | TC-07 (E2E-01) | US-13, RB-7 | Crítico | Verificado | La «clase de hoy» de Tutora y Gestión era la **primera** sesión del curso: la E2E guardó la asistencia en la clase 1 (3 de octubre) en vez de la 7 (14 de noviembre). Causa: en postgrest-dart 2.9, `.order(columna)` ordena **descendente** por defecto, y `elegirSesionActual` toma la última sesión registrable. El mismo supuesto dejaba invertidas (Z→A) 14 consultas: sedes, cursos, nómina, voluntariado, roles, fotos, pendientes de importación y el cronograma. | Arreglado: `ascending: true` explícito en las 14 consultas de `lib/repositories/`. Además, las pruebas exigen `fecha.asc.nullslast` y la E2E-01 comprueba que los 3 ausentes quedan en la última clase ya realizada. Sin el arreglo la E2E falla (`resultados/local/def-01-antes/e2e.txt`); con él pasa. Pasa a Cerrado cuando la E2E pase en la beta. |
| DEF-02 | 2026-11-16 | TC-02, TC-32 | RNF-S-2 | Menor | Aceptado | El SRS pide «HTTP 403» ante un acceso cruzado. 9 de los 19 intentos responden **200 con una lista vacía**: son lecturas directas a tablas o vistas, donde RLS filtra las filas ajenas. | Se acepta: no se entrega ningún dato ajeno, y las RPC con un ID explícito responden 403 y registran el intento. Se propone ajustar el método del SRS a «403, o respuesta vacía cuando la lectura pasa por RLS». |
| DEF-03 | 2026-11-16 | TC-41 | RNF-M-3 | Mayor | Diferido | El frontend no captura los errores no controlados (no hay `FlutterError.onError` ni `PlatformDispatcher.onError`), así que un error en el celular de una tutora no queda en ningún registro centralizado. | Se difiere a la siguiente iteración (M-3 no es crítico): capturar los errores y enviarlos a una tabla de errores con su RPC y su marca de tiempo. |
| DEF-04 | 2026-11-16 | TC-37 | RNF-U-1 | Menor | Cerrado | US-13 pedía áreas táctiles de 48×48 px, pero el SRS (§4.4) fija 44×44 px. | US-13 se alineó con el SRS. `responsivo_test.dart` verifica los 44 px. |
| DEF-05 | 2026-11-16 | TC-34 | RNF-S-5 | Menor | Cerrado | En el diseño inicial, la beta cargaba `seed.sql`, cuyas cuentas usan una contraseña publicada en el repositorio: cualquiera que la leyera podía entrar a la beta. | Se rediseñó: la beta no carga `seed.sql`. Solo se crea la cuenta `directiva@ninaspro.cl` (`supabase/beta/directiva.sql`), con la clave del secreto `BETA_CLAVE_CUENTAS`; el resto de los datos lo crea el equipo. |
| DEF-06 | 2026-11-16 | — | RNF-P-1 | Menor | Cerrado | `CLAUDE.md` describía un mockup con datos en memoria y decía «no tocar supabase/», pero la app ya usa Supabase real. | Se actualizó `CLAUDE.md`. |
