# Grafana Cloud + Prometheus — Serveaso observability

Roll out on **DEV (Render)** first. When `/metrics` passes integration tests on all services, copy scrape targets to **prod** and import the same dashboards with `environment=prod`.

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

All metrics include default labels: `service=<name>`, `environment=<NODE_ENV>`.

---

## Phase 1 — Verify DEV (before Grafana Cloud)

1. Deploy all backend services to Render (this PR adds `/metrics` to reviews, tickets, chat, image-uploader).
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

## Phase 2 — Grafana Cloud setup (DEV)

### 1. Create stack

1. Sign up at [grafana.com](https://grafana.com/) → **Grafana Cloud** (free tier is enough for DEV).
2. Note your **Prometheus remote write URL** and **Grafana instance URL**.

### 2. Add a collector (Grafana Alloy)

**Option A — Grafana Cloud Hosted Collector (simplest)**

1. Grafana Cloud → **Connections** → **Collector**.
2. Create a collector for your region.
3. Paste scrape config from [`prometheus.dev-scrape.yml`](./prometheus.dev-scrape.yml) into the Alloy config (under `prometheus.scrape` blocks if using River, or use the YAML equivalent your UI provides).

**Option B — Alloy on a small VM / laptop (DEV only)**

```bash
# Install Grafana Alloy, then:
alloy run monitoring/alloy.dev.river
```

See [`alloy.dev.river.example`](./alloy.dev.river.example) for a starter River config.

### 3. Confirm data

Grafana Cloud → **Explore** → Prometheus:

```promql
up{environment="dev"}
```

You should see one series per service (9 targets).

```promql
sum by (service) (rate(http_requests_total{environment="dev"}[5m]))
```

Hit any API (or wait for traffic) — rates should appear.

### 4. Import dashboard

1. **Dashboards** → **New** → **Import**.
2. Upload [`dashboards/serveaso-overview.json`](./dashboards/serveaso-overview.json).
3. Select your Prometheus datasource.
4. Set variable `environment` = `dev`.

Per-service dashboards (optional): `services/providers/monitoring/grafana/dashboards/`, `services/coupons/monitoring/grafana/dashboards/`.

---

## Phase 3 — Alerts (recommended before prod)

Create alert rules in Grafana Cloud (or Prometheus):

| Alert | PromQL (example) | Severity |
|-------|------------------|----------|
| Service down | `up{environment="dev"} == 0` | critical |
| High 5xx rate | `sum by (service) (rate(http_requests_total{status_code=~"5..",environment="dev"}[5m])) > 0.1` | warning |
| High p95 latency | `histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_ms_bucket{environment="dev"}[5m]))) > 2000` | warning |
| Not ready (synthetic) | Blackbox or integration test failure | warning |

**Logs:** Render dashboard logs remain the source for stack traces until Loki is added. Optional next step: Grafana Cloud Logs + forward Render log stream or structured JSON from apps.

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
| `monitoring/dashboards/serveaso-overview.json` | Cross-service Grafana dashboard |
| `monitoring/alloy.dev.river.example` | Alloy collector example |
| `tests/integration/metrics.test.mjs` | CI smoke for `/metrics` on all 9 services |
