#!/usr/bin/env bash
# Corre integration_test/app_e2e_test.dart en Chrome headless dentro de Docker.
# Uso: SUPABASE_URL=http://host.docker.internal:54321 SUPABASE_ANON_KEY=... CLAVE=... \
#        bash pruebas-rnf/e2e/correr.sh <carpeta_salida>
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
SALIDA="$(mkdir -p "${1:?Uso: correr.sh <carpeta_salida>}" && cd "$1" && pwd)"
docker build -q -t ninaspro-e2e "$RAIZ/pruebas-rnf/e2e" >/dev/null
MSYS_NO_PATHCONV=1 docker run --rm --add-host host.docker.internal:host-gateway \
  -v "$RAIZ:/src:ro" -v "$SALIDA:/out" -v ninaspro-pubcache:/root/.pub-cache \
  -e SUPABASE_URL -e SUPABASE_ANON_KEY -e CLAVE ninaspro-e2e bash -c '
    set -e
    mkdir -p /app && cd /src && tar --exclude=frontend/build --exclude=frontend/.dart_tool --exclude=.git -cf - . | (cd /app && tar xf -)
    cd /app/frontend && flutter pub get >/dev/null
    chromedriver --port=4444 --silent &
    sleep 1
    set +e
    flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_e2e_test.dart \
      -d web-server --browser-name=chrome --headless --no-version-check \
      --web-browser-flag=--no-sandbox --web-browser-flag=--disable-dev-shm-usage \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
      --dart-define=E2E_CLAVE="$CLAVE" 2>&1 | tee /out/e2e.txt
    codigo=${PIPESTATUS[0]}
    cp build/integration_response_data.json /out/e2e-tiempos.json 2>/dev/null || true
    exit $codigo'
