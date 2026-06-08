# Serveaso metrics collector (Render)

Grafana Alloy **Background Worker** on Render. Scrapes all DEV backend `/metrics` endpoints and remote-writes to **Grafana Cloud Prometheus**.

## Step 1 — Grafana API token (one time)

1. Grafana Cloud → **Connections** → **Collector** → **Install**
2. **Create token**
   - Name: `serveaso-render-collector`
   - Scopes: `set:alloy-data-write`
   - Remote Configuration: **off** (this service uses a local `config.alloy`)
3. Copy the token (shown once).

Also copy from Grafana Cloud → **Your stack** → **Prometheus** → **Details**:

| Field | Env var on Render |
|-------|-------------------|
| Remote write URL | `GRAFANA_PROMETHEUS_URL` |
| Username / Instance ID | `GRAFANA_PROMETHEUS_USER` |
| API token | `GRAFANA_API_KEY` |

## Step 2 — Create Render Background Worker

1. [Render Dashboard](https://dashboard.render.com/) → **New +** → **Background Worker**
2. **Connect repository:** `ServEase-Innovations/Serveaso` (monorepo)
3. **Name:** `serveaso-metrics-collector`
4. **Region:** same as your other DEV services
5. **Branch:** `main`
6. **Root Directory:** `monitoring/render-collector`
7. **Runtime:** **Docker**
8. **Instance type:** Starter or higher (free tier sleeps → metrics gaps)
9. **Environment variables:**

   | Key | Value |
   |-----|--------|
   | `GRAFANA_PROMETHEUS_URL` | `https://prometheus-prod-XX.grafana.net/api/prom/push` |
   | `GRAFANA_PROMETHEUS_USER` | Your numeric instance ID |
   | `GRAFANA_API_KEY` | Token from step 1 (mark **Secret**) |
   | `SCRAPE_ENV` | `dev` |

10. **Create Background Worker**

## Step 3 — Verify

**Render:** Worker logs should show Alloy started without config errors.

**Grafana Explore** (Prometheus datasource):

```promql
up{job="serveaso-render-dev"}
```

Expect **9** series at `1` (one per backend). Any `0` → that service needs redeploy with `/metrics`.

**HTTP panels** use `environment="production"` on Render DEV (`NODE_ENV=production`). See [`../GRAFANA_CLOUD.md`](../GRAFANA_CLOUD.md) Phase 2.

## Step 4 — Import dashboard

```bash
export GRAFANA_URL="https://YOURSTACK.grafana.net"
export GRAFANA_API_TOKEN="glc_..."
./monitoring/scripts/grafana-import-dashboard.sh
```

Or **Dashboards → Import** → upload [`../dashboards/serveaso-overview.json`](../dashboards/serveaso-overview.json).

Set GitHub Actions variable **`GRAFANA_DASHBOARD_URL`** to the dashboard URL (deploy email link).

## Troubleshooting

| Log / symptom | Fix |
|---------------|-----|
| `unknown function env` | Pin Alloy image in Dockerfile (already `v1.8.2`) |
| `401` on remote_write | Wrong `GRAFANA_PROMETHEUS_USER` or `GRAFANA_API_KEY` |
| `up == 0` for a target | Open `https://<host>/metrics` in browser; redeploy service |
| No data overnight | Free Render plan — upgrade worker to Starter |

## Prod (later)

Duplicate the worker or change `SCRAPE_ENV=prod` and update hostnames in `config.alloy` from `monitoring/prometheus.prod-scrape.yml.example`.
