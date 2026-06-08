# Grafana Cloud + Prometheus — Serveaso observability

Roll out on **DEV (Render)** first. When `/metrics` passes integration tests on all services, copy scrape targets to **prod** and import the same dashboards with `environment=prod`.

## Status (DEV) — updated 2026-06-09

| Phase | Status | Notes |
|-------|--------|-------|
| **Phase 1** — Verify `/metrics` | **Done** | 9/9 backends expose `/metrics`; CI + `phase2-verify.sh` pass |
| **Phase 2** — Grafana Cloud + collector | **Done** | Stack `maityronit18-prom`, Render worker `serveaso-metrics-collector`, `up{job="serveaso-render-dev"}` = 9 × `1` |
| **Phase 2** — Overview dashboard | **Done** | `Serveaso — API overview` imported; **Metrics environment** = `dev` |
| **Phase 2** — `METRICS_ENVIRONMENT=dev` on Render | **Done** | All 9 DEV backends; app metrics label `environment="dev"` |
| **Phase 2** — Deploy email observability | **Done** | Post-deploy smoke in `.github/workflows/observability-smoke.yml` + deploy notification |
| **Phase 2** — `GRAFANA_DASHBOARD_URL` | **Done** | GitHub Actions variable — dashboard link in deploy email |
| **Phase 3** — DEV alert rules | **Done** | Folder `Serveaso DEV`, evaluation group `serveaso-dev`, 4 rules + email contact point |
| **Phase 4** — Prod | **Not started** | EC2 scrape targets + `Serveaso PROD` folder |

**CI / deploy:** `GH_PAT` required on Serveaso repo to mirror-push `services/imageUploader` → `ServEase-Innovations/imageUploader` before Render deploy.

## What each backend exposes

Every microservice implements:

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness — process up |
| `GET /ready` | Readiness — DB/Mongo reachable |
| `GET /metrics` | Prometheus text exposition |

### Standard metrics (all services)

| Metric | Type | Labels | Use in Grafana |
|--------|------|--------|----------------|
| `http_requests_total` | Counter | `service`, `environment`, `method`, `route`, `status_code` | Request rate, error ratio |
| `http_request_duration_ms` | Histogram | same | p50/p95 latency |
| `api_errors_total` | Counter | + `code` | Business/API error codes |
| `process_cpu_user_seconds_total` | Counter | `service`, `environment` | CPU |
| `process_resident_memory_bytes` | Gauge | `service`, `environment` | Memory |
| `nodejs_eventloop_lag_seconds` | Gauge | `service`, `environment` | Event-loop stalls |

### Service-specific metrics

| Service | Extra metrics |
|---------|----------------|
| **payments** | `socket_io_connections_total`, `socket_io_disconnects_total` |
| **chat** | `socket_io_connections_total`, `socket_io_disconnects_total` |
| **providers** | `provider_actions_total` (`action`, `result`) |
| **coupons** | `coupon_actions_total` (`action`, `result`) |

App metrics labels: `service=<name>`, `environment=<METRICS_ENVIRONMENT || NODE_ENV>`. Render DEV sets **`METRICS_ENVIRONMENT=dev`** (while `NODE_ENV` stays `production`).

---

## Phase 1 — Verify DEV (before Grafana Cloud) ✅

1. ~~Deploy all backend services to Render~~ (`/metrics` on all 9 backends including reviews, tickets, chat, image-uploader).
2. Run integration tests:
   ```bash
   npm run test:integration
   ```
   Or only metrics:
   ```bash
   node --test tests/integration/metrics.test.mjs
   ```
3. Manual spot-check:
   ```bash
   curl -s https://providers-k8w7.onrender.com/metrics | head -30
   ```

---

## Phase 2 — Grafana Cloud setup (DEV) ✅

Use the **Render Background Worker** collector (recommended). Hosted Grafana Cloud collectors work too, but the repo ships a ready-made Alloy config for Render.

### Checklist

| Step | Action | Done? |
|------|--------|-------|
| 2.1 | Grafana Cloud stack + Prometheus remote write URL | ✅ |
| 2.2 | API token (`set:alloy-data-write`) | ✅ |
| 2.3 | Render worker `serveaso-metrics-collector` deployed | ✅ |
| 2.4 | Explore: `up{job="serveaso-render-dev"}` → 9 × `1` | ✅ |
| 2.5 | Import **Serveaso — API overview** dashboard | ✅ |
| 2.6 | GitHub variable `GRAFANA_DASHBOARD_URL` (deploy email link) | ✅ |
| 2.7 | `METRICS_ENVIRONMENT=dev` on all Render DEV backends | ✅ |

Run local verification:

```bash
chmod +x monitoring/scripts/phase2-verify.sh
./monitoring/scripts/phase2-verify.sh
```

### 2.1 — Create stack

1. [grafana.com](https://grafana.com/) → **Grafana Cloud** (free tier is enough for DEV).
2. Note from **Your stack** → **Prometheus** → **Details**:
   - **Remote write URL** → `GRAFANA_PROMETHEUS_URL`
   - **Username / Instance ID** → `GRAFANA_PROMETHEUS_USER`
   - **Grafana instance URL** → e.g. `https://YOURSTACK.grafana.net`

### 2.2 — Collector on Render (recommended)

Follow [`render-collector/README.md`](./render-collector/README.md):

1. Grafana Cloud → **Connections** → **Collector** → **Create token** (scope `set:alloy-data-write`, remote config **off**).
2. Render → **New Background Worker** → repo `Serveaso`, root `monitoring/render-collector`, runtime **Docker**.
3. Env vars: `GRAFANA_PROMETHEUS_URL`, `GRAFANA_PROMETHEUS_USER`, `GRAFANA_API_KEY`, `SCRAPE_ENV=dev`.
4. Use **Starter** instance type or higher (free tier sleeps → metric gaps).

Scrape targets live in [`render-collector/config.alloy`](./render-collector/config.alloy) (single job `serveaso-render-dev`, 9 backends).

**Alternative:** Grafana Cloud hosted collector — paste targets from [`prometheus.dev-scrape.yml`](./prometheus.dev-scrape.yml). **Local DEV only:** [`alloy.dev.river.example`](./alloy.dev.river.example).

### 2.3 — Confirm data in Explore

Grafana → **Explore** → Prometheus datasource:

**Scrape health** (expect 9 series at `1`):

```promql
up{job="serveaso-render-dev"}
```

**HTTP traffic** — app metrics use `environment="dev"` (`METRICS_ENVIRONMENT=dev` on Render):

```promql
sum by (service) (rate(http_requests_total{environment="dev"}[5m]))
```

### 2.4 — Import dashboard

**Option A — script (fastest)**

```bash
export GRAFANA_URL="https://YOURSTACK.grafana.net"
export GRAFANA_API_TOKEN="glc_..."   # Cloud API key or service account token
chmod +x monitoring/scripts/grafana-import-dashboard.sh
./monitoring/scripts/grafana-import-dashboard.sh
```

**Option B — UI**

1. **Dashboards** → **New** → **Import**.
2. Upload [`dashboards/serveaso-overview.json`](./dashboards/serveaso-overview.json).
3. Select your **Prometheus** datasource.
4. Set **Metrics environment** = `dev` (default in repo dashboard JSON).

Copy the dashboard URL into GitHub → **Settings** → **Secrets and variables** → **Actions** → **Variables** → `GRAFANA_DASHBOARD_URL` (used by deploy notification email).

Per-service dashboards (optional): `services/providers/monitoring/grafana/dashboards/`, `services/coupons/monitoring/grafana/dashboards/`.

---

## Phase 3 — Alerts (DEV) ✅

Configured in Grafana Cloud → **Alerting** → folder **`Serveaso DEV`**, evaluation group **`serveaso-dev`** (evaluate every **1m**).

| Rule name | PromQL | Condition | Pending | Severity | No data |
|-----------|--------|-----------|---------|----------|---------|
| **DEV — scrape target down** | `up{job="serveaso-render-dev"}` | below **1** | 5m | `critical` | Alerting |
| **DEV — metrics collector unhealthy** | `count(up{job="serveaso-render-dev"} == 1)` | below **9** | 5m | `critical` | Alerting |
| **DEV — high 5xx rate** | `sum by (service) (rate(http_requests_total{environment="dev",status_code=~"5.."}[5m]))` | above **0.05** | 10m | `warning` | **OK** |
| **DEV — high p95 latency** | `histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_ms_bucket{environment="dev"}[5m])))` | above **2000** (ms) | 10m | `warning` | **OK** |

Labels on all rules: `environment=dev`, plus `severity` as above.

**Notification templates** — use fallbacks so emails are not empty when a label is missing:

```text
{{ or $labels.service $labels.instance "unknown target" }}
```

Rule 2 (collector count) has no `service` label — use `$values` in summary, not `$labels.service`.

**No-data emails:** Rules 3 & 4 must use **If no data → OK**. Otherwise Grafana sends `DatasourceNoData` emails with `[no value]` for `{{ $labels.service }}`.

**After `METRICS_ENVIRONMENT=dev`:** Update rules 3 & 4 in Grafana UI to filter `environment="dev"` (not `production`) if they were created with the old PromQL.

**Contact point:** email (e.g. `serveaso-dev-email`). **Silence** rules during planned deploys (~30m).

**Not in Grafana (handled elsewhere):**

| Concern | Where |
|---------|--------|
| Integration test failures | Deploy email + GitHub Actions |
| `/metrics` missing after deploy | `observability-smoke.yml` in Deploy Backend workflow |
| Synthetic `/ready` checks | Integration tests (`tests/integration/`) |

**Logs:** Render dashboard logs remain the source for stack traces until Loki is added. Optional next step: Grafana Cloud Logs + forward Render log stream or structured JSON from apps.

### Prod alerts (Phase 4)

Duplicate rules into folder **`Serveaso PROD`** with prod scrape job / hostnames and stricter thresholds before customer traffic.

---

## Phase 4 — Prod migration (next week)

1. Copy [`prometheus.dev-scrape.yml`](./prometheus.dev-scrape.yml) → `prometheus.prod-scrape.yml`.
2. Replace Render hostnames with EC2/ALB hostnames from `docs/ENV_MATRIX.md`.
3. Set `environment: prod` on all targets.
4. Add a second Grafana folder **Serveaso PROD** or use dashboard variable `environment=prod`.
5. Re-run integration tests against prod URLs (`INTEGRATION_*_URL` env vars).
6. Enable stricter alerts on prod only.

**Security note:** `/metrics` is public today (same as local Docker scrape). For prod, consider restricting `/metrics` to internal network or Grafana Alloy IP allowlist via nginx/ALB if needed.

---

## File map

| File | Purpose |
|------|---------|
| `monitoring/prometheus.dev-scrape.yml` | DEV scrape targets (Render) |
| `monitoring/prometheus.prod-scrape.yml.example` | Prod template |
| `monitoring/render-collector/config.alloy` | **Active** Alloy config (Render worker) |
| `monitoring/render-collector/README.md` | Collector + dashboard setup on Render |
| `monitoring/dashboards/serveaso-overview.json` | Cross-service Grafana dashboard |
| `monitoring/scripts/phase2-verify.sh` | Local 9/9 `/metrics` check + Explore queries |
| `monitoring/scripts/grafana-import-dashboard.sh` | Import overview dashboard via API |
| `monitoring/alloy.dev.river.example` | Alloy collector example (local DEV) |
| `.github/workflows/observability-smoke.yml` | Post-deploy `/metrics` probe (callable) |
| `.github/scripts/observability-smoke.sh` | Probe script + JSON report for deploy email |
| `tests/integration/metrics.test.mjs` | CI smoke for `/metrics` on all 9 services |
