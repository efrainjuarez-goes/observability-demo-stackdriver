#!/usr/bin/env bash
# Monta el load balancer HTTP externo con serverless NEG.
# Son seis recursos encadenados; el orden importa.
set -euo pipefail

echo "==> 1/6 Serverless NEG"
gcloud compute network-endpoint-groups create neg-app-demo \
  --project="$PROY_A" --region="$REGION" \
  --network-endpoint-type=serverless \
  --cloud-run-service="$SVC_RUN" 2>/dev/null || echo "    ya existe"

echo "==> 2/6 Backend service"
gcloud compute backend-services create bs-app-demo \
  --project="$PROY_A" --global \
  --load-balancing-scheme=EXTERNAL_MANAGED 2>/dev/null || echo "    ya existe"

echo "==> 3/6 Enganchando NEG al backend"
gcloud compute backend-services add-backend bs-app-demo \
  --project="$PROY_A" --global \
  --network-endpoint-group=neg-app-demo \
  --network-endpoint-group-region="$REGION" 2>/dev/null || echo "    ya enganchado"

echo "==> 4/6 URL map"
gcloud compute url-maps create um-app-demo \
  --project="$PROY_A" --default-service=bs-app-demo 2>/dev/null || echo "    ya existe"

echo "==> 5/6 Target HTTP proxy"
gcloud compute target-http-proxies create proxy-app-demo \
  --project="$PROY_A" --url-map=um-app-demo 2>/dev/null || echo "    ya existe"

echo "==> 6/6 IP estatica y regla de forwarding"
gcloud compute addresses create ip-app-demo \
  --project="$PROY_A" --global --ip-version=IPV4 2>/dev/null || echo "    ya existe"

gcloud compute forwarding-rules create fr-app-demo \
  --project="$PROY_A" --global \
  --target-http-proxy=proxy-app-demo \
  --ports=80 \
  --address=ip-app-demo \
  --load-balancing-scheme=EXTERNAL_MANAGED 2>/dev/null || echo "    ya existe"

LB_IP="$(gcloud compute addresses describe ip-app-demo \
  --global --project="$PROY_A" --format='value(address)')"

echo
echo "IP del load balancer: $LB_IP"
echo "Guardala: export LB_IP=\"$LB_IP\""
echo
echo "La propagacion tarda entre 3 y 7 minutos. Hasta entonces veras 404 o 502."
echo "Prueba con: curl -s -o /dev/null -w '%{http_code}\\n' \"http://$LB_IP/\""
