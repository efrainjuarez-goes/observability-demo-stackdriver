#!/usr/bin/env bash
# Verifica que el entorno esta listo antes de desplegar nada.
# Comprueba variables, proyecto activo y herramientas disponibles.
set -euo pipefail

fallo=0
ok()    { echo "  OK    $1"; }
error() { echo "  ERROR $1"; fallo=1; }

echo "Verificando entorno..."

# Variables obligatorias
for v in PROY_A PROY_B REGION ZONA SVC_RUN SQL_INSTANCE VM_ALLOY SA_ALLOY BILLING_ID; do
  if [ -z "${!v:-}" ]; then
    error "$v no esta definida. Corre: source vars.sh"
  else
    ok "$v = ${!v}"
  fi
done

[ "$fallo" -eq 1 ] && { echo; echo "Faltan variables. Revisa vars.sh"; exit 1; }

# El proyecto activo de gcloud debe existir
activo="$(gcloud config get-value project 2>/dev/null || true)"
if [ -z "$activo" ] || [ "$activo" = "(unset)" ]; then
  error "No hay proyecto activo en gcloud. Corre: gcloud config set project $PROY_A"
elif ! gcloud projects describe "$activo" >/dev/null 2>&1; then
  error "El proyecto activo ($activo) no existe o esta borrado."
  echo "        Corre: gcloud config set project $PROY_A"
else
  ok "proyecto activo = $activo"
fi

# Herramientas
for cmd in gcloud curl openssl; do
  command -v "$cmd" >/dev/null 2>&1 && ok "$cmd disponible" || error "$cmd no encontrado"
done

echo
if [ "$fallo" -eq 1 ]; then
  echo "Hay problemas que resolver antes de continuar."
  exit 1
fi
echo "Entorno listo."
