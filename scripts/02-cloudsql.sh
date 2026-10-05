#!/usr/bin/env bash
# Crea la instancia de Cloud SQL. Tarda entre 5 y 10 minutos.
# Lanzalo temprano y sigue con el resto mientras termina.
set -euo pipefail

: "${SQL_PASS:?Define SQL_PASS primero. Ej: export SQL_PASS=\"\$(openssl rand -base64 18)\"}"

echo "==> Creando instancia $SQL_INSTANCE (esto tarda varios minutos)"
gcloud sql instances create "$SQL_INSTANCE" \
  --project="$PROY_A" \
  --database-version=POSTGRES_15 \
  --edition=ENTERPRISE \
  --tier=db-f1-micro \
  --region="$REGION" \
  --storage-size=10GB \
  --storage-type=HDD \
  --no-backup 2>/dev/null || echo "    la instancia ya existe"

echo "==> Configurando usuario y base"
gcloud sql users set-password postgres \
  --instance="$SQL_INSTANCE" --project="$PROY_A" --password="$SQL_PASS"

gcloud sql databases create demo \
  --instance="$SQL_INSTANCE" --project="$PROY_A" 2>/dev/null || echo "    la base ya existe"

echo
echo "Listo. La tabla la crea la aplicacion al arrancar; no hace falta psql."
