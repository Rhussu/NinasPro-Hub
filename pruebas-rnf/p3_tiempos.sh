#!/usr/bin/env bash
# TC-42 · RNF-P-3: despliegue ≤ 10 min y rollback ≤ 5 min.
#
# Uso: bash pruebas-rnf/p3_tiempos.sh [rama=premain] [workflow=cd-frontend.yml] > resultados/p3.json
# Requiere `gh` autenticado (o GH_TOKEN en Actions).
#
# Método: 1) se hace un commit a la rama y se espera su despliegue; 2) se revierte
# con `git revert` y se espera el despliegue del revert. Este script lee los runs
# del workflow de despliegue en la rama y mide, para cada uno, desde que se creó
# hasta que terminó (lo que tarda en quedar publicada la versión). El último run
# cuyo commit empieza con "Revert" es el rollback; el último que no, el despliegue.
set -euo pipefail
RAMA="${1:-premain}"
WF="${2:-cd-frontend.yml}"

gh run list --workflow "$WF" --branch "$RAMA" --limit 30 \
  --json databaseId,displayTitle,headSha,createdAt,updatedAt,conclusion,status,event,url |
node -e '
  const runs = JSON.parse(require("fs").readFileSync(0, "utf8"))
    .filter((r) => r.status === "completed")
    .map((r) => ({ ...r, minutos: +((new Date(r.updatedAt) - new Date(r.createdAt)) / 60000).toFixed(2) }));
  const ok = runs.filter((r) => r.conclusion === "success");
  const rollback = ok.find((r) => /^Revert/.test(r.displayTitle));
  const despliegue = ok.find((r) => !/^Revert/.test(r.displayTitle));
  const cumpleD = !!despliegue && despliegue.minutos <= 10;
  const cumpleR = !!rollback && rollback.minutos <= 5;
  const max = ok.length ? Math.max(...ok.map((r) => r.minutos)) : null;
  console.log(JSON.stringify({
    herramienta: "gh run list (GitHub Actions)",
    rama: process.argv[1], workflow: process.argv[2], fecha: new Date().toISOString(),
    despliegue: despliegue || null, rollback: rollback || null,
    maximo_minutos_exitosos: max, runs_exitosos: ok.length,
    cumple_despliegue: cumpleD, cumple_rollback: cumpleR,
    cumple: cumpleD && cumpleR,
  }, null, 2));
' "$RAMA" "$WF"
