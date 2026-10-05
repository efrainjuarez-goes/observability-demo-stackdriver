#!/usr/bin/env bash
# Despliega la app en Cloud Run y la conecta a Cloud SQL.
set -euo pipefail

: "${SQL_PASS:?Define SQL_PASS primero}"

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Desplegando desde $raiz/app"
cd "$raiz/app"

gcloud run deploy "$SVC_RUN" \
  --source . \
  --region="$REGION" \
  --project="$PROY_A" \
  --allow-unauthenticated \
  --min-instances=1 \
  --max-instances=3 \
  --cpu=1 \
  --memory=512Mi \
  --add-cloudsql-instances="$CONN_NAME" \
  --set-env-vars="INSTANCE_CONNECTION_NAME=${CONN_NAME},DB_USER=postgres,DB_PASS=${SQL_PASS},DB_NAME=demo"

RUN_URL="$(gcloud run services describe "$SVC_RUN" \
  --region="$REGION" --project="$PROY_A" --format='value(status.url)')"

echo
echo "==> Verificando"
echo "    URL: $RUN_URL"
curl -s "$RUN_URL/"   && echo
curl -s "$RUN_URL/db" && echo

echo
echo "Guarda la URL:  export RUN_URL=\"$RUN_URL\""
