# Demo: métricas de GCP a Grafana Cloud con Alloy

Montaje reproducible del stackdriver exporter embebido en Grafana Alloy, que lee métricas de la API de Cloud Monitoring de un proyecto GCP y las envía a Grafana Cloud como series de Prometheus.

**No requiere VPN ni túnel entre proyectos.** El acceso se resuelve con un binding de IAM.

## Arquitectura

```
┌─ Proyecto A: carga de trabajo ──────────────────────────────┐
│                                                              │
│  Load balancer ──▶ Cloud Run ──▶ Cloud SQL                   │
│       │                │              │                      │
│       └────────────────┴──────────────┘                      │
│                        ▼                                     │
│            Cloud Monitoring API                              │
│          monitoring.googleapis.com                           │
└──────────────────────────┬───────────────────────────────────┘
                           │ HTTPS + service account
                           │ roles/monitoring.viewer
┌──────────────────────────┴───────────────────────────────────┐
│ Proyecto B: observabilidad                                   │
│                                                              │
│  Alloy en una VM ──▶ relabel ──▶ remote_write ──▶ Grafana    │
│  prometheus.exporter.gcp                            Cloud    │
└──────────────────────────────────────────────────────────────┘
```

## Estructura

```
.
├── app/                      Aplicación Node.js de prueba
│   ├── index.js              4 endpoints con perfiles de métrica distintos
│   └── package.json
├── alloy/
│   └── config.alloy          Configuración completa y comentada
├── scripts/
│   ├── 00-preflight.sh       Verifica el entorno antes de desplegar
│   ├── 01-proyectos.sh       Crea proyectos, facturación y APIs
│   ├── 02-cloudsql.sh        Instancia Postgres
│   ├── 03-cloudrun.sh        Despliega la app
│   ├── 04-loadbalancer.sh    LB HTTP externo con serverless NEG
│   ├── 05-iam.sh             Service account y permiso cruzado
│   ├── 06-vm.sh              VM para Alloy
│   ├── 07-instalar-alloy.sh  Se ejecuta DENTRO de la VM
│   ├── gen-productos.sh      Genera reglas de relabel desde el CSV
│   ├── carga.sh              Genera tráfico para la demo
│   └── 99-limpieza.sh        Borra todo
├── inventario/
│   └── proyectos.csv         Mapeo project_id → producto / área
├── docs/
│   ├── METRICAS.md           Nombres, queries PromQL y paneles
│   └── DIAGNOSTICO.md        Referencia de errores comunes     
└── vars.example.sh           Plantilla de variables
```

## Prerequisitos

- Cuenta de GCP con facturación activa y permisos para crear proyectos
- Cuenta de Grafana Cloud con un stack creado (el free tier alcanza)
- **Todo se ejecuta desde Cloud Shell**, que ya trae `gcloud` y no requiere instalar nada local

## Montaje

### 1. Variables

```bash
cp vars.example.sh vars.sh
# Edita vars.sh con tus valores reales
source vars.sh

# Para que persistan entre pestañas de Cloud Shell:
echo "source $(pwd)/vars.sh" >> ~/.bashrc
```

Usa valores **literales**. Un ID generado con `$(date)` cambia entre pestañas y los comandos acabarían apuntando a proyectos distintos.

### 2. Contraseña de la base

```bash
export SQL_PASS="$(openssl rand -base64 18)"
echo "Guarda esto: $SQL_PASS"
```

### 3. Verificación previa

```bash
./scripts/00-preflight.sh
```

Comprueba que las variables estén definidas, que el proyecto activo de gcloud exista y que las herramientas necesarias estén disponibles.

### 4. Infraestructura

```bash
./scripts/01-proyectos.sh
./scripts/02-cloudsql.sh      # tarda 5-10 min, lánzalo y sigue
./scripts/03-cloudrun.sh
./scripts/04-loadbalancer.sh  # la propagación tarda 3-7 min
./scripts/05-iam.sh
./scripts/06-vm.sh
```

Guarda las salidas de `RUN_URL` y `LB_IP`, que los pasos siguientes necesitan.

### 5. Alloy

```bash
gcloud compute ssh "$VM_ALLOY" --zone="$ZONA" --project="$PROY_B"
```

Dentro de la VM:

```bash
export GCP_PROJECT_A="tu-proyecto-a"
export GC_URL="https://prometheus-prod-NN-prod-REGION.grafana.net/api/prom/push"
export GC_USER="1234567"
export GC_TOKEN="glc_tu_token"

# Copia 07-instalar-alloy.sh y config.alloy a la VM, luego:
bash 07-instalar-alloy.sh
sudo cp config.alloy /etc/alloy/config.alloy
sudo alloy fmt /etc/alloy/config.alloy > /dev/null && echo "sintaxis OK"
sudo systemctl enable --now alloy
sudo journalctl -u alloy -f --no-pager
```

### 6. Tráfico y verificación

```bash
./scripts/carga.sh "$LB_IP"
```

Déjalo corriendo. Las métricas tardan unos 2 minutos en aparecer en Grafana Cloud.

Para ver la UI de Alloy sin abrir el firewall:

```bash
gcloud compute ssh "$VM_ALLOY" --zone="$ZONA" --project="$PROY_B" -- -N -L 12345:localhost:12345
```

Y abre `http://localhost:12345`.

En Grafana, verifica con:

```promql
{origen="stackdriver-exporter"}
```

## Escalar a varios proyectos

1. Añade los proyectos al CSV de inventario:

```csv
project_id,producto,area,tecnologia
sgt-prod-4471,SIGES,salud,gcp
goes-prod-1123,GOES,gobierno,gcp
```

2. Genera el bloque de relabel:

```bash
./scripts/gen-productos.sh > bloque-productos.alloy
```

3. Sustituye el bloque marcado en `config.alloy` entre los comentarios `Bloque generado` y `fin del bloque generado`.

4. Añade los `project_id` a `project_ids` del exporter y crea el binding de IAM de cada proyecto nuevo:

```bash
gcloud projects add-iam-policy-binding PROYECTO_NUEVO \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.viewer"
```

A partir de unos 30 proyectos conviene repartirlos en varios componentes `prometheus.exporter.gcp`, cada uno con su `prometheus.scrape`, para que el fallo de un grupo no detenga la recolección completa.

## Consumo de la API de Monitoring

Desde el 2 de octubre de 2025 las lecturas de la API de Cloud Monitoring se contabilizan **por series de tiempo devueltas**, con una cuota gratuita mensual por cuenta de facturación.

Lo que determina el consumo no es cuántos proyectos tienes, sino cuántas series devuelve cada consulta. Las tres palancas, por orden de impacto:

1. Subir `request_interval` (y `scrape_interval` con él)
2. Recortar `metrics_prefixes` al mínimo que realmente se grafique
3. Usar `extra_filters` para excluir recursos que no se observarán

Antes de escalar a muchos proyectos, conviene medir las series que devuelven unos pocos representativos y extrapolar.

## Limpieza

```bash
./scripts/99-limpieza.sh
```

O, más rápido y seguro:

```bash
gcloud projects delete "$PROY_A"
gcloud projects delete "$PROY_B"
```

Revoca también el token de access policy en Grafana Cloud.

## Documentación

- [`docs/METRICAS.md`](docs/METRICAS.md) — nombres de métricas, queries PromQL y paneles sugeridos
- [`docs/DIAGNOSTICO.md`](docs/DIAGNOSTICO.md) — referencia de errores comunes y diagnóstico
