#!/usr/bin/env bash
# Genera trafico contra el load balancer para que las metricas
# tengan forma en lugar de ser lineas planas.
# Uso: ./carga.sh <ip-del-lb>
set -euo pipefail

LB_IP="${1:-${LB_IP:-}}"
[ -z "$LB_IP" ] && { echo "uso: ./carga.sh <ip-del-lb>"; exit 1; }

echo "Generando trafico contra http://${LB_IP}  (Ctrl+C para detener)"
while true; do
  curl -s -o /dev/null "http://${LB_IP}/"
  curl -s -o /dev/null "http://${LB_IP}/db"

  # 1 de cada 5 al endpoint lento
  [ $((RANDOM % 5)) -eq 0 ] && curl -s -o /dev/null "http://${LB_IP}/slow" &

  # 1 de cada 10 genera un 500
  [ $((RANDOM % 10)) -eq 0 ] && curl -s -o /dev/null "http://${LB_IP}/error"

  sleep 1
done
