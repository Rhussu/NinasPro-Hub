// TC-27 · RNF-R-1 (p95 ≤ 1.500 ms) y RNF-R-2 (≥ 15 req/s) — prueba de carga.
//
// Simula el sábado de clases: 30 tutoras concurrentes durante 10 minutos que
// abren la clase (instancias → sesiones → lista) y guardan la asistencia, con
// las MISMAS llamadas REST/RPC que hace SupabaseClaseRepository.
//
// Uso (ver pruebas-rnf/README.md):
//   k6 run -e SUPABASE_URL=... -e SUPABASE_ANON_KEY=... -e CLAVE=... \
//          --summary-export resultados/k6-resumen.json pruebas-rnf/k6/carga_sesion.js
// Variables opcionales: VUS (30), DURACION (10m), CUENTAS (lista separada por comas).
import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Counter } from 'k6/metrics';

const URL = __ENV.SUPABASE_URL;
const KEY = __ENV.SUPABASE_ANON_KEY;
const CLAVE = __ENV.CLAVE; // contraseña de las cuentas sintéticas del seed
const VUS = parseInt(__ENV.VUS || '30', 10);
const DURACION = __ENV.DURACION || '10m';

// Por defecto, las tutoras y Gestión de supabase/seed.sql (Supabase local).
// En la beta se pasan las cuentas reales de prueba con CUENTAS; todas usan la
// clave CLAVE. Cada cuenta necesita un curso con una clase ya realizada.
const CUENTAS = (__ENV.CUENTAS ||
  'camila.sepulveda@ninaspro.cl,valeria.troncoso@ninaspro.cl,daniela.valenzuela@ninaspro.cl,' +
  'francisca.herrera@ninaspro.cl,javiera.munoz@ninaspro.cl,antonia.reyes@ninaspro.cl,' +
  'catalina.soto@ninaspro.cl,martina.lagos@ninaspro.cl,fernanda.pizarro@ninaspro.cl,' +
  'constanza.vidal@ninaspro.cl').split(',').map((c) => c.trim());

const errores = new Counter('errores_negocio');

export const options = {
  scenarios: {
    sabado_de_clases: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURACION,
    },
  },
  thresholds: {
    // RNF-R-1: cargar datos de la sesión y guardar asistencia
    'http_req_duration{operacion:cargar_sesion}': ['p(95)<1500'],
    'http_req_duration{operacion:guardar_asistencia}': ['p(95)<1500'],
    // RNF-R-2: throughput sostenido
    http_reqs: ['rate>=15'],
    http_req_failed: ['rate<0.01'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function cabeceras(token) {
  return {
    apikey: KEY,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

function hoy() {
  return new Date().toISOString().slice(0, 10);
}

// Inicia sesión con cada cuenta y prepara su clase: la última que ya llegó a su
// fecha y no está suspendida (la "clase de hoy" de la app).
export function setup() {
  if (!URL || !KEY || !CLAVE) fail('Faltan SUPABASE_URL, SUPABASE_ANON_KEY o CLAVE');
  const tutoras = [];
  for (const correo of CUENTAS) {
    const r = http.post(
      `${URL}/auth/v1/token?grant_type=password`,
      JSON.stringify({ email: correo, password: CLAVE }),
      { headers: { apikey: KEY, 'Content-Type': 'application/json' }, tags: { operacion: 'login' } },
    );
    if (r.status !== 200) { console.warn(`No entra ${correo}: ${r.status}`); continue; }
    const token = r.json('access_token');
    const id = r.json('user.id');
    const h = cabeceras(token);
    const inst = http.get(
      `${URL}/rest/v1/instancias_curso?select=id,tutores_instancia!inner(tutor_id)&activo=eq.true&tutores_instancia.tutor_id=eq.${id}`,
      { headers: h, tags: { operacion: 'login' } },
    ).json();
    if (!inst.length) { console.warn(`${correo} no tiene cursos`); continue; }
    // La clase más reciente ya realizada que tenga un pase de lista guardado:
    // la carga reenvía esa lista sin cambiarla.
    const clases = http.get(
      `${URL}/rest/v1/clases?select=id,fecha,estado&instancia_curso_id=eq.${inst[0].id}&fecha=lte.${hoy()}&estado=neq.suspendida&order=fecha.desc&limit=8`,
      { headers: h, tags: { operacion: 'login' } },
    ).json();
    const conLista = clases.find((c) => {
      const l = http.post(`${URL}/rest/v1/rpc/lista_asistencia_clase`, JSON.stringify({ p_clase_id: c.id }), { headers: h, tags: { operacion: 'login' } });
      return l.status === 200 && l.json().some((f) => f.estado === 'presente' || f.estado === 'ausente');
    });
    if (!conLista) { console.warn(`${correo} no tiene una clase realizada con pase de lista guardado`); continue; }
    tutoras.push({ correo, id, token, instancia: inst[0].id, clase: conLista.id });
  }
  if (!tutoras.length) fail('Ninguna cuenta pudo preparar su clase');
  console.log(`Cuentas listas: ${tutoras.length}/${CUENTAS.length}`);
  return { tutoras };
}

export default function (datos) {
  const t = datos.tutoras[(__VU - 1) % datos.tutoras.length];
  const h = cabeceras(t.token);
  const carga = { headers: h, tags: { operacion: 'cargar_sesion' } };

  // 1. Cargar datos de la sesión (lo que hace la app al abrir la clase)
  const inst = http.get(
    `${URL}/rest/v1/instancias_curso?select=id,tutores_instancia!inner(tutor_id)&activo=eq.true&tutores_instancia.tutor_id=eq.${t.id}`,
    carga,
  );
  check(inst, { 'instancias 200': (r) => r.status === 200 });
  const ses = http.get(
    `${URL}/rest/v1/clases?select=id,numero_sesion,fecha,hora_inicio,hora_fin,estado,motivo_suspension,es_especial,planificacion_clases(tema_titulo)&instancia_curso_id=eq.${t.instancia}&order=fecha`,
    carga,
  );
  check(ses, { 'sesiones 200': (r) => r.status === 200 });
  const lista = http.post(`${URL}/rest/v1/rpc/lista_asistencia_clase`, JSON.stringify({ p_clase_id: t.clase }), carga);
  if (!check(lista, { 'lista 200': (r) => r.status === 200 })) { errores.add(1); sleep(2); return; }

  sleep(1 + Math.random() * 2); // la tutora marca presentes y ausentes

  // 2. Guardar la asistencia. Se reenvía EXACTAMENTE lo que ya está guardado
  //    (presentes y ausentes; las justificadas no se tocan), así la medición no
  //    cambia los datos de la beta ni llena la auditoría: un UPDATE sin cambios
  //    no se audita. Por eso la clase debe tener un pase de lista guardado.
  const registros = lista.json()
    .filter((f) => f.estado === 'presente' || f.estado === 'ausente')
    .map((f) => ({ inscripcion_id: f.inscripcion_id, estado: f.estado }));
  if (!registros.length) {
    if (__ITER === 0) console.warn(`${t.correo}: la clase no tiene pase de lista guardado; no se mide el guardado`);
    sleep(2);
    return;
  }
  const g = http.post(
    `${URL}/rest/v1/rpc/guardar_asistencia_clase`,
    JSON.stringify({ p_clase_id: t.clase, p_registros: registros, p_guardado_en: new Date().toISOString() }),
    { headers: h, tags: { operacion: 'guardar_asistencia' } },
  );
  if (!check(g, { 'guardar 200': (r) => r.status === 200 })) {
    errores.add(1);
    if (__ITER === 0) console.warn(`guardar ${t.correo}: ${g.status} ${g.body}`);
  }

  sleep(1 + Math.random() * 2);
}
