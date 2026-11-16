#!/usr/bin/env bash
# Corre la prueba de carga (TC-27) dentro de Docker con latencia de red simulada.
#
# Uso: SUPABASE_URL=... SUPABASE_ANON_KEY=... CLAVE=... bash pruebas-rnf/k6/correr.sh <salida.json>
# Opcionales: VUS (30), DURACION (10m), LATENCIA (100ms), JITTER (20ms), PERDIDA (0%).
#
# La latencia se agrega con `tc netem` en un contenedor cuyo namespace de red
# comparte k6. Así el método es igual en un PC con Docker y en GitHub Actions.
# Para Supabase local usa SUPABASE_URL=http://host.docker.internal:54321.
set -euo pipefail

SALIDA="${1:?Uso: correr.sh <salida.json>}"
LATENCIA="${LATENCIA:-100ms}"
JITTER="${JITTER:-20ms}"
PERDIDA="${PERDIDA:-0%}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
DIR_SALIDA="$(cd "$(dirname "$SALIDA")" && pwd)"
RED=ninaspro-netem

docker rm -f "$RED" >/dev/null 2>&1 || true
docker run -d --name "$RED" --cap-add NET_ADMIN --add-host host.docker.internal:host-gateway alpine:3.20 sleep 7200 >/dev/null
trap 'docker rm -f "$RED" >/dev/null 2>&1 || true' EXIT
docker exec "$RED" sh -c "apk add -q iproute2 >/dev/null && tc qdisc add dev eth0 root netem delay $LATENCIA $JITTER distribution normal loss $PERDIDA"
echo "Latencia simulada: $LATENCIA ± $JITTER, pérdida $PERDIDA"
docker exec "$RED" ping -c 3 -q 1.1.1.1 2>/dev/null | tail -1 || true

MSYS_NO_PATHCONV=1 docker run --rm --network "container:$RED" \
  -v "$AQUI:/scripts:ro" -v "$DIR_SALIDA:/out" \
  -e SUPABASE_URL -e SUPABASE_ANON_KEY -e CLAVE -e VUS -e DURACION -e CUENTAS \
  grafana/k6:0.57.0 run --quiet --summary-export "/out/$(basename "$SALIDA")" /scripts/carga_sesion.js
