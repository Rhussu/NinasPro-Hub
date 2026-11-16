#!/usr/bin/env bash
# TC-33 · RNF-S-3 (TLS 1.2+ en tránsito).
#
# Uso: bash pruebas-rnf/seguridad/tls.sh <host> [<host> ...] > resultados/tls.json
#   ej. bash pruebas-rnf/seguridad/tls.sh rhussu.github.io xyz.supabase.co
#
# Para cada host intenta un handshake con cada versión de TLS usando openssl.
# Cumple si TLS 1.0 y 1.1 son RECHAZADOS y TLS 1.2 o 1.3 es ACEPTADO, y el
# certificado es válido para el host. El cifrado en reposo (AES-256) no se
# puede medir desde afuera: se verifica con la documentación del proveedor
# (ver docs/pruebas/plan-de-pruebas.md, TC-33).
set -uo pipefail

[ $# -ge 1 ] || { echo "Uso: $0 <host> [<host> ...]" >&2; exit 2; }

probar() { # host flag → "aceptado" | "rechazado"
  # -sigalgs/@SECLEVEL=0 permite que el CLIENTE ofrezca TLS antiguos; así
  # medimos lo que acepta el servidor y no lo que bloquea nuestro openssl.
  if echo | timeout 15 openssl s_client -connect "$1:443" -servername "$1" "$2" -cipher 'DEFAULT:@SECLEVEL=0' \
      >/dev/null 2>&1; then echo aceptado; else echo rechazado; fi
}

primero=1
echo "{\"herramienta\":\"$(openssl version)\",\"fecha\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"hosts\":["
fallo=0
for host in "$@"; do
  t10=$(probar "$host" -tls1)
  t11=$(probar "$host" -tls1_1)
  t12=$(probar "$host" -tls1_2)
  t13=$(probar "$host" -tls1_3)
  verif=$(echo | timeout 15 openssl s_client -connect "$host:443" -servername "$host" -verify_return_error -verify_hostname "$host" 2>/dev/null \
    | grep -m1 'Verify return code' | sed 's/.*: //')
  vence=$(echo | timeout 15 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  ok=true
  [ "$t10" = rechazado ] && [ "$t11" = rechazado ] || ok=false
  [ "$t12" = aceptado ] || [ "$t13" = aceptado ] || ok=false
  [[ "$verif" == 0* ]] || ok=false
  $ok || fallo=1
  [ $primero = 1 ] || echo ","
  primero=0
  printf '{"host":"%s","tls1_0":"%s","tls1_1":"%s","tls1_2":"%s","tls1_3":"%s","certificado":"%s","vence":"%s","cumple":%s}' \
    "$host" "$t10" "$t11" "$t12" "$t13" "$verif" "$vence" "$ok"
done
echo "],\"cumple\":$([ $fallo = 0 ] && echo true || echo false)}"
exit $fallo
