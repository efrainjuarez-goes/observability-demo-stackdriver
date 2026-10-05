#!/usr/bin/env bash
# Copia este archivo a vars.sh, pon tus valores y cargalo con:
#   source vars.sh
#
# IMPORTANTE: usa valores LITERALES, nunca generados con $(date) ni similares.
# Un ID generado al vuelo cambia entre pestanas de terminal y los comandos
# acabarian apuntando a proyectos distintos.

# --- Proyectos ---
export PROY_A="gcp-app-demo"          # proyecto con la carga de trabajo
export PROY_B="gcp-obs-demo"          # proyecto de observabilidad

# --- Region ---
export REGION="us-central1"
export ZONA="us-central1-a"

# --- Recursos ---
export SVC_RUN="app-demo"
export SQL_INSTANCE="demo-pg"
export VM_ALLOY="vm-alloy"
export SA_ALLOY="sa-alloy-exporter"

# --- Derivadas (no editar) ---
export SA_EMAIL="${SA_ALLOY}@${PROY_B}.iam.gserviceaccount.com"
export CONN_NAME="${PROY_A}:${REGION}:${SQL_INSTANCE}"

# --- Facturacion ---
# Obtenlo con: gcloud billing accounts list
export BILLING_ID="XXXXXX-XXXXXX-XXXXXX"

# --- Grafana Cloud ---
# Connections -> Hosted Prometheus metrics en tu stack
export GC_URL="https://prometheus-prod-NN-prod-REGION.grafana.net/api/prom/push"
export GC_USER="1234567"
export GC_TOKEN="glc_pega_aqui_tu_token"

echo "Variables cargadas: A=$PROY_A B=$PROY_B region=$REGION"
