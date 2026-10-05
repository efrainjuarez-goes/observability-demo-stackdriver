#!/usr/bin/env bash
# Crea la service account en el proyecto B y le da lectura de metricas
# sobre el proyecto A. Este paso sustituye a la VPN.
set -euo pipefail

echo "==> Creando service account en $PROY_B"
gcloud iam service-accounts create "$SA_ALLOY" \
  --project="$PROY_B" \
  --display-name="Alloy GCP exporter" 2>/dev/null || echo "    ya existe"

echo "==> Permiso cruzado: $SA_EMAIL puede leer metricas de $PROY_A"
gcloud projects add-iam-policy-binding "$PROY_A" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.viewer" \
  --condition=None >/dev/null

echo "==> Permiso sobre su propio proyecto"
gcloud projects add-iam-policy-binding "$PROY_B" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.viewer" \
  --condition=None >/dev/null

echo
echo "==> Verificando"
gcloud projects get-iam-policy "$PROY_A" \
  --flatten="bindings[].members" \
  --filter="bindings.members:${SA_EMAIL}" \
  --format="table(bindings.role)"
