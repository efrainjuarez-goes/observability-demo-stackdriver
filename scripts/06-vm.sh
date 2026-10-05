#!/usr/bin/env bash
# Crea la VM que correra Alloy, con la service account adjunta.
set -euo pipefail

echo "==> Creando VM $VM_ALLOY"
gcloud compute instances create "$VM_ALLOY" \
  --project="$PROY_B" \
  --zone="$ZONA" \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB \
  --service-account="$SA_EMAIL" \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=alloy 2>/dev/null || echo "    la VM ya existe"

echo
echo "VM creada. Para entrar:"
echo "  gcloud compute ssh $VM_ALLOY --zone=$ZONA --project=$PROY_B"
echo
echo "Para ver la UI de Alloy sin abrir el firewall (recomendado):"
echo "  gcloud compute ssh $VM_ALLOY --zone=$ZONA --project=$PROY_B -- -N -L 12345:localhost:12345"
echo "  y abre http://localhost:12345"
