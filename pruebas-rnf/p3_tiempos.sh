#!/usr/bin/env bash
# TC-42 · RNF-P-3: despliegue ≤ 10 min y rollback ≤ 5 min.
#
# Uso: bash pruebas-rnf/p3_tiempos.sh [rama=premain] [workflow=cd-frontend.yml] > resultados/p3.json
# Requiere `gh` autenticado (o GH_TOKEN en Actions).
#
# Método: 1) un commit a la rama; 2) su `git revert`. Para cada commit se mide
# desde que se creó la PRIMERA ejecución del workflow de despliegue hasta que
# terminó la PRIMERA ejecución exitosa: el tiempo real hasta que la versión
# queda publicada, contando reintentos y re-ejecuciones si las hubo.
# El commit más reciente cuyo mensaje empieza con "Revert" es el rollback; el
# más reciente que no, el despliegue.
set -euo pipefail
RAMA="${1:-premain}"
WF="${2:-cd-frontend.yml}"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

RUNS="$(gh run list --workflow "$WF" --branch "$RAMA" --limit 60 \
  --json databaseId,headSha,createdAt,updatedAt,conclusion,status,event,attempt)"

# Mensaje de cada commit (no depende de tener la historia en el checkout)
SHAS="$(printf '%s' "$RUNS" | node -e 'const r=JSON.parse(require("fs").readFileSync(0,"utf8"));console.log([...new Set(r.map(x=>x.headSha))].slice(0,15).join(" "))')"
MENSAJES="{"
primero=1
for sha in $SHAS; do
  msg="$(gh api "repos/$REPO/commits/$sha" --jq '.commit.message | split("\n")[0]' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  [ $primero = 1 ] || MENSAJES+=","
  MENSAJES+="\"$sha\":\"$msg\""
  primero=0
done
MENSAJES+="}"

printf '%s' "$RUNS" | node -e '
  const runs = JSON.parse(require("fs").readFileSync(0, "utf8"));
  const mensajes = JSON.parse(process.argv[3]);
  const porCommit = new Map();
  for (const r of runs) {
    if (!(r.headSha in mensajes)) continue;
    const g = porCommit.get(r.headSha) || { sha: r.headSha.slice(0, 7), mensaje: mensajes[r.headSha], ejecuciones: [] };
    g.ejecuciones.push(r);
    porCommit.set(r.headSha, g);
  }
  const grupos = [...porCommit.values()].map((g) => {
    const inicio = Math.min(...g.ejecuciones.map((r) => +new Date(r.createdAt)));
    const exitos = g.ejecuciones.filter((r) => r.status === "completed" && r.conclusion === "success")
      .map((r) => +new Date(r.updatedAt));
    const fin = exitos.length ? Math.min(...exitos) : null;
    return {
      sha: g.sha, mensaje: g.mensaje,
      inicio: new Date(inicio).toISOString(), publicado: fin ? new Date(fin).toISOString() : null,
      minutos: fin ? +((fin - inicio) / 60000).toFixed(2) : null,
      ejecuciones: g.ejecuciones.length,
      fallidas: g.ejecuciones.filter((r) => r.conclusion === "failure").length,
    };
  }).filter((g) => g.minutos !== null).sort((a, b) => b.inicio.localeCompare(a.inicio));
  const rollback = grupos.find((g) => /^Revert/.test(g.mensaje)) || null;
  const despliegue = grupos.find((g) => !/^Revert/.test(g.mensaje)) || null;
  const cumpleD = !!despliegue && despliegue.minutos <= 10;
  const cumpleR = !!rollback && rollback.minutos <= 5;
  console.log(JSON.stringify({
    herramienta: "gh run list (GitHub Actions)", rama: process.argv[1], workflow: process.argv[2],
    fecha: new Date().toISOString(), despliegue, rollback,
    cumple_despliegue: cumpleD, cumple_rollback: cumpleR, cumple: cumpleD && cumpleR,
    historial: grupos.slice(0, 8),
  }, null, 2));
' "$RAMA" "$WF" "$MENSAJES"
