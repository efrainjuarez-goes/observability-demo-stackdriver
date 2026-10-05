# Diagnóstico

Referencia de los errores más comunes al operar este montaje, con su causa y resolución.

## Tabla rápida

| Síntoma | Causa | Resolución |
| --- | --- | --- |
| `403 PERMISSION_DENIED` en logs de Alloy | Binding de IAM ausente o sin propagar | Ejecutar `05-iam.sh`, esperar 1 min |
| `403` al hacer remote_write | Token de Grafana sin permiso `metrics:write` | Regenerar el token |
| `401` al hacer remote_write | El username no es el ID numérico de instancia | Es un número, no el correo |
| Alloy: `Start request repeated too quickly` | Error de configuración; systemd oculta el real | Validar con `alloy fmt`, ver logs filtrados |
| `unrecognized attribute name` | Atributo inexistente en el componente | Eliminar la línea; `alloy fmt` lo detecta |
| Series vacías, Alloy sin errores | Sin tráfico, o aún no pasa el retraso de ingesta | Correr `carga.sh` y esperar 5 min |
| LB devuelve 404 o 502 | Propagación del balanceador global | Esperar hasta 7 min |
| `API has not been used in project` | La API tarda en habilitarse | Reintentar en 1 minuto |
| `Project 'xxx' not found or deleted` | Variables apuntando a un proyecto que no existe | Verificar `vars.sh` y el proyecto activo |
| `Invalid value for [--service-account]` | `SA_EMAIL` sin valor | `echo "$SA_EMAIL"` antes de usarla |
| `Permission denied` al leer `/etc/alloy/config.alloy` | Permisos restringidos del archivo | `sudo` también para leer |
| UI de Alloy inaccesible | Puerto no expuesto o firewall | Usar túnel SSH (ver abajo) |

## Validación antes de reiniciar

Validar siempre la sintaxis antes de reiniciar el servicio. Cuesta mucho menos que diagnosticar por logs:

```bash
sudo alloy fmt /etc/alloy/config.alloy > /dev/null && echo "sintaxis OK"
```

Si Alloy no arranca, systemd oculta el error real detrás de sus mensajes de reintento. Fíltralos:

```bash
sudo journalctl -u alloy -n 60 --no-pager | grep -v "systemd\[1\]"
```

O ejecuta Alloy a mano, que es más directo:

```bash
sudo /usr/bin/alloy run /etc/alloy/config.alloy
```

Tras corregir, `reset-failed` es necesario: sin él systemd recuerda que se rindió y no vuelve a intentar.

```bash
sudo systemctl reset-failed alloy
sudo systemctl restart alloy
```

## ¿Dónde se corta el flujo?

Diagnostica de abajo hacia arriba.

**1. ¿GCP tiene la métrica?** Desde la VM:

```bash
TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

AHORA=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ANTES=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v3/projects/${GCP_PROJECT_A}/timeSeries?filter=metric.type%3D%22run.googleapis.com%2Frequest_count%22&interval.startTime=${ANTES}&interval.endTime=${AHORA}" \
  | head -40
```

Si devuelve `{}`, el problema es falta de tráfico o de tiempo, no el exporter.

**2. ¿El exporter las produce?**

```bash
curl -s http://localhost:12345/api/v0/component/prometheus.exporter.gcp.gcp_demo/metrics | head -30
```

Si GCP tiene datos pero aquí no aparecen, revisa `metrics_prefixes`.

**3. ¿Llegan a Grafana Cloud?**

```bash
curl -s http://localhost:12345/metrics \
  | grep -E 'prometheus_remote_storage_(samples_total|failed|retried)'
```

- `samples_failed_total` creciendo → problema del lado de Grafana Cloud (credenciales, URL, límites del plan)
- `samples_total` sin crecer → problema del lado de GCP (permisos o prefijos)

## Acceso a la UI de Alloy

El método recomendado es un túnel SSH, que no expone nada a internet y funciona desde cualquier red:

```bash
gcloud compute ssh "$VM_ALLOY" --zone="$ZONA" --project="$PROY_B" -- -N -L 12345:localhost:12345
```

Y abre `http://localhost:12345`.

Si prefieres abrir el puerto, la IP que importa es la de **tu navegador**, no la de Cloud Shell:

```bash
gcloud compute firewall-rules update allow-alloy-ui --project="$PROY_B" \
  --source-ranges="TU_IP_DEL_NAVEGADOR/32"
```

Verifica también que la VM tenga el tag, porque sin él la regla no aplica:

```bash
gcloud compute instances describe "$VM_ALLOY" --zone="$ZONA" --project="$PROY_B" \
  --format="value(tags.items)"
```

Y que Alloy escuche fuera de localhost:

```bash
sudo ss -lntp | grep 12345   # debe decir 0.0.0.0:12345
```

## Buenas prácticas

**Configuración declarativa por encima de variables de shell.** Para un despliegue a escala conviene Terraform para los recursos y, en la VM, un script de arranque o una imagen con el config ya puesto, en lugar de `export` en una terminal.

**Identificadores literales.** Un ID generado con `$(date)` cambia entre sesiones y produce referencias a proyectos distintos.

**La aplicación crea su propia tabla.** Con `CREATE TABLE IF NOT EXISTS` al arrancar se evita la conexión manual a Cloud SQL, y de paso se verifica que Cloud Run alcanza la base.

**Ejecutar `00-preflight.sh` al inicio de cada sesión.** Comprueba variables, proyecto activo y herramientas antes de tocar nada.
