#!/usr/bin/env bash
# Cobertura de líneas (RNF-M-1, TC-39).
#
# Uso (desde frontend/, después de `flutter test --coverage`):
#   bash tool/cobertura.sh [coverage/lcov.info] [carpeta_salida] [umbral]
#
# Calcula la cobertura global y la de las REGLAS CRÍTICAS (asistencia,
# autorizaciones, cálculo de porcentajes, según el SRS §4.6), genera el HTML
# con genhtml en coverage/html y escribe <salida>/cobertura.json.
# Sale con código 1 si las reglas críticas quedan bajo el umbral (80 % por defecto).
set -euo pipefail

LCOV="${1:-coverage/lcov.info}"
SALIDA="${2:-coverage}"
UMBRAL="${3:-80}"

# Archivos de Dart que implementan reglas críticas. Las reglas que viven en la
# base (porcentajes, meta, alertas) se prueban con pgTAP (supabase/tests).
CRITICAS=(
  lib/utils/rut.dart
  lib/utils/planilla.dart
  lib/utils/calendario.dart
  lib/utils/exportacion.dart
  lib/data/offline/cola_sincronizacion.dart
  lib/repositories/clase_repository.dart
  lib/repositories/alumnas_repository.dart
  lib/repositories/justificativos_repository.dart
  lib/repositories/portal_repository.dart
  lib/screens/tutora/clase_sesion_controller.dart
)

[ -f "$LCOV" ] || { echo "No existe $LCOV: corre antes flutter test --coverage" >&2; exit 2; }
mkdir -p "$SALIDA"

lista=$(IFS=,; echo "${CRITICAS[*]}")

awk -F: -v criticas="$lista" -v umbral="$UMBRAL" '
  BEGIN { n = split(criticas, c, ","); for (i = 1; i <= n; i++) es[c[i]] = 1 }
  /^SF:/ { f = substr($0, 4) }
  /^LF:/ { lf = $2 }
  /^LH:/ {
    lh = $2; T += lf; H += lh
    if (f in es) { CT += lf; CH += lh; vistos[f] = 1
      det = det sprintf("%s{\"archivo\":\"%s\",\"lineas\":%d,\"cubiertas\":%d,\"porcentaje\":%.1f}", (det ? "," : ""), f, lf, lh, (lf ? 100 * lh / lf : 0)) }
  }
  END {
    for (k in es) if (!(k in vistos)) faltan = faltan sprintf("%s\"%s\"", (faltan ? "," : ""), k)
    g = (T ? 100 * H / T : 0); cr = (CT ? 100 * CH / CT : 0)
    printf "{\"herramienta\":\"flutter test --coverage + lcov\",\"umbral\":%s,", umbral
    printf "\"global\":{\"lineas\":%d,\"cubiertas\":%d,\"porcentaje\":%.2f},", T, H, g
    printf "\"criticas\":{\"lineas\":%d,\"cubiertas\":%d,\"porcentaje\":%.2f,\"archivos\":[%s],\"sin_datos\":[%s]}}\n", CT, CH, cr, det, faltan
  }' "$LCOV" > "$SALIDA/cobertura.json"

cat "$SALIDA/cobertura.json"

if command -v genhtml >/dev/null 2>&1; then
  genhtml -q "$LCOV" -o coverage/html --title "NiñasPro Hub · cobertura" >/dev/null || echo "genhtml falló; se omite el HTML" >&2
fi

criticas=$(sed -E 's/.*"criticas":\{"lineas":[0-9]+,"cubiertas":[0-9]+,"porcentaje":([0-9.]+).*/\1/' "$SALIDA/cobertura.json")
global=$(sed -E 's/.*"global":\{"lineas":[0-9]+,"cubiertas":[0-9]+,"porcentaje":([0-9.]+).*/\1/' "$SALIDA/cobertura.json")
echo "Cobertura global: ${global}% · reglas críticas: ${criticas}% (umbral ${UMBRAL}%)"
awk -v c="$criticas" -v g="$global" -v u="$UMBRAL" 'BEGIN { exit !(c >= u && g >= u) }' || {
  echo "❌ Cobertura bajo el ${UMBRAL}% (RNF-M-1)"; exit 1; }
echo "✅ RNF-M-1 cumple"
