# Arnés de medición de RNF

Scripts reproducibles para medir los RNF del SRS §4. Solo necesitan Docker y bash: no hace falta instalar k6, Flutter ni Chrome.

**Nunca se mide contra producción.** El blanco es la base local o la beta.

| Script | RNF / TC | Qué mide |
|---|---|---|
| `k6/correr.sh` + `k6/carga_sesion.js` | R-1, R-2, P-2 / TC-27 | 30 tutoras por 10 min con latencia simulada (`tc netem`): p95 por operación y req/s |
| `seguridad/acceso_cruzado.js` | S-1, S-2 / TC-02, 17, 31, 32 | 19 intentos de acceso cruzado con JWT de otra sede, de otra alumna, anónimo y de la Directiva sin MFA |
| `seguridad/tls.sh` | S-3 / TC-33 | Qué versiones de TLS acepta cada host y si el certificado es válido |
| `e2e/correr.sh` + `e2e/Dockerfile` | TC-07, 17, 31 | `flutter drive` en Chrome headless contra Supabase |
| `p3_tiempos.sh` | P-3 / TC-42 | Duración del despliegue y del rollback en GitHub Actions |

## En local (Supabase en Docker)

```bash
npx supabase start            # migraciones + seed.sql
export SUPABASE_URL=http://host.docker.internal:54321
export SUPABASE_ANON_KEY=<ANON_KEY de `npx supabase status`>
export CLAVE=NinasPro2026     # contraseña de las cuentas del seed
R=docs/pruebas/resultados/local

bash pruebas-rnf/k6/correr.sh $R/k6-carga.json | tee $R/k6-carga.txt
docker run --rm --add-host host.docker.internal:host-gateway \
  -v "$PWD/pruebas-rnf/seguridad:/scripts:ro" -v "$PWD/$R:/out" \
  -e SUPABASE_URL -e SUPABASE_ANON_KEY -e CLAVE grafana/k6:0.57.0 run --quiet /scripts/acceso_cruzado.js
bash pruebas-rnf/seguridad/tls.sh rhussu.github.io > $R/tls.json
bash pruebas-rnf/e2e/correr.sh $R
npx supabase test db > $R/pgtap.txt
```

Las variables opcionales de la carga son `VUS`, `DURACION`, `LATENCIA`, `JITTER` y `PERDIDA`. Por ejemplo, `VUS=5 DURACION=30s` sirve como prueba de humo.

## En la beta

Se hace desde **Actions → «Medición de RNF (beta)» → Run workflow**, sobre la rama `premain`. El workflow necesita estos secretos:
- `BETA_SUPABASE_URL`
- `BETA_SUPABASE_ANON_KEY`
- `BETA_CLAVE_CUENTAS`: la contraseña de las cuentas de prueba de la beta.

La beta no tiene los datos de `seed.sql`, así que antes de medir hay que crear las cuentas de prueba en la app, todas con la clave de `BETA_CLAVE_CUENTAS`, y declararlas como **variables** del repositorio (Settings → Secrets and variables → Actions → Variables):
- `BETA_CUENTAS_CARGA`: correos de tutoras o de Gestión, separados por comas. Cada una necesita un curso asignado y una clase ya realizada **con el pase de lista guardado**. La carga reenvía exactamente esa lista, así que no cambia los datos ni deja registros en la auditoría.
- `BETA_CUENTAS_ACCESO`: `gestion_sede_B,gestion_sede_A,tutora_sede_A,alumna_sede_A,directiva` (cinco correos, dos sedes distintas, y la alumna con al menos una compañera inscrita).

Los resultados quedan en `docs/pruebas/resultados/beta/` y el informe se vuelve a publicar.

## Cómo leer los resultados

`frontend/tool/generar_informe.dart` lee estos archivos y calcula el veredicto de cada RNF (ver `docs/pruebas/plan-de-pruebas.md`). La medición local sirve de evidencia preliminar («Cumple en local»). El veredicto oficial sale de la beta.
