#!/usr/bin/env bash
# Genera las reglas de relabel de producto a partir del CSV de inventario.
# Agrupa los proyectos de un mismo producto en una sola regla con
# alternancia de regex, para no tener 120 reglas sueltas.
#
# Uso:
#   ./gen-productos.sh                      # imprime en pantalla
#   ./gen-productos.sh > bloque.alloy       # guarda a archivo
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
csv="${1:-$raiz/inventario/proyectos.csv}"

[ -f "$csv" ] || { echo "No encuentro $csv" >&2; exit 1; }

# Acumula los project_id de cada producto y de cada area
declare -A ids_producto
declare -A ids_area

while IFS=, read -r project_id producto area tecnologia; do
  # Salta encabezado, lineas vacias y comentarios
  [ "$project_id" = "project_id" ] && continue
  [ -z "$project_id" ] && continue
  case "$project_id" in \#*) continue ;; esac

  if [ -n "${ids_producto[$producto]:-}" ]; then
    ids_producto[$producto]="${ids_producto[$producto]}|$project_id"
  else
    ids_producto[$producto]="$project_id"
  fi

  if [ -n "$area" ]; then
    if [ -n "${ids_area[$area]:-}" ]; then
      ids_area[$area]="${ids_area[$area]}|$project_id"
    else
      ids_area[$area]="$project_id"
    fi
  fi
done < "$csv"

total=0
for p in "${!ids_producto[@]}"; do total=$((total + 1)); done

echo "  // ---- Bloque generado por gen-productos.sh ----"
echo "  // Fuente: $(basename "$csv")  |  productos: $total"

for producto in "${!ids_producto[@]}"; do
  ids="${ids_producto[$producto]}"
  echo
  echo "  rule {"
  echo "    source_labels = [\"project_id\"]"
  echo "    regex         = \"(${ids})\""
  echo "    target_label  = \"producto\""
  echo "    replacement   = \"${producto}\""
  echo "  }"
done

for area in "${!ids_area[@]}"; do
  ids="${ids_area[$area]}"
  echo
  echo "  rule {"
  echo "    source_labels = [\"project_id\"]"
  echo "    regex         = \"(${ids})\""
  echo "    target_label  = \"area\""
  echo "    replacement   = \"${area}\""
  echo "  }"
done

echo
echo "  // ---- fin del bloque generado ----"
