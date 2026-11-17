#!/usr/bin/env bash
# Arma el SQL de los DATOS DE PRUEBA de la beta a partir de supabase/seed.sql,
# para que la beta y las pruebas locales usen los mismos datos ficticios.
#
# Uso: CLAVE='<clave de las cuentas>' bash supabase/beta/datos_prueba.sh > datos.sql
#
# Diferencias con seed.sql:
#   - No crea la cuenta de la Directiva: ya existe (supabase/beta/directiva.sql)
#     y se la referencia por su correo.
#   - Todas las cuentas usan la clave CLAVE (secreto BETA_CLAVE_CUENTAS), no la
#     clave publicada en el repositorio.
#   - Agrega una segunda alumna con cuenta (compañera, para el acceso cruzado)
#     y una clase futura suspendida.
#   - Si los datos ya están cargados, no hace nada (la transacción se aborta).
set -euo pipefail
: "${CLAVE:?Falta CLAVE}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
SEED="$AQUI/../seed.sql"
DIRECTIVA_SEED="'153a59dc-cc3d-516f-92db-27df6fe5dd6b'"

# Comillas simples duplicadas para SQL; perl no reinterpreta el valor
export CLAVE_SQL="$(printf '%s' "$CLAVE" | sed "s/'/''/g")"

cat <<'EOF'
-- =============================================================================
-- Datos de prueba de la BETA (generado por supabase/beta/datos_prueba.sh
-- desde supabase/seed.sql). Todo es ficticio. No editar a mano.
-- =============================================================================
EOF

sed -e "/'directiva@ninaspro.cl'/d" \
    -e "s/$DIRECTIVA_SEED/(SELECT id FROM auth.users WHERE email = 'directiva@ninaspro.cl')/g" \
    -e "s/'NinasPro2026'/'__CLAVE__'/g" \
    -e "/^-- Todas las cuentas demo usan la contraseña/d" \
    -e "/^--   directiva@ninaspro.cl/d" \
    "$SEED" |
awk '
  /^BEGIN;$/ && !hecho_inicio {
    print
    print ""
    print "-- Guardas: la Directiva debe existir y los datos no deben estar cargados"
    print "DO $$"
    print "BEGIN"
    print "  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = '\''directiva@ninaspro.cl'\'') THEN"
    print "    RAISE EXCEPTION '\''Primero crea la cuenta de la Directiva (crear_directiva=true)'\'';"
    print "  END IF;"
    print "  IF EXISTS (SELECT 1 FROM public.sedes WHERE id = '\''86e8126c-4085-5643-8d87-3ee4ed689f96'\'') THEN"
    print "    RAISE EXCEPTION '\''Los datos de prueba ya están cargados en esta base: no se cargan dos veces'\'';"
    print "  END IF;"
    print "END $$;"
    hecho_inicio = 1
    next
  }
  /^COMMIT;$/ {
    print "-- ---------------------------------------------------------------------------"
    print "-- Extras de la beta"
    print "-- ---------------------------------------------------------------------------"
    print "-- Segunda alumna con cuenta en la Sede Beauchef (la compañera del acceso cruzado)"
    print "INSERT INTO public.correos_autorizados (correo, rol, sede_id, alumna_id, autorizado_por) VALUES ('\''florencia.munoz@correo.cl'\'', '\''alumna'\'', '\''86e8126c-4085-5643-8d87-3ee4ed689f96'\'', '\''3ebf929d-448b-5114-bd81-344eae48f6da'\'', '\''9fc64a9c-583f-5ea3-b88c-abdcd2b255fa'\'');"
    print "INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current, reauthentication_token) VALUES ('\''00000000-0000-0000-0000-000000000000'\'', '\''7c1e2d8a-5b0f-4c3e-9a61-2f4b8d9e0a17'\'', '\''authenticated'\'', '\''authenticated'\'', '\''florencia.munoz@correo.cl'\'', extensions.crypt('\''__CLAVE__'\'', extensions.gen_salt('\''bf'\'')), now(), '\''{\"provider\":\"email\",\"providers\":[\"email\"]}'\'', '\''{}'\'', now(), now(), '\'''\'', '\'''\'', '\'''\'', '\'''\'', '\'''\'', '\'''\'');"
    print "INSERT INTO auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at) VALUES (gen_random_uuid(), '\''7c1e2d8a-5b0f-4c3e-9a61-2f4b8d9e0a17'\'', '\''7c1e2d8a-5b0f-4c3e-9a61-2f4b8d9e0a17'\'', '\''email'\'', jsonb_build_object('\''sub'\'', '\''7c1e2d8a-5b0f-4c3e-9a61-2f4b8d9e0a17'\'', '\''email'\'', '\''florencia.munoz@correo.cl'\'', '\''email_verified'\'', true), now(), now(), now());"
    print ""
    print "-- Una clase futura de Beauchef suspendida (calendario, US-03)"
    print "UPDATE public.clases SET estado = '\''suspendida'\'', motivo_suspension = '\''Feriado (dato de prueba)'\''"
    print "WHERE id = (SELECT id FROM public.clases WHERE instancia_curso_id = '\''f58950d7-e247-5afd-9f19-835cb908e9ec'\'' AND fecha > current_date ORDER BY fecha DESC LIMIT 1);"
    print ""
  }
  { print }
' |
perl -pe 's/__CLAVE__/$ENV{CLAVE_SQL}/g'
