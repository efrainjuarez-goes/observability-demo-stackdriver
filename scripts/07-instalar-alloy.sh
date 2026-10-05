#!/usr/bin/env bash
# ESTE SCRIPT SE EJECUTA DENTRO DE LA VM, no en Cloud Shell.
# Instala Alloy y deja la configuracion lista.
set -euo pipefail

: "${GCP_PROJECT_A:?Define GCP_PROJECT_A con el ID del proyecto a monitorear}"
: "${GC_URL:?Define GC_URL con la URL de remote write de Grafana Cloud}"
: "${GC_USER:?Define GC_USER con el ID numerico de tu instancia de Prometheus}"
: "${GC_TOKEN:?Define GC_TOKEN con tu token de access policy}"

echo "==> Instalando Alloy"
sudo apt-get update -qq
sudo apt-get install -y -qq gpg curl

sudo mkdir -p /etc/apt/keyrings/
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  | sudo tee /etc/apt/sources.list.d/grafana.list >/dev/null

sudo apt-get update -qq
sudo apt-get install -y alloy
alloy --version

echo "==> Verificando acceso al proyecto $GCP_PROJECT_A"
TOKEN="$(curl -s -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)"

codigo="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v3/projects/${GCP_PROJECT_A}/metricDescriptors?pageSize=1")"

if [ "$codigo" != "200" ]; then
  echo "ERROR: la API de Monitoring respondio $codigo"
  echo "Revisa que el binding de IAM del paso 05 se haya aplicado."
  exit 1
fi
echo "    acceso confirmado"

echo "==> Escribiendo variables de entorno"
sudo tee /etc/default/alloy > /dev/null <<EOF
CUSTOM_ARGS="--server.http.listen-addr=0.0.0.0:12345"
GC_URL="${GC_URL}"
GC_USER="${GC_USER}"
GC_TOKEN="${GC_TOKEN}"
GCP_PROJECT_A="${GCP_PROJECT_A}"
EOF
sudo chmod 600 /etc/default/alloy

echo
echo "Alloy instalado. Ahora copia config.alloy a /etc/alloy/config.alloy y arranca:"
echo "  sudo alloy fmt /etc/alloy/config.alloy > /dev/null && echo 'sintaxis OK'"
echo "  sudo systemctl enable --now alloy"
