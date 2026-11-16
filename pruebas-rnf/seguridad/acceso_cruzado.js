// TC-02, TC-17, TC-31, TC-32 · RNF-S-2 (mínimo privilegio) y RNF-S-1 (MFA Directiva).
//
// Prueba de acceso cruzado sobre la API real (PostgREST/RPC), con los JWT de
// cuentas sintéticas del seed. Primero descubre IDs legítimos con la cuenta
// dueña y después intenta usarlos con una cuenta de OTRA sede o de otro rol.
//
// Resultado esperado de cada intento: DENEGADO, es decir, HTTP 401/403 o un
// error de la base, o bien una lectura vacía (con RLS, PostgREST responde 200 y
// [] a un SELECT sobre filas ajenas: las filas existen, pero no se ven).
//
// Uso: k6 run -e SUPABASE_URL=... -e SUPABASE_ANON_KEY=... -e CLAVE=... \
//        --summary-export resultados/acceso-cruzado.json pruebas-rnf/seguridad/acceso_cruzado.js
import http from 'k6/http';
import { check, fail } from 'k6';

const URL = __ENV.SUPABASE_URL;
const KEY = __ENV.SUPABASE_ANON_KEY;
const CLAVE = __ENV.CLAVE;

export const options = {
  iterations: 1,
  vus: 1,
  thresholds: { checks: ['rate==1'] },
};

function login(correo) {
  const r = http.post(`${URL}/auth/v1/token?grant_type=password`, JSON.stringify({ email: correo, password: CLAVE }), {
    headers: { apikey: KEY, 'Content-Type': 'application/json' },
  });
  if (r.status !== 200) fail(`No entra ${correo}: ${r.status} ${r.body}`);
  return { token: r.json('access_token'), id: r.json('user.id'), correo };
}

function h(cuenta) {
  const c = { apikey: KEY, 'Content-Type': 'application/json' };
  if (cuenta) c.Authorization = `Bearer ${cuenta.token}`;
  return { headers: c };
}

const get = (cuenta, ruta) => http.get(`${URL}/rest/v1/${ruta}`, h(cuenta));
const rpc = (cuenta, fn, cuerpo) => http.post(`${URL}/rest/v1/rpc/${fn}`, JSON.stringify(cuerpo || {}), h(cuenta));

// Denegado = error HTTP, 200 con respuesta vacía, o 200 con el código de
// "permiso denegado" de Postgres (42501) en el cuerpo. Este último caso es el
// de las RPC que registran el intento en la auditoría: si lanzaran el error,
// el registro se desharía junto con la transacción.
function denegado(r) {
  return forma(r) !== 'datos';
}

function forma(r) {
  if (r.status >= 400) return 'http_' + r.status;
  try {
    const b = r.json();
    if (b === null || (Array.isArray(b) && b.length === 0)) return 'vacio';
    if (b && !Array.isArray(b) && b.code === '42501') return 'cuerpo_42501';
    return 'datos';
  } catch (_) {
    return r.body === '' || r.body === 'null' ? 'vacio' : 'datos';
  }
}

const resultados = [];
function intento(id, descripcion, r) {
  const ok = denegado(r);
  resultados.push({ id, descripcion, http: r.status, forma: forma(r), denegado: ok, cuerpo: String(r.body).slice(0, 160) });
  check(r, { [`${id} ${descripcion}`]: () => ok });
}

export default function () {
  if (!URL || !KEY || !CLAVE) fail('Faltan SUPABASE_URL, SUPABASE_ANON_KEY o CLAVE');

  // Cuentas: por defecto las de supabase/seed.sql (local). En la beta se pasan con
  // CUENTAS_ACCESO="gestion_sede_B,gestion_sede_A,tutora_sede_A,alumna_sede_A,directiva",
  // todas con la clave CLAVE. Sede A y sede B deben ser distintas.
  const [cGestionB, cGestionA, cTutoraA, cAlumnaA, cDirectiva] = (__ENV.CUENTAS_ACCESO ||
    'valeria.troncoso.f@ninaspro.cl,camila.sepulveda@ninaspro.cl,daniela.valenzuela@ninaspro.cl,' +
    'valentina.soto@correo.cl,directiva@ninaspro.cl').split(',').map((c) => c.trim());
  const gestionSJ = login(cGestionB); // Gestión de la sede B ("otra sede")
  const gestionBeauchef = login(cGestionA); // Gestión de la sede A
  const tutoraBeauchef = login(cTutoraA); // Tutora de la sede A
  const alumna = login(cAlumnaA); // Alumna de la sede A
  const directiva = login(cDirectiva); // sin segundo factor (aal1)

  // IDs legítimos de San Joaquín, vistos por su propia Gestión
  const instSJ = get(gestionSJ, 'instancias_curso?select=id,sede_id&activo=eq.true&limit=1').json();
  if (!instSJ.length) fail('Gestión San Joaquín no ve su instancia: revisa el seed');
  const claseSJ = get(gestionSJ, `clases?select=id&instancia_curso_id=eq.${instSJ[0].id}&limit=1`).json()[0].id;
  const sedeSJ = instSJ[0].sede_id;
  const listaSJ = rpc(gestionSJ, 'lista_asistencia_clase', { p_clase_id: claseSJ });
  check(listaSJ, { 'control: Gestión ve la lista de su propia sede': (r) => r.status === 200 });

  // IDs de las alumnas de una clase de Beauchef, vistos por Gestión Beauchef
  const instB = get(gestionBeauchef, 'instancias_curso?select=id&activo=eq.true&limit=1').json();
  const claseB = instB.length ? get(gestionBeauchef, `clases?select=id&instancia_curso_id=eq.${instB[0].id}&limit=1`).json() : [];
  const listaB = claseB.length ? rpc(gestionBeauchef, 'lista_asistencia_clase', { p_clase_id: claseB[0].id }) : null;
  const otras = listaB && listaB.status === 200 ? listaB.json() : [];
  const propia = rpc(alumna, 'portal_alumna');
  check(propia, { 'control: la alumna ve su propio portal': (r) => r.status === 200 });
  const propiaId = propia.status === 200 ? propia.json('alumna.id') : null;
  const otraAlumna = (otras.find((o) => o.alumna_id !== propiaId) || {}).alumna_id;

  // --- Tutora de Beauchef sobre San Joaquín (TC-32) ---
  intento('S2-01', 'Tutora lee las clases de otra sede', get(tutoraBeauchef, `clases?select=id&instancia_curso_id=eq.${instSJ[0].id}`));
  intento('S2-02', 'Tutora lee la lista de asistencia de otra sede', rpc(tutoraBeauchef, 'lista_asistencia_clase', { p_clase_id: claseSJ }));
  intento('S2-03', 'Tutora guarda asistencia en una clase de otra sede',
    rpc(tutoraBeauchef, 'guardar_asistencia_clase', { p_clase_id: claseSJ, p_registros: [], p_guardado_en: new Date().toISOString() }));
  intento('S2-04', 'Tutora lee la nómina de otra sede', get(tutoraBeauchef, `nomina_alumnas?select=alumna_id&sede_id=eq.${sedeSJ}`));
  intento('S2-05', 'Tutora lee la auditoría', rpc(tutoraBeauchef, 'consultar_auditoria', {}));
  intento('S2-06', 'Tutora exporta un reporte', rpc(tutoraBeauchef, 'exportar_reporte', { p_tipo: 'nomina', p_sede_id: sedeSJ }));

  // --- Gestión de Beauchef sobre San Joaquín ---
  intento('S2-07', 'Gestión lee justificativos de otra sede', get(gestionBeauchef, `justificativos_detalle?select=*&sede_id=eq.${sedeSJ}`));
  intento('S2-08', 'Gestión lee la lista de asistencia de otra sede', rpc(gestionBeauchef, 'lista_asistencia_clase', { p_clase_id: claseSJ }));
  intento('S2-17', 'Gestión exporta la nómina de otra sede', rpc(gestionBeauchef, 'exportar_reporte', { p_tipo: 'asistencia', p_sede_id: sedeSJ }));

  // --- Alumna (TC-17, AT-8) ---
  if (otraAlumna) {
    intento('S2-09', 'Alumna lee la ficha de otra alumna cambiando el ID', get(alumna, `alumnas?select=id,rut&id=eq.${otraAlumna}`));
    intento('S2-10', 'Alumna lee la asistencia de otra alumna',
      get(alumna, `asistencia_alumnas?select=*,inscripciones!inner(alumna_id)&inscripciones.alumna_id=eq.${otraAlumna}`));
  }
  if (otraAlumna) intento('S2-16', 'Alumna abre el portal de otra cambiando el ID (AT-8)', rpc(alumna, 'portal_alumna', { p_alumna_id: otraAlumna }));
  intento('S2-11', 'Alumna lee la lista de asistencia de una clase', rpc(alumna, 'lista_asistencia_clase', { p_clase_id: claseSJ }));
  intento('S2-12', 'Alumna lee la nómina', get(alumna, 'nomina_alumnas?select=alumna_id'));
  intento('S2-13', 'Alumna lee los justificativos de otras', get(alumna, `justificativos_detalle?select=*&alumna_id=neq.${propiaId}`));

  // --- Sin sesión ---
  intento('S2-14', 'Anónimo lee alumnas', get(null, 'alumnas?select=id,rut'));
  intento('S2-15', 'Anónimo guarda asistencia',
    rpc(null, 'guardar_asistencia_clase', { p_clase_id: claseSJ, p_registros: [], p_guardado_en: new Date().toISOString() }));

  // --- Directiva sin segundo factor (TC-31, RNF-S-1) ---
  intento('S1-01', 'Directiva sin MFA (aal1) lee la nómina nacional', get(directiva, 'nomina_alumnas?select=alumna_id'));
  intento('S1-02', 'Directiva sin MFA (aal1) consulta la auditoría', rpc(directiva, 'consultar_auditoria', {}));

  console.log(`RESULTADOS ${JSON.stringify(resultados)}`);
}

// handleSummary corre fuera de la VU: el detalle sale de los checks.
export function handleSummary(data) {
  const resultados = [];
  for (const c of data.root_group.checks) {
    const m = c.name.match(/^(S[12]-[0-9]+) (.*)$/);
    if (m) resultados.push({ id: m[1], descripcion: m[2], denegado: c.fails === 0 && c.passes > 0 });
  }
  const total = resultados.length;
  const ok = resultados.filter((r) => r.denegado).length;
  const salida = {
    herramienta: 'k6 (acceso cruzado sobre PostgREST/RPC)',
    fecha: new Date().toISOString(),
    intentos: total,
    denegados: ok,
    cumple: total > 0 && ok === total && data.metrics.checks.values.rate === 1,
    detalle: resultados,
  };
  const destino = __ENV.SALIDA || '/out/acceso-cruzado.json';
  return { [destino]: JSON.stringify(salida, null, 2), stdout: `Denegados ${ok}/${total}\n` };
}
