#!/usr/bin/env bash
# Crea los dos proyectos, los liga a facturacion y habilita las APIs.
set -euo pipefail

echo "==> Creando proyectos"
gcloud projects create "$PROY_A" --name="Demo app GCP"        2>/dev/null || echo "    $PROY_A ya existe"
gcloud projects create "$PROY_B" --name="Demo observabilidad" 2>/dev/null || echo "    $PROY_B ya existe"

echo "==> Ligando facturacion"
gcloud billing projects link "$PROY_A" --billing-account="$BILLING_ID"
gcloud billing projects link "$PROY_B" --billing-account="$BILLING_ID"

echo "==> Habilitando APIs en $PROY_A"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  monitoring.googleapis.com \
  --project="$PROY_A"

echo "==> Habilitando APIs en $PROY_B"
gcloud services enable \
  compute.googleapis.com \
  monitoring.googleapis.com \
  iam.googleapis.com \
  --project="$PROY_B"

echo "==> Fijando el proyecto activo"
gcloud config set project "$PROY_A"

echo "Listo. Las APIs pueden tardar 1-2 min en estar disponibles."
