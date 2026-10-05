#!/usr/bin/env bash
# Borra todos los recursos. El load balancer va en orden inverso al de creacion.
set -uo pipefail

echo "Esto borrara TODOS los recursos de la demo."
read -r -p "Escribe BORRAR para confirmar: " confirma
[ "$confirma" != "BORRAR" ] && { echo "Cancelado."; exit 0; }

echo "==> Load balancer"
gcloud compute forwarding-rules      delete fr-app-demo    --global --project="$PROY_A" --quiet
gcloud compute target-http-proxies   delete proxy-app-demo          --project="$PROY_A" --quiet
gcloud compute url-maps              delete um-app-demo             --project="$PROY_A" --quiet
gcloud compute backend-services      delete bs-app-demo    --global --project="$PROY_A" --quiet
gcloud compute network-endpoint-groups delete neg-app-demo --region="$REGION" --project="$PROY_A" --quiet
gcloud compute addresses             delete ip-app-demo    --global --project="$PROY_A" --quiet

echo "==> Cloud Run y Cloud SQL"
gcloud run services   delete "$SVC_RUN"      --region="$REGION" --project="$PROY_A" --quiet
gcloud sql instances  delete "$SQL_INSTANCE"                    --project="$PROY_A" --quiet

echo "==> VM y firewall"
gcloud compute instances       delete "$VM_ALLOY" --zone="$ZONA" --project="$PROY_B" --quiet
gcloud compute firewall-rules  delete allow-alloy-ui            --project="$PROY_B" --quiet 2>/dev/null || true

echo
echo "==> Verificando que no quede nada cobrando"
gcloud compute forwarding-rules list --project="$PROY_A"
gcloud compute addresses        list --project="$PROY_A"
gcloud sql instances            list --project="$PROY_A"
gcloud compute instances        list --project="$PROY_B"

echo
echo "No olvides revocar el token de Grafana Cloud."
