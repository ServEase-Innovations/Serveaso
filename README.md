# Serveaso backend monorepo

One **parent repository** that pins four **Git submodules** under `services/`. Each submodule is a normal Node app with its own `package.json`, history, and deploy story. The root uses **npm workspaces** so you can install and run everything together for local development, or work inside any submodule alone.

| Path | Role | Submodule remote |
| ---- | ---- | ---------------- |
| `services/payments` | Payments, engagements, wallets, Socket.IO | [ServEase-Innovations/payments](https://github.com/ServEase-Innovations/payments) |
| `services/preferences` | User preferences (MongoDB) | [ServEase-Innovations/preferences](https://github.com/ServEase-Innovations/preferences) |
| `services/providers` | Providers, customers, vendors (PostgreSQL) | [ServEase-Innovations/providers](https://github.com/ServEase-Innovations/providers) |
| `services/coupons` | Coupons & redemptions (PostgreSQL / Prisma) | [ServEase-Innovations/coupons](https://github.com/ServEase-Innovations/coupons) |

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
```

| Service | Port in `npm run dev` | Docs (typical) |
| ------- | --------------------- | -------------- |
| payments | 4100 | `/v1/api-docs`, `/v2/api-docs` |
| preferences | 3001 | `/api-docs` |
| providers | 4000 | `/api-docs` |
| coupons | 3002 | `/api-docs`, `/metrics` |

**One service** from the root:

```bash
npm run dev:payments
npm run dev:preferences
npm run dev:providers
npm run dev:coupons
```

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
services/
  payments/            # submodule → payments repo
  preferences/         # submodule → preferences repo
  providers/           # submodule → providers repo
  coupons/             # submodule → coupons repo
package.json           # npm workspaces: services/*
docker-compose.yml     # optional local databases
```

## Port note (payments vs providers)

Both upstream **payments** and **providers** often default to port **4000**. When you run `npm run dev` from this monorepo root, **payments** is started with `PORT=4100` so it does not collide with **providers** on **4000**. If you run **payments** only inside `services/payments`, set `PORT` yourself if **providers** is also on the same machine.
