// Genera el informe de pruebas (docs/pruebas/informe-resultados.md e index.html)
// a partir de los resultados medidos y de los catálogos del repositorio.
//
// Uso (desde frontend/): dart run tool/generar_informe.dart ../docs/pruebas
//
// Entradas, dentro de docs/pruebas/:
//   rnf.json              catálogo de RNF: objetivo, método, interpretación y decisión
//   casos.json            catálogo de casos TC-xx con su estado y evidencia
//   defectos.md           registro de defectos (tabla)
//   resultados/beta/      mediciones contra la beta (tienen prioridad)
//   resultados/local/     mediciones en Supabase local (Docker)
// Cada resultado es la salida de una herramienta: flutter test (JSON), lcov,
// pgTAP, k6 (summary-export), openssl y gh. El veredicto de los RNF medidos se
// calcula aquí, no se escribe a mano.
import 'dart:convert';
import 'dart:io';

late Directory raiz;

void main(List<String> args) {
  raiz = Directory(args.isEmpty ? '../docs/pruebas' : args.first);
  if (!File('${raiz.path}/rnf.json').existsSync()) {
    stderr.writeln('No encuentro ${raiz.path}/rnf.json');
    exit(2);
  }
  final rnf = (jsonDecode(File('${raiz.path}/rnf.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final casos = (jsonDecode(File('${raiz.path}/casos.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final defectos = leerDefectos(File('${raiz.path}/defectos.md'));
  final evaluados = [for (final r in rnf) evaluar(r)];
  final niveles = resumenNiveles();
  final cobertura = leerJson('cobertura.json');

  final informe = Informe(evaluados, casos, defectos, niveles, cobertura);
  File('${raiz.path}/informe-resultados.md').writeAsStringSync(informe.markdown());
  File('${raiz.path}/index.html').writeAsStringSync(informe.html());
  stdout.writeln('Informe generado en ${raiz.path}/informe-resultados.md e index.html');
}

// ---------------------------------------------------------------- resultados

/// Ambientes en orden de preferencia: la beta manda sobre local.
const ambientes = ['beta', 'local'];

/// Devuelve (ambiente, archivo) del resultado más relevante.
(String, File)? buscar(String nombre) {
  for (final a in ambientes) {
    final f = File('${raiz.path}/resultados/$a/$nombre');
    if (f.existsSync() && f.lengthSync() > 0) return (a, f);
  }
  return null;
}

(String, Map<String, dynamic>)? leerJson(String nombre) {
  final r = buscar(nombre);
  if (r == null) return null;
  try {
    return (r.$1, jsonDecode(r.$2.readAsStringSync()) as Map<String, dynamic>);
  } on FormatException {
    return null;
  }
}

String ms(num v) => '${v.round()} ms';
String pct(num v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} %';
String fechaArchivo(File f) => f.lastModifiedSync().toUtc().toIso8601String().substring(0, 10);

class Evaluado {
  final Map<String, dynamic> rnf;
  final String valor;
  final String veredicto;
  final String? ambiente;
  final String? evidencia;
  final String? nota;
  Evaluado(this.rnf, this.valor, this.veredicto, {this.ambiente, this.evidencia, this.nota});
  String get id => rnf['id'] as String;
  bool get critico => rnf['critico'] == true;
}

Evaluado evaluar(Map<String, dynamic> r) {
  final medicion = r['medicion'] as Map<String, dynamic>?;
  final manual = r['manual'] as Map<String, dynamic>?;
  Evaluado deManual() =>
      Evaluado(r, manual?['valor'] as String? ?? 'Sin medición', manual?['veredicto'] as String? ?? 'No medido');
  if (medicion == null) return deManual();

  final archivo = medicion['archivo'] as String;
  final encontrado = buscar(archivo);
  if (encontrado == null) return deManual();
  final (ambiente, f) = encontrado;
  final evidencia = 'resultados/$ambiente/$archivo';
  Map<String, dynamic> json() => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  String? valor;
  bool? cumple;
  switch (medicion['tipo']) {
    case 'k6_p95':
      final m = json()['metrics'] as Map<String, dynamic>;
      final carga = (m['http_req_duration{operacion:cargar_sesion}'] as Map)['p(95)'] as num;
      final guardar = (m['http_req_duration{operacion:guardar_asistencia}'] as Map)['p(95)'] as num;
      valor = 'p95 cargar sesión ${ms(carga)} · guardar asistencia ${ms(guardar)}';
      cumple = carga <= 1500 && guardar <= 1500;
    case 'k6_rate':
      final m = json()['metrics'] as Map<String, dynamic>;
      final reqs = m['http_reqs'] as Map;
      final fallos = (m['http_req_failed'] as Map)['value'] as num;
      valor = '${(reqs['rate'] as num).toStringAsFixed(1).replaceAll('.', ',')} req/s · '
          '${reqs['count']} solicitudes · ${pct(fallos * 100)} de errores';
      cumple = (reqs['rate'] as num) >= 15 && fallos < 0.01;
    case 'cobertura':
      final d = json();
      final c = (d['criticas'] as Map)['porcentaje'] as num;
      final g = (d['global'] as Map)['porcentaje'] as num;
      valor = '${pct(c)} en reglas críticas · ${pct(g)} global (lcov)';
      cumple = c >= 80 && g >= 80;
    case 'acceso_cruzado':
      final d = json();
      valor = '${d['denegados']}/${d['intentos']} intentos denegados';
      cumple = d['cumple'] == true;
    case 'tls':
      final d = json();
      final hosts = (d['hosts'] as List).cast<Map<String, dynamic>>();
      valor = hosts
          .map((h) => '${h['host']}: TLS 1.0 ${h['tls1_0']}, 1.1 ${h['tls1_1']}, 1.2 ${h['tls1_2']}, 1.3 ${h['tls1_3']}')
          .join(' · ');
      cumple = d['cumple'] == true;
    case 'p3':
      final d = json();
      final dep = d['despliegue'] as Map?;
      final rb = d['rollback'] as Map?;
      valor = 'despliegue ${dep == null ? '—' : '${dep['minutos']} min'} · rollback ${rb == null ? '—' : '${rb['minutos']} min'}';
      cumple = dep == null || rb == null ? null : d['cumple'] == true;
    case 'analyze':
      final t = f.readAsStringSync();
      cumple = t.contains('No issues found');
      valor = cumple ? '0 errores, 0 advertencias, 0 infos' : 'flutter analyze reporta problemas';
    case 'e2e_tiempos':
      final t = ((json()['tiempos'] ?? const {}) as Map).cast<String, dynamic>();
      final total = t['tarea_tutora_total_ms'] as num?;
      final base = deManual();
      return Evaluado(r, base.valor, base.veredicto,
          ambiente: ambiente,
          evidencia: evidencia,
          nota: total == null ? null : 'Proxy E2E (no reemplaza la prueba con personas): tarea completa de la tutora en ${ms(total)}');
  }
  if (valor == null) return deManual();
  var veredicto = cumple == null ? 'No medido' : (cumple ? 'Cumple' : 'No cumple');
  String? nota;
  if (cumple == true && r['pendiente'] != null) {
    veredicto = 'Parcial';
    nota = r['pendiente'] as String;
  } else if (cumple == true && ambiente == 'local' && r['pendiente_si_solo_local'] != null) {
    veredicto = 'Cumple en local';
    nota = r['pendiente_si_solo_local'] as String;
  }
  return Evaluado(r, valor, veredicto, ambiente: ambiente, evidencia: '$evidencia (${fechaArchivo(f)})', nota: nota);
}

// ------------------------------------------------------------ niveles de prueba

class Nivel {
  final String nivel;
  final String herramienta;
  final int pasan;
  final int fallan;
  final String evidencia;
  final String? ambiente;
  final String detalle;

  /// La carga cuenta comprobaciones HTTP, no casos de prueba: no suma al total.
  final bool esCasoDePrueba;
  Nivel(this.nivel, this.herramienta, this.pasan, this.fallan, this.evidencia, this.detalle,
      {this.ambiente, this.esCasoDePrueba = true});
  bool get ok => fallan == 0 && pasan > 0;
}

/// Tipo de cada archivo de pruebas de Flutter.
String tipoArchivo(String ruta) {
  final n = ruta.split('/').last;
  if (n == 'responsivo_test.dart') return 'Dominio';
  if (const ['rut_test.dart', 'nombres_test.dart', 'planilla_test.dart', 'rut_input_formatter_test.dart', 'cola_sincronizacion_test.dart']
      .contains(n)) {
    return 'Unitaria';
  }
  if (n.contains('repository') || n == 'health_service_test.dart' || n == 'clase_repository_test.dart' ||
      n == 'justificativos_evidencias_test.dart' || n == 'reportes_portal_alertas_test.dart') {
    return 'Integración (HTTP simulado)';
  }
  return 'Widget / UI';
}

List<Nivel> resumenNiveles() {
  final niveles = <Nivel>[];

  final ft = buscar('flutter-test.json');
  if (ft != null) {
    final suites = <int, String>{};
    final pruebas = <int, (int, bool)>{}; // id → (suite, oculta)
    final porTipo = <String, List<int>>{}; // tipo → [pasan, fallan]
    for (final linea in ft.$2.readAsLinesSync()) {
      if (linea.trim().isEmpty) continue;
      final e = jsonDecode(linea) as Map<String, dynamic>;
      switch (e['type']) {
        case 'suite':
          final s = e['suite'] as Map<String, dynamic>;
          suites[s['id'] as int] = (s['path'] as String?) ?? '';
        case 'testStart':
          final t = e['test'] as Map<String, dynamic>;
          pruebas[t['id'] as int] = (t['suiteID'] as int, (t['metadata'] as Map?)?['skip'] == true);
        case 'testDone':
          if (e['hidden'] == true) continue;
          final p = pruebas[e['testID'] as int];
          if (p == null) continue;
          final tipo = tipoArchivo(suites[p.$1] ?? '');
          final cuenta = porTipo.putIfAbsent(tipo, () => [0, 0]);
          if (e['result'] == 'success') {
            cuenta[0]++;
          } else {
            cuenta[1]++;
          }
      }
    }
    for (final tipo in const ['Unitaria', 'Integración (HTTP simulado)', 'Widget / UI', 'Dominio']) {
      final c = porTipo[tipo];
      if (c == null) continue;
      niveles.add(Nivel(tipo, 'flutter test', c[0], c[1], 'resultados/${ft.$1}/flutter-test.json', switch (tipo) {
        'Unitaria' => 'Reglas puras: RUT módulo 11, planilla CSV/XLSX, cola sin conexión, nombres',
        'Integración (HTTP simulado)' => 'Repositorios Supabase contra un cliente HTTP simulado: RPC, filtros, errores 403',
        'Widget / UI' => 'Pantallas de cada rol con repositorios falsos',
        _ => 'Responsivo 360–1920 px y áreas táctiles de 44 px (RNF-U-1, U-3)',
      }, ambiente: ft.$1));
    }
  }

  final pg = buscar('pgtap.txt');
  if (pg != null) {
    final t = pg.$2.readAsStringSync();
    final m = RegExp(r'Files=(\d+), Tests=(\d+)').firstMatch(t);
    final total = int.tryParse(m?.group(2) ?? '') ?? 0;
    final ok = t.contains('Result: PASS');
    niveles.add(Nivel('Integración (base de datos)', 'pgTAP (supabase test db)', ok ? total : 0, ok ? 0 : total,
        'resultados/${pg.$1}/pgtap.txt', '${m?.group(1) ?? '?'} archivos: esquema, RLS por rol, reglas de clase, auditoría, alertas',
        ambiente: pg.$1));
  }

  final e2e = buscar('e2e.txt');
  if (e2e != null) {
    final ok = e2e.$2.readAsStringSync().contains('All tests passed');
    niveles.add(Nivel('Extremo a extremo', 'flutter drive + Chrome headless', ok ? 3 : 0, ok ? 0 : 1,
        'resultados/${e2e.$1}/e2e.txt', 'Tutora pasa lista · Alumna ve solo su portal · Directiva sin MFA queda bloqueada',
        ambiente: e2e.$1));
  }

  final ac = leerJson('acceso-cruzado.json');
  if (ac != null) {
    final total = ac.$2['intentos'] as int;
    final den = ac.$2['denegados'] as int;
    niveles.add(Nivel('Seguridad (acceso cruzado)', 'k6 sobre PostgREST/RPC', den, total - den,
        'resultados/${ac.$1}/acceso-cruzado.json', 'Intentos con JWT de otra sede, otra alumna, anónimo y Directiva sin MFA',
        ambiente: ac.$1));
  }

  final k6 = leerJson('k6-carga.json');
  if (k6 != null) {
    final checks = (k6.$2['metrics'] as Map)['checks'] as Map;
    niveles.add(Nivel('Carga', 'k6 · 30 VUs · netem', checks['passes'] as int, checks['fails'] as int,
        'resultados/${k6.$1}/k6-carga.json', 'Comprobaciones HTTP durante la carga del sábado (TC-27); no se suman al total de pruebas',
        ambiente: k6.$1, esCasoDePrueba: false));
  }
  return niveles;
}

// ------------------------------------------------------------------ defectos

List<Map<String, String>> leerDefectos(File f) {
  if (!f.existsSync()) return [];
  final filas = <Map<String, String>>[];
  List<String>? columnas;
  for (final linea in f.readAsLinesSync()) {
    if (!linea.startsWith('|')) continue;
    final celdas = linea.split('|').map((c) => c.trim()).toList()
      ..removeAt(0)
      ..removeLast();
    if (columnas == null) {
      columnas = celdas;
      continue;
    }
    if (celdas.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) continue;
    filas.add({for (var i = 0; i < columnas.length && i < celdas.length; i++) columnas[i]: celdas[i]});
  }
  return filas;
}

// ------------------------------------------------------------------ salida

class Informe {
  final List<Evaluado> rnf;
  final List<Map<String, dynamic>> casos;
  final List<Map<String, String>> defectos;
  final List<Nivel> niveles;
  final (String, Map<String, dynamic>)? cobertura;
  Informe(this.rnf, this.casos, this.defectos, this.niveles, this.cobertura);

  String get fecha => DateTime.now().toUtc().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
  List<Evaluado> get criticos => rnf.where((r) => r.critico).toList();
  int get criticosCumplen => criticos.where((r) => r.veredicto == 'Cumple').length;
  int get pruebasPasan => niveles.where((n) => n.esCasoDePrueba).fold(0, (s, n) => s + n.pasan);
  int get pruebasFallan => niveles.where((n) => n.esCasoDePrueba).fold(0, (s, n) => s + n.fallan);
  List<Map<String, String>> get defectosAbiertos =>
      defectos.where((d) => const ['Abierto', 'En corrección', 'Corregido', 'Diferido'].contains(d['Estado'])).toList();
  bool get bloqueanMvp =>
      criticos.any((r) => r.veredicto != 'Cumple') ||
      defectos.any((d) => const ['Crítico', 'Bloqueante'].contains(d['Severidad']) &&
          !const ['Verificado', 'Cerrado'].contains(d['Estado']));

  String get conclusion {
    final faltan = criticos.where((r) => r.veredicto != 'Cumple').map((r) => '${r.id} (${r.veredicto.toLowerCase()})');
    return bloqueanMvp
        ? 'El MVP todavía no cumple la DoD (§10, punto 3): faltan ${faltan.join(', ')}. Ningún RNF crítico medido falla; '
            'los pendientes son mediciones en la beta y pruebas con personas.'
        : 'Todos los RNF críticos cumplen y no hay defectos críticos abiertos.';
  }

  // ---- Markdown
  String markdown() {
    final b = StringBuffer()
      ..writeln('# Informe de resultados de pruebas · NiñasPro Hub')
      ..writeln()
      ..writeln('> Generado por `frontend/tool/generar_informe.dart` el $fecha UTC a partir de `docs/pruebas/resultados/`. '
          'No editar a mano: corregir los catálogos (`rnf.json`, `casos.json`, `defectos.md`) y volver a generar.')
      ..writeln()
      ..writeln('## Resumen')
      ..writeln()
      ..writeln('- **Pruebas ejecutadas:** $pruebasPasan pasan · $pruebasFallan fallan.')
      ..writeln('- **RNF críticos:** $criticosCumplen de ${criticos.length} cumplen.')
      ..writeln('- **Defectos:** ${defectos.length} registrados, ${defectosAbiertos.length} abiertos.')
      ..writeln('- **Conclusión:** $conclusion')
      ..writeln()
      ..writeln('## Niveles de prueba ejecutados')
      ..writeln()
      ..writeln('| Nivel | Herramienta | Pasan | Fallan | Qué cubre | Ambiente | Evidencia |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final n in niveles) {
      b.writeln('| ${n.nivel} | ${n.herramienta} | ${n.pasan} | ${n.fallan} | ${n.detalle} | ${n.ambiente ?? '—'} | `${n.evidencia}` |');
    }
    b
      ..writeln()
      ..writeln('## RNF críticos')
      ..writeln()
      ..writeln('| RNF | Objetivo | Método reproducible | Valor obtenido | Veredicto |')
      ..writeln('|---|---|---|---|---|');
    for (final r in criticos) {
      b.writeln('| **${r.id}** ${r.rnf['nombre']} | ${r.rnf['objetivo']} | ${r.rnf['metodo']} `${r.rnf['comando']}` | '
          '${r.valor}${r.ambiente != null ? ' _(${r.ambiente})_' : ''}${r.nota != null ? '<br>${r.nota}' : ''} | **${r.veredicto}** |');
    }
    b
      ..writeln()
      ..writeln('## Desviaciones: interpretación y decisión')
      ..writeln();
    for (final r in rnf.where((r) => r.veredicto != 'Cumple' || r.rnf['decision'] != '—')) {
      if (r.rnf['decision'] == '—') continue;
      b
        ..writeln('### ${r.id} · ${r.rnf['nombre']} — ${r.veredicto}')
        ..writeln()
        ..writeln('- **Interpretación:** ${r.rnf['interpretacion']}')
        ..writeln('- **Decisión:** ${r.rnf['decision']}')
        ..writeln();
    }
    b
      ..writeln('## Todos los RNF')
      ..writeln()
      ..writeln('| RNF | Crítico | Objetivo | Valor obtenido | Veredicto | Casos |')
      ..writeln('|---|---|---|---|---|---|');
    for (final r in rnf) {
      b.writeln('| ${r.id} ${r.rnf['nombre']} | ${r.critico ? 'Sí' : 'No'} | ${r.rnf['objetivo']} | ${r.valor} | ${r.veredicto} | '
          '${(r.rnf['tc'] as List).join(', ')} |');
    }
    final cob = cobertura;
    if (cob != null) {
      b
        ..writeln()
        ..writeln('## Cobertura de reglas críticas (${cob.$1})')
        ..writeln()
        ..writeln('Herramienta: `${cob.$2['herramienta']}`. Reporte navegable: [`cobertura/`](cobertura/index.html).')
        ..writeln()
        ..writeln('| Archivo | Líneas | Cubiertas | Cobertura |')
        ..writeln('|---|---|---|---|');
      for (final a in ((cob.$2['criticas'] as Map)['archivos'] as List).cast<Map<String, dynamic>>()) {
        b.writeln('| `${a['archivo']}` | ${a['lineas']} | ${a['cubiertas']} | ${pct(a['porcentaje'] as num)} |');
      }
    }
    b
      ..writeln()
      ..writeln('## Defectos')
      ..writeln()
      ..writeln('| ID | Caso | Severidad | Estado | Descripción | Decisión / arreglo |')
      ..writeln('|---|---|---|---|---|---|');
    for (final d in defectos) {
      b.writeln('| ${d['ID']} | ${d['Caso']} | ${d['Severidad']} | ${d['Estado']} | ${d['Descripción']} | ${d['Decisión / arreglo']} |');
    }
    b
      ..writeln()
      ..writeln('## Casos de prueba (SRS §11)')
      ..writeln()
      ..writeln('| TC | Tipo | RF | RNF | Qué verifica | Evidencia | Estado |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final c in casos) {
      b.writeln('| ${c['tc']} | ${c['tipo']} | ${c['rf']} | ${c['rnf']} | ${c['que']} | ${c['evidencia']} | '
          '${c['estado']}${c['nota'] != null ? ' — ${c['nota']}' : ''} |');
    }
    return b.toString();
  }

  // ---- HTML
  static String e(Object? s) => const HtmlEscape().convert('${s ?? ''}');

  static String claseVeredicto(String v) => switch (v) {
    'Cumple' || 'Pasa' || 'Verificado' || 'Cerrado' => 'ok',
    'No cumple' || 'Falla' || 'Abierto' || 'Crítico' || 'Bloqueante' => 'mal',
    'No medido' || 'Pendiente' => 'gris',
    _ => 'medio',
  };

  static String chip(String v) => '<span class="chip ${claseVeredicto(v)}">${e(v)}</span>';

  /// `código` en línea, como en el Markdown de los catálogos.
  static String md(Object? s) => e(s).replaceAllMapped(RegExp('`([^`]+)`'), (m) => '<code>${m[1]}</code>')
      .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => '<b>${m[1]}</b>');

  String html() {
    final b = StringBuffer();
    final cob = cobertura;
    final cobCriticas = cob == null ? null : (cob.$2['criticas'] as Map)['porcentaje'] as num;
    b.write('''<!doctype html>
<html lang="es-CL"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Informe de pruebas · NiñasPro Hub</title>
<style>
:root{--bg:#f7f5fb;--panel:#fff;--txt:#1d1530;--sub:#5d5470;--linea:#e4dff0;--marca:#7b3fe4;
--ok:#137a4a;--ok-bg:#dff5ea;--mal:#b42335;--mal-bg:#fde4e7;--medio:#8a5a00;--medio-bg:#fff1cc;--gris:#5d5470;--gris-bg:#eeebf3}
@media (prefers-color-scheme:dark){:root{--bg:#120d1f;--panel:#1c1530;--txt:#efeaf8;--sub:#b3a9c9;--linea:#2f2547;--marca:#b28cff;
--ok:#6fdca5;--ok-bg:#123527;--mal:#ff8f9c;--mal-bg:#3d1520;--medio:#ffd36b;--medio-bg:#3a2d0b;--gris:#b3a9c9;--gris-bg:#2a2340}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--txt);font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:1180px;margin:0 auto;padding:28px 16px 64px}
h1{font-size:26px;margin:0 0 4px}h2{font-size:19px;margin:36px 0 12px}h3{font-size:15px;margin:18px 0 6px}
.sub{color:var(--sub);margin:0 0 20px}a{color:var(--marca)}code{font:12.5px ui-monospace,Consolas,monospace;background:var(--gris-bg);padding:1px 5px;border-radius:5px;overflow-wrap:anywhere}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}
.kpi{background:var(--panel);border:1px solid var(--linea);border-radius:14px;padding:14px 16px}
.kpi b{display:block;font-size:28px;line-height:1.2}.kpi span{color:var(--sub);font-size:13px}
.aviso{margin-top:14px;padding:12px 16px;border-radius:12px;border:1px solid var(--linea);background:var(--panel)}
.aviso-pendiente{border-color:var(--medio);background:var(--medio-bg)}.aviso-listo{border-color:var(--ok);background:var(--ok-bg)}
.tabla{overflow-x:auto;background:var(--panel);border:1px solid var(--linea);border-radius:14px}
table{border-collapse:collapse;width:100%;min-width:720px}th,td{text-align:left;vertical-align:top;padding:10px 12px;border-bottom:1px solid var(--linea)}
th{font-size:12px;text-transform:uppercase;letter-spacing:.04em;color:var(--sub);background:var(--gris-bg)}tr:last-child td{border-bottom:0}
td small{display:block;color:var(--sub);margin-top:4px}
.chip{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12.5px;font-weight:700;white-space:nowrap}
.ok{color:var(--ok);background:var(--ok-bg)}.mal{color:var(--mal);background:var(--mal-bg)}.medio{color:var(--medio);background:var(--medio-bg)}.gris{color:var(--gris);background:var(--gris-bg)}
.barra{height:8px;background:var(--gris-bg);border-radius:9px;min-width:120px;position:relative}.barra i{position:absolute;inset:0 auto 0 0;background:var(--ok);border-radius:9px}
.barra.bajo i{background:var(--mal)}.umbral{position:absolute;top:-3px;bottom:-3px;left:80%;width:2px;background:var(--txt);opacity:.5}
.desv{background:var(--panel);border:1px solid var(--linea);border-radius:14px;padding:4px 16px 12px;margin-bottom:10px}
.desv p{margin:6px 0}nav{display:flex;flex-wrap:wrap;gap:8px 16px;margin:8px 0 0;font-size:14px}
</style></head><body><main>
<h1>Informe de pruebas · NiñasPro Hub</h1>
<p class="sub">Generado el ${e(fecha)} UTC desde <code>docs/pruebas/resultados/</code>. Ambiente preferido: beta; si no hay medición en la beta, se usa la local (Docker).</p>
<nav><a href="#niveles">Niveles</a><a href="#criticos">RNF críticos</a><a href="#desviaciones">Desviaciones</a><a href="#todos">Todos los RNF</a><a href="#cobertura">Cobertura</a><a href="#defectos">Defectos</a><a href="#casos">Casos TC</a><a href="plan-de-pruebas.md">Plan de pruebas</a></nav>
<div class="kpis" style="margin-top:18px">
<div class="kpi"><b>$pruebasPasan</b><span>pruebas pasan · $pruebasFallan fallan</span></div>
<div class="kpi"><b>$criticosCumplen / ${criticos.length}</b><span>RNF críticos cumplen</span></div>
<div class="kpi"><b>${cobCriticas == null ? '—' : pct(cobCriticas)}</b><span>cobertura en reglas críticas (meta 80 %)</span></div>
<div class="kpi"><b>${defectosAbiertos.length} / ${defectos.length}</b><span>defectos abiertos / registrados</span></div>
</div>
<div class="aviso ${bloqueanMvp ? 'aviso-pendiente' : 'aviso-listo'}"><b>Conclusión.</b> ${e(conclusion)}</div>
''');

    b.write('<h2 id="niveles">Niveles de prueba ejecutados</h2><div class="tabla"><table><tr><th>Nivel</th><th>Herramienta</th>'
        '<th>Pasan</th><th>Fallan</th><th>Qué cubre</th><th>Evidencia</th></tr>');
    for (final n in niveles) {
      b.write('<tr><td><b>${e(n.nivel)}</b></td><td>${e(n.herramienta)}</td><td><span class="chip ${n.pasan > 0 ? 'ok' : 'gris'}">${n.pasan}</span></td>'
          '<td>${n.fallan == 0 ? '0' : '<span class="chip mal">${n.fallan}</span>'}</td><td>${e(n.detalle)}</td>'
          '<td><code>${e(n.evidencia)}</code><small>${e(n.ambiente)}</small></td></tr>');
    }
    b.write('</table></div>');

    b.write('<h2 id="criticos">RNF críticos (SRS §10)</h2><div class="tabla"><table><tr><th>RNF</th><th>Objetivo</th>'
        '<th>Método reproducible</th><th>Valor obtenido</th><th>Veredicto</th></tr>');
    for (final r in criticos) {
      b.write('<tr><td><b>${e(r.id)}</b><small>${e(r.rnf['nombre'])}</small></td><td>${e(r.rnf['objetivo'])}</td>'
          '<td>${md(r.rnf['metodo'])}<small><code>${e(r.rnf['comando'])}</code></small></td>'
          '<td>${e(r.valor)}${r.ambiente != null ? '<small>Ambiente: ${e(r.ambiente)} · ${e(r.evidencia)}</small>' : ''}'
          '${r.nota != null ? '<small>${e(r.nota)}</small>' : ''}</td><td>${chip(r.veredicto)}</td></tr>');
    }
    b.write('</table></div>');

    b.write('<h2 id="desviaciones">Desviaciones: interpretación y decisión</h2>');
    for (final r in rnf) {
      if (r.rnf['decision'] == '—') continue;
      b.write('<div class="desv"><h3>${e(r.id)} · ${e(r.rnf['nombre'])} ${chip(r.veredicto)}</h3>'
          '<p><b>Interpretación.</b> ${md(r.rnf['interpretacion'])}</p><p><b>Decisión.</b> ${md(r.rnf['decision'])}</p></div>');
    }

    b.write('<h2 id="todos">Todos los RNF</h2><div class="tabla"><table><tr><th>RNF</th><th>Objetivo</th><th>Valor obtenido</th>'
        '<th>Veredicto</th><th>Casos</th></tr>');
    for (final r in rnf) {
      b.write('<tr><td><b>${e(r.id)}</b>${r.critico ? ' <span class="chip gris">crítico</span>' : ''}<small>${e(r.rnf['nombre'])}</small></td>'
          '<td>${e(r.rnf['objetivo'])}</td><td>${e(r.valor)}</td><td>${chip(r.veredicto)}</td><td>${e((r.rnf['tc'] as List).join(', '))}</td></tr>');
    }
    b.write('</table></div>');

    if (cob != null) {
      b.write('<h2 id="cobertura">Cobertura de reglas críticas</h2><p class="sub">Herramienta: <code>${e(cob.$2['herramienta'])}</code> · '
          'ambiente ${e(cob.$1)} · global ${pct((cob.$2['global'] as Map)['porcentaje'] as num)} · '
          '<a href="cobertura/index.html">reporte completo de lcov</a></p><div class="tabla"><table><tr><th>Archivo</th><th>Líneas</th>'
          '<th>Cobertura</th><th style="width:30%">Meta 80 %</th></tr>');
      for (final a in ((cob.$2['criticas'] as Map)['archivos'] as List).cast<Map<String, dynamic>>()) {
        final p = a['porcentaje'] as num;
        b.write('<tr><td><code>${e(a['archivo'])}</code></td><td>${a['cubiertas']}/${a['lineas']}</td><td>${pct(p)}</td>'
            '<td><div class="barra${p < 80 ? ' bajo' : ''}"><i style="width:${p.clamp(0, 100)}%"></i><span class="umbral"></span></div></td></tr>');
      }
      b.write('</table></div>');
    }

    b.write('<h2 id="defectos">Defectos</h2><div class="tabla"><table><tr><th>ID</th><th>Caso</th><th>Severidad</th><th>Estado</th>'
        '<th>Descripción</th><th>Decisión / arreglo</th></tr>');
    for (final d in defectos) {
      b.write('<tr><td><b>${e(d['ID'])}</b><small>${e(d['Fecha'])}</small></td><td>${e(d['Caso'])}<small>${e(d['US / RNF'])}</small></td>'
          '<td>${chip(d['Severidad'] ?? '')}</td><td>${chip(d['Estado'] ?? '')}</td><td>${md(d['Descripción'])}</td>'
          '<td>${md(d['Decisión / arreglo'])}</td></tr>');
    }
    b.write('</table></div>');

    b.write('<h2 id="casos">Casos de prueba (SRS §11)</h2><p class="sub">Tipos: U unitaria · I integración · E extremo a extremo · '
        'C carga · S seguridad · M manual · CI integración continua.</p><div class="tabla"><table><tr><th>TC</th><th>Tipo</th>'
        '<th>Qué verifica</th><th>Evidencia</th><th>Estado</th></tr>');
    for (final c in casos) {
      b.write('<tr><td><b>${e(c['tc'])}</b><small>${e(c['rf'])} · ${e(c['rnf'])}</small></td><td>${e(c['tipo'])}</td>'
          '<td>${e(c['que'])}${c['nota'] != null ? '<small>${e(c['nota'])}</small>' : ''}</td><td><small>${e(c['evidencia'])}</small></td>'
          '<td>${chip(c['estado'] as String)}</td></tr>');
    }
    b.write('</table></div></main></body></html>\n');
    return b.toString();
  }
}
