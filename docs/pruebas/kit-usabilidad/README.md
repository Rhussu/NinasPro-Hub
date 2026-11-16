# Kit de usabilidad · TC-36 (RNF-U-2) y TC-08 / TC-38

Pauta del SRS §10.3 para medir **RNF-U-2**: al menos el 80 % de las tutoras de prueba registran la asistencia y la foto sin ayuda técnica en ≤ 3 minutos.

## Antes de la sesión
- [ ] Beta publicada (`/beta/`) con un curso, una clase de hoy y alumnas **ficticias** creadas desde la cuenta de la Directiva.
- [ ] Una cuenta de tutora por participante, creada en la beta.
- [ ] Participantes: **4 tutoras como mínimo**, que no hayan participado en el desarrollo ni usado antes la app.
- [ ] Consentimiento informado firmado (Anexo H del SRS). No se registran nombres ni rostros en la planilla.
- [ ] Roles: un **moderador**, que presenta las tareas y no ayuda ni da pistas, y un **observador**, que cronometra y anota.
- [ ] Dispositivos: el celular propio de cada tutora. Anotar el modelo, el sistema y el navegador (sirve también para TC-38).

## Tareas (en este orden, con el cronómetro corriendo)
| # | Tarea que lee el moderador | Éxito | Tiempo máximo |
|---|---|---|---|
| T1 | «Entra con la cuenta que te pasamos y pasa lista de la clase de hoy. Hoy faltaron las 3 primeras de la lista.» | Lista guardada con 3 ausentes en la clase de hoy | 3 min (junto con T2) |
| T2 | «Sube una foto de la clase.» | Foto ligada a la clase | (incluida en los 3 min) |
| T3 | «Una alumna te mandó un justificativo: búscalo.» | Llega a la bandeja | 2 min |

Para RNF-U-2 se cronometran **T1 + T2** juntas, desde que la tutora toca «Ingresar».

## Planilla de observación
Completar `planilla-observacion.csv`, con una fila por participante y tarea:
- `resultado`: `sin_ayuda`, `con_pista` o `no_completa`.
- `segundos`.
- `errores`.
- `donde_se_detuvo`.

**Cálculo del veredicto:**

% de éxito = participantes con T1+T2 `sin_ayuda` y ≤ 180 s ÷ total de participantes.

**Cumple** si el resultado es ≥ 80 %.

## SUS (System Usability Scale)
Al terminar, cada participante responde `sus.csv` en una escala de 1 a 5.

Puntaje SUS = 2,5 × [Σ(impares − 1) + Σ(5 − pares)]. Se reporta el promedio y el rango; la hipótesis H3 es un SUS ≥ 68.

## Corte de conexión (TC-08) y navegadores (TC-38)
Con un Android y un iPhone:
1. Abrir la lista.
2. Activar el modo avión y guardar. Debe aparecer «Pendiente de envío».
3. Desactivar el modo avión. La nube debe pasar a «todo guardado» sin hacer nada más.
4. Verificar en la beta que no haya registros duplicados.

Anotar el resultado en `navegadores.csv`.
