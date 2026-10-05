# Métricas y queries

## Nomenclatura

El exporter produce nombres con el patrón:

```
stackdriver_<recurso>_<servicio>_googleapis_com_<metrica>
```

La regla de relabel en `config.alloy` los normaliza a `gcp_<servicio>_<metrica>`. Es una sola regla genérica que funciona para cualquier tecnología de GCP, presente o futura:

```alloy
rule {
  source_labels = ["__name__"]
  regex         = "stackdriver_.*?_([a-z0-9]+)_(?:googleapis_com|kubernetes_io)_(.+)"
  target_label  = "__name__"
  replacement   = "gcp_${1}_${2}"
}
```

La captura perezosa `.*?` absorbe la parte del recurso sin importar cuántos segmentos tenga, que es lo que varía entre servicios.

| Nombre original | Normalizado |
| --- | --- |
| `stackdriver_cloud_run_revision_run_googleapis_com_request_count` | `gcp_run_request_count` |
| `stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count` | `gcp_loadbalancing_https_request_count` |
| `stackdriver_cloudsql_database_cloudsql_googleapis_com_database_cpu_utilization` | `gcp_cloudsql_database_cpu_utilization` |
| `stackdriver_gce_instance_compute_googleapis_com_instance_cpu_utilization` | `gcp_compute_instance_cpu_utilization` |
| `stackdriver_pubsub_topic_pubsub_googleapis_com_topic_send_request_count` | `gcp_pubsub_topic_send_request_count` |

El nombre original se conserva en la etiqueta `metrica_gcp`, para poder rastrear el origen de cualquier serie.

> **Antes de adoptar el renombrado:** rompe los dashboards construidos sobre los nombres largos. Decidirlo antes de crear paneles, no después. Las series ya enviadas conservan el nombre viejo hasta que venza la retención, por lo que ambos conviven temporalmente en el autocompletado.

## Etiquetas disponibles

### Nativas de GCP

El exporter convierte las labels del recurso monitoreado en labels de Prometheus. Las más útiles:

| Etiqueta | Dónde aparece | Para qué sirve |
| --- | --- | --- |
| `project_id` | todas | Identificador del proyecto, base del mapeo a producto |
| `location` | todas | Región del recurso |
| `response_code` | LB y Cloud Run | Código HTTP exacto |
| `response_code_class` | LB y Cloud Run | `2xx`, `4xx`, `5xx`; base del error rate |
| `service_name` | Cloud Run | Nombre del servicio |
| `revision_name` | Cloud Run | Revisión concreta, útil para comparar despliegues |
| `database_id` | Cloud SQL | Instancia |

### Añadidas por relabel

| Etiqueta | Valor |
| --- | --- |
| `proyecto_gcp` | Copia de `project_id` |
| `producto` | Nombre de negocio; `sin-mapear` si falta en el CSV |
| `area` | Área funcional, desde el CSV |
| `origen` | `stackdriver-exporter` |
| `entorno` | `demo`, `prod`, etc. |
| `metrica_gcp` | Nombre original de la métrica |

La etiqueta `unit` se descarta con `labeldrop`: no aporta nada y multiplica cardinalidad.

## Queries

### Tráfico

```promql
# Requests por segundo en el load balancer
sum(rate(gcp_loadbalancing_https_request_count[5m]))

# Desglose por clase de respuesta
sum by (response_code_class) (rate(gcp_loadbalancing_https_request_count[5m]))

# Latencia p95 del LB
gcp_loadbalancing_https_total_latencies{quantile="0.95"}
```

### Tasa de error

El punto fuerte del patrón: este ratio es considerablemente más incómodo de construir con el constructor de queries de Cloud Monitoring.

```promql
sum(rate(gcp_run_request_count{response_code_class="5xx"}[5m]))
/
sum(rate(gcp_run_request_count[5m]))
```

Por producto:

```promql
sum by (producto) (rate(gcp_run_request_count{response_code_class="5xx"}[5m]))
/
sum by (producto) (rate(gcp_run_request_count[5m]))
```

### Cloud Run

```promql
# Requests por segundo
sum(rate(gcp_run_request_count[5m]))

# Instancias activas
sum(gcp_run_container_instance_count)

# Comparar revisiones (útil tras un despliegue)
sum by (revision_name) (rate(gcp_run_request_count[5m]))
```

### Cloud SQL

```promql
gcp_cloudsql_database_cpu_utilization * 100
gcp_cloudsql_database_memory_utilization * 100
gcp_cloudsql_database_network_connections
```

### Salud del propio recolector

La VM es punto único de fallo, así que conviene vigilarla:

```promql
# Muestras enviadas: si deja de crecer, el problema está del lado de GCP
rate(prometheus_remote_storage_samples_total[5m])

# Muestras fallidas: si crece, el problema está del lado de Grafana Cloud
rate(prometheus_remote_storage_samples_failed_total[5m])
```

## Dashboard sugerido

Tres filas:

1. **Tráfico** — requests por segundo del LB, desglose por `response_code_class`, latencias p50/p95/p99
2. **Cómputo** — instancias de Cloud Run, CPU y memoria del contenedor, requests por revisión
3. **Datos** — CPU, memoria y conexiones de Cloud SQL

Variables de dashboard:

```promql
# Por producto
label_values(gcp_run_request_count, producto)

# Por proyecto
label_values(gcp_run_request_count, project_id)
```

Con la variable `producto`, un solo dashboard cubre los 120 proyectos. Con el datasource nativo de Cloud Monitoring habría que configurarlos uno a uno.

## Latencia esperada

**Unos 2 minutos** extremo a extremo.

| Etapa | Retraso | ¿Se controla? |
| --- | --- | --- |
| GCP muestrea la métrica | hasta 60 s | No |
| Queda disponible en la API | 1 a 4 min según métrica | No |
| Alloy scrapea y envía | hasta 2 min | Sí, vía `scrape_interval` |

Bajar el `scrape_interval` por debajo del tiempo de publicación de GCP no reduce la latencia percibida y multiplica las series devueltas. Este retraso es inherente a leer métricas por API: le ocurre igual al datasource nativo de Cloud Monitoring. Para observabilidad en segundos hay que instrumentar la aplicación con un endpoint `/metrics` propio.

## Descartar métricas

Dos niveles, con efectos distintos:

**No traerlas de GCP** — es el único que reduce el consumo de la API, que se contabiliza por series devueltas:

```alloy
metrics_prefixes = [ "..." ]   // recortar al mínimo

extra_filters = [
  "run.googleapis.com/request_count:resource.labels.service_name=starts_with(\"prod-\")",
]
```

**No enviarlas a Grafana** — reduce cardinalidad y almacenamiento, no el consumo de la API:

```alloy
# Descartar por patrón
rule {
  source_labels = ["__name__"]
  regex         = ".*_bucket$"
  action        = "drop"
}

# Lista blanca: descarta todo lo que no coincida
rule {
  source_labels = ["__name__"]
  regex         = "gcp_(run|loadbalancing|cloudsql)_.*"
  action        = "keep"
}
```

Con muchos proyectos, la lista blanca es el enfoque correcto: se define qué se quiere, no qué se descarta.
