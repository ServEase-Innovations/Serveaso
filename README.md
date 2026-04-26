# Serveaso monorepo (backend + UI)

Official umbrella repository: [ServEase-Innovations/Serveaso](https://github.com/ServEase-Innovations/Serveaso). Licensed under the MIT License — see [LICENSE](LICENSE).

This **parent** repository uses **Git submodules** to pin the backend services and the web app. Each submodule keeps its own history, release cadence, and can be developed or deployed on its own.

| Path | Role | Submodule remote |
| ---- | ---- | ---------------- |
| `services/payments` | Payments, engagements, wallets, Socket.IO | [ServEase-Innovations/payments](https://github.com/ServEase-Innovations/payments) |
| `services/preferences` | User preferences (MongoDB) | [ServEase-Innovations/preferences](https://github.com/ServEase-Innovations/preferences) |
| `services/providers` | Providers, customers, vendors (PostgreSQL) | [ServEase-Innovations/providers](https://github.com/ServEase-Innovations/providers) |
| `services/coupons` | Coupons & redemptions (PostgreSQL / Prisma) | [ServEase-Innovations/coupons](https://github.com/ServEase-Innovations/coupons) |
| `services/utils` | Email helpers, uploads, admin/Mongo utilities, WebSockets | [ServEase-Innovations/utils](https://github.com/ServEase-Innovations/utils) |
| `services/notifications` | Mail / notification sending (code under `Mail/`) | [ServEase-Innovations/notifications](https://github.com/ServEase-Innovations/notifications) |
| `services/chat` | Real-time chat (MERN: `backend/`, `frontend/`) | [ServEase-Innovations/chat](https://github.com/ServEase-Innovations/chat) |
| `services/reviews` | Reviews service (TypeScript, Prisma, PostgreSQL) | [ServEase-Innovations/reviews](https://github.com/ServEase-Innovations/reviews) |
| `apps/servase-ui` | **React (CRA) + TypeScript** customer UI for Servease | [ServEase-Innovations/ServEase_UI](https://github.com/ServEase-Innovations/ServEase_UI) |

The **root** uses **npm workspaces** only for `services/*`. The UI app has a **separate** `node_modules` under `apps/servase-ui` to avoid clashing with backend dependency hoisting.

## Web UI (ServEase_UI)

```bash
cd apps/servase-ui
npm install
npm start
# or from repo root:
npm run dev:ui
```

- Default dev server: **http://localhost:3000** (per Create React App).
- For **local + monorepo backends**, copy `apps/servase-ui/.env.local.example` to `apps/servase-ui/.env.local` (defaults match `npm run dev` ports; see `src/config/urls.ts`).
- For **QA / production**, use that project’s **`.env.qa`** / deployment env (do not commit secrets).
- The UI is **not** required to run the backend microservices.

### Is it a good idea to keep the UI in this repo?

**Reasons to keep it (submodule):** one `git clone --recurse-submodules` gets a **full stack** for onboarding; a single “platform” commit can **pin** API + UI versions for reproducible QA. **Submodules** preserve separate GitHub projects and access control, unlike copying source into one flat tree.

**Reasons to split:** the UI and APIs often **release on different schedules**; CI can get heavier; very large `npm install` in the UI is separate from the backend (which you already have by not using workspaces for `apps/*`).

A common pattern is: **this layout for local / integration work**, and **independent deploy pipelines** per `ServEase_UI` and each API repo in production. Submodules are optional: you can remove the submodule and clone the UI elsewhere if the team prefers two checkouts.

## Clone (with submodules)

```bash
git clone --recurse-submodules <your-monorepo-url> Serveaso-BE
cd Serveaso-BE
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

Update all submodules to the commits recorded by the parent repo:

```bash
git submodule update --init --recursive
```

Pull upstream changes for each submodule (after fetching in the submodule):

```bash
git submodule foreach 'git fetch origin && git checkout main && git pull origin main'
```

(Use each repo’s default branch name if it is not `main`.)

## Install (full monorepo)

```bash
npm install
```

Runs installs for every workspace (including submodule packages).

## Run locally

**All services** (non-clashing ports via env in the script):

```bash
npm run dev
# alias:
npm run dev:all
```

| Service | Port in `npm run dev` | Notes |
| ------- | --------------------- | ----- |
| payments | 4100 | HTTP + **Socket.IO**; `/v1/api-docs`, `/v2/api-docs` |
| preferences | 3001 | `/api-docs` |
| providers | 4000 | `/api-docs` |
| coupons | 3002 | `/api-docs`, `/metrics` |
| utils | **3030** (main + WebSocket), **4030** (email HTTP app) | Two listeners in one process; see `services/utils/.env.example` |
| reviews | 5005 | Set `PORT` in script to avoid clashing with CRA (3000) |

**One service** from the root:

```bash
npm run dev:payments
npm run dev:preferences
npm run dev:providers
npm run dev:coupons
npm run dev:utils
npm run dev:reviews
```

### Web UI (points APIs at the ports above)

From the repo root:

```bash
cp apps/servase-ui/.env.local.example apps/servase-ui/.env.local
# edit if your ports differ, then:
npm run dev:ui
```

`apps/servase-ui/src/config/urls.ts` defaults to the same localhost ports as this table. Override with `REACT_APP_*` variables in `.env.local` (see the example file).

### Troubleshooting (`npm run dev`)

| Symptom | What to do |
| --------|------------|
| **`preferences` crashes** with `Cannot read properties of undefined (reading 'startsWith')` (or Mongo connect errors) | The preferences service needs **`MONGO_URI`** in **`services/preferences/.env`** (Mongo connection string, e.g. `mongodb://localhost:27017` if you use the repo’s optional `docker compose` Mongo). Optionally set **`DB_NAME`**. The server calls `new MongoClient(process.env.MONGO_URI)`; if `MONGO_URI` is empty, the driver throws. |
| **`reviews` failed** with `ts-node-dev: command not found` | Fixed in the **reviews** submodule: dev uses **`tsx`**. From the monorepo root run **`npm install`**, then **`npm run dev`** again. The script sets **`PORT=5005`**. If you run the reviews app alone without `PORT`, the default is **5005** to avoid clashing with the React app on 3000. |
| **`payments` logs** `constraint ... for relation "..." already exists` / schema apply errors on startup | Usually harmless if the API is already up: **`initDB`** re-runs SQL against an existing database. You can ignore the message if `payments_api_started` and `http://localhost:4100` work. A proper fix is idempotent migrations (separate work). |
| **Port already in use** (EADDRINUSE) | Each service in the `npm run dev` table uses a fixed port. Stop the other process using that port, or change the **`PORT=...`** prefix in **`package.json`** and match **`apps/servase-ui/.env.local`** to the new URL. |
| **`/api-docs` on preferences (3001) returns JSON 401** with `messageId: auth.unauthorized` | The preferences app does **not** return that. Run `curl -sI http://localhost:3001/_whoami` — you should see **`X-ServeEaso-Service: preferences`**. If not, another process is on 3001 or traffic is not reaching Node; use `lsof -i :3001` and see [services/preferences/README.md](services/preferences/README.md#swagger--docs-return-401-json-with-authunauthorized). |

**One service without the monorepo** (deploy / CI pattern — only that repo matters):

```bash
cd services/providers
npm install
npm run dev
```

Each submodule can be cloned and deployed **by itself** from its own GitHub repository; the monorepo is optional for local convenience and version pinning.

## Independent deployment

Typical options:

1. **Deploy from the submodule’s remote** — Point your pipeline (GitHub Actions, ECS, etc.) at `ServEase-Innovations/payments` (or your fork). No monorepo checkout required.
2. **Deploy from the monorepo** — Checkout this repo with submodules, set the job `working-directory` to `services/payments` (or the service you need), run `npm ci` and `npm start` there. Pin the parent commit so production tracks known submodule SHAs.
3. **Docker** — Use each service’s own `Dockerfile` when present (e.g. `services/providers`); build context is that submodule directory.

Submodules do **not** force shared releases: you bump the submodule pointer in the parent only when you want the monorepo to record a new combination of versions.

## Scaling **utils** (one submodule today, optional split later)

The [utils](https://github.com/ServEase-Innovations/utils) service runs **two HTTP servers** in one Node process (main app + email routes). For local monorepo runs, **`PORT`** and **`UTILS_EMAIL_PORT`** default to **3030** and **4030** so they do not collide with preferences (3001) or providers (4000).

When you outgrow a single process, split by **creating a new repository** (for example `utils-email`), moving the `appForEmail` stack and its routes into it, and deploying that repo as its own service. Point other apps at it with an env var (for example `UTILS_EMAIL_SERVICE_URL`). You do not need multiple submodules until those repos exist; keep **one** `utils` submodule until the split is real.

## Observability (metrics, logs, Grafana)

Each submodule can expose **Prometheus** metrics at **`GET /metrics`**, write JSON lines to **`logs/app.log`**, and (optionally) run a local **Docker** stack with **Prometheus + Grafana + Loki + Promtail**.  
**Prometheus** scrapes **metrics**; **Loki** (via **Promtail**) ingests **logs**; **Grafana** visualizes both.

| Submodule | Metrics job (Prometheus) | Loki / Promtail log label | Grafana (example host port) | Compose / docs |
|-----------|-------------------------|---------------------------|----------------------------|----------------|
| **payments** | `payments-app` | `job="payments-app"` | http://localhost:3202 | `docker-compose.monitoring.yml` — [payments README](services/payments/README.md) |
| **preferences** | `preferences-app` | `job="preferences-app"` | http://localhost:3203 | `docker-compose.monitoring.yml` — [preferences README](services/preferences/README.md) |
| **providers** | `providers-app` | `job="providers-app"` | http://localhost:3205 (full stack) or 3000 (slim) | `docker-compose.observability-full.yml` — [providers README](services/providers/README.md) |
| **coupons** | `coupons-api` | `job="coupons-app"` | http://localhost:3101 | `docker-compose.monitoring.yml` — [coupons README](services/coupons/README.md) |
| **utils** | `utils-app` | `job="utils-app"` | http://localhost:3204 | `docker-compose.monitoring.yml` — [utils README](services/utils/README.md) |

**Port conflicts:** Do not run every stack at once without editing host ports in each `docker-compose*.yml`. Only one process can bind **9090** on the host, etc.

**Scrape targets:** Prometheus in Docker uses **`host.docker.internal`** to reach APIs on your machine. If your monorepo dev ports differ (e.g. payments on **4100**), edit that service’s `monitoring/prometheus/prometheus.yml` (or equivalent) `targets` before `docker compose up`.

## Environment variables

Each service keeps its own `.env`. See `.env.monorepo.example` for the default port layout when running `npm run dev` from the root.

## Optional: Postgres + Mongo (Docker)

```bash
docker compose up -d
```

- PostgreSQL: `localhost:5432`, user/password/database `serveaso`
- MongoDB: `localhost:27017`

## Layout

```
.gitmodules            # submodule URLs + paths
apps/
  servase-ui/          # submodule → ServEase_UI (React; own package-lock)
services/
  payments/            # submodule → payments repo
  ...
package.json           # npm workspaces: services/* only
docker-compose.yml     # optional local databases
```

## Port note (payments vs providers)

Both upstream **payments** and **providers** often default to port **4000**. When you run `npm run dev` from this monorepo root, **payments** is started with `PORT=4100` so it does not collide with **providers** on **4000**. If you run **payments** only inside `services/payments`, set `PORT` yourself if **providers** is also on the same machine.
