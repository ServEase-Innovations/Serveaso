# Backend CI/CD (GitHub Actions)

For database layout, table inventory, and design tradeoffs, see **[DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md)**.

Deployments are driven from the **Serveaso** monorepo (this repo). Each backend lives under `services/*` (Git submodules).

## Database migrations ([DB_Migrations](https://github.com/ServEase-Innovations/DB_Migrations))

Schema DDL is **not** applied by microservices on startup. The monorepo pins migrations as the **`database/`** git submodule.

```bash
git clone --recurse-submodules <monorepo-url> Serveaso-BE
cd Serveaso-BE
npm run db:install && npm run db:migrate
```

CI and `db:migrate` require the **`services/payments`** submodule (baseline schema). Workflows use `submodules: recursive`.

If migrate fails with `relation "public.engagements" does not exist`, the dev DB never received baseline — re-run migrate on latest `database/` (baseline runs automatically) or run `npm run db:baseline` once.

If migrate fails with `relation "public.support_tickets" does not exist` on `094_epoch_db_columns.sql`, use latest `database/` migrate (Prisma tickets runs before that SQL automatically).

### Database secrets (required for CI migrate)

| Secret | Used when |
|--------|-----------|
| `DEV_DATABASE_URL` | `environment: dev` — full Postgres URL for shared `serveaso` |
| `PROD_DATABASE_URL` | `environment: prod` |

Example: `postgresql://user:pass@host:5432/serveaso1`

See also **[DATABASE_MIGRATIONS.md](./DATABASE_MIGRATIONS.md)**.

---

## Workflows

| Workflow | Purpose |
|----------|---------|
| [**Migrate Database**](../.github/workflows/migrate-database.yml) | Manual: SQL + Prisma (tickets) on dev or prod |
| [**Deploy Backend**](../.github/workflows/deploy-backend.yml) | Manual deploy to **dev** (Render) or **prod** (EC2); migrations first if enabled |
| [**Rollback Backend (EC2)**](../.github/workflows/rollback-backend.yml) | Roll back **prod** to a previous build version |

### Deploy Backend

1. GitHub → **Actions** → **Deploy Backend** → **Run workflow**
2. Choose **environment**: `dev` or `prod`
3. Choose **service**: one service or `all`

**Build version (prod only)**  
Every prod deploy is stored as:

```text
<git-sha>-<run-number>
```

Example: `33f5c35-128`

On the server:

```text
/home/ubuntu/<service>/
  current          → symlink to active release
  VERSION          → active build id
  DEPLOYED_AT      → UTC timestamp
  releases/
    33f5c35-128/
    33f5c35-120/
    ...
```

The last **5** releases are kept; older folders are deleted automatically.

### Rollback (EC2 prod only)

1. **Actions** → **Rollback Backend (EC2)** → **Run workflow**
2. Pick the **service**
3. **rollback_version**: paste a folder name from `releases/` (e.g. `33f5c35-120`), or leave **empty** to roll back to the previous release

SSH to the server to list versions:

```bash
ls -1t /home/ubuntu/payments/releases
cat /home/ubuntu/payments/VERSION
```

---

## GitHub secrets

### Shared (prod / EC2)

| Secret | Description |
|--------|-------------|
| `EC2_HOST` | Production server hostname or IP |
| `EC2_USER` | SSH user (e.g. `ubuntu`) |
| `EC2_SSH_KEY` | Private key (full PEM contents) |

Optional per-service deploy roots (defaults shown):

| Secret | Default path |
|--------|----------------|
| `EC2_DEPLOY_PATH_PAYMENTS` | `/home/ubuntu/payments` |
| `EC2_DEPLOY_PATH_PROVIDERS` | `/home/ubuntu/providers` |
| `EC2_DEPLOY_PATH_COUPONS` | `/home/ubuntu/coupons` |
| `EC2_DEPLOY_PATH_PREFERENCES` | `/home/ubuntu/preferences` |
| `EC2_DEPLOY_PATH_UTILS` | `/home/ubuntu/utils` |
| `EC2_DEPLOY_PATH_REVIEWS` | `/home/ubuntu/reviews` |
| `EC2_DEPLOY_PATH_TICKETS` | `/home/ubuntu/tickets` |
| `EC2_DEPLOY_PATH_IMAGE_UPLOADER` | `/home/ubuntu/image-uploader` |
| `EC2_DEPLOY_PATH_CHAT` | `/home/ubuntu/chat` |

### Prod environment files (multiline `.env` per service)

| Secret |
|--------|
| `PROD_ENV_PAYMENTS` |
| `PROD_ENV_PROVIDERS` |
| `PROD_ENV_COUPONS` |
| `PROD_ENV_PREFERENCES` |
| `PROD_ENV_UTILS` |
| `PROD_ENV_REVIEWS` |
| `PROD_ENV_TICKETS` |
| `PROD_ENV_IMAGE_UPLOADER` |
| `PROD_ENV_CHAT` |

Paste the full `.env` body for each service (same format as on the server today).

### Render deploy hooks (dev only)

Create a **Deploy Hook** in each Render service (Settings → Deploy Hook). Add the URL as a repository secret:

| Secret | Render service (example) |
|--------|---------------------------|
| `RENDER_DEPLOY_HOOK_PAYMENTS` | payments |
| `RENDER_DEPLOY_HOOK_PROVIDERS` | providers |
| `RENDER_DEPLOY_HOOK_COUPONS` | coupons |
| `RENDER_DEPLOY_HOOK_PREFERENCES` | preferences |
| `RENDER_DEPLOY_HOOK_UTILS` | utils |
| `RENDER_DEPLOY_HOOK_REVIEWS` | reviews |
| `RENDER_DEPLOY_HOOK_TICKETS` | tickets |
| `RENDER_DEPLOY_HOOK_IMAGE_UPLOADER` | image-uploader |
| `RENDER_DEPLOY_HOOK_CHAT` | chat |

Dev deploy only **triggers** Render; it does not push env vars (configure those in the Render dashboard).

### Why GitHub does not trigger Render (but Manual Deploy works)

Render **reviews** builds from **`ServEase-Innovations/reviews`**, not the Serveaso monorepo.

| Problem | Fix |
|---------|-----|
| **`GITHUB_TOKEN` cannot push `reviews`** | Add Serveaso secret **`GH_PAT`**: fine-grained PAT with **Contents: Read and write** on `reviews` (and other service repos you deploy). CI pushes `services/reviews` before triggering Render. |
| Only monorepo pushed | Push submodule: `cd services/reviews && git push origin main`, or use **Deploy Backend** with `GH_PAT` set. |
| Hook queued / `pending` | Use latest `main` on remote (push first). Enable **Auto-Deploy** on Render for `main` as backup. |
| Manual Deploy works, CI does not | Almost always **missing `GH_PAT`** or wrong `RENDER_DEPLOY_HOOK_REVIEWS` secret. |

**Recommended: auto-deploy when you push `reviews`**

1. Copy workflow to reviews repo (already in submodule): `services/reviews/.github/workflows/trigger-render-deploy.yml`
2. Push that file to **`reviews` `main`**
3. In **reviews** repo (not Serveaso) → Secrets → `RENDER_DEPLOY_HOOK` = Render deploy hook URL

Then every `git push` to **reviews** triggers Render (like manual deploy).

**Monorepo Deploy Backend (dev)** order: push submodule (`GH_PAT`) → deploy hook (latest on branch, same as Manual) → wait for live.

| Secret (Serveaso repo) | Purpose |
|------------------------|---------|
| `GH_PAT` | Push `services/*` submodules to their GitHub repos (**required** for Render deploy from monorepo) |
| `RENDER_DEPLOY_HOOK_REVIEWS` | From Render → reviews → Deploy Hook |
| `RENDER_API_KEY` + `RENDER_SERVICE_ID_REVIEWS` | Optional; watch deploy status |

### Render API (dev — deploy logs & status)

To **wait for the deploy**, **fail the job on build failure**, and show **build/app logs** in the Actions log and job summary, add:

| Secret | Description |
|--------|-------------|
| `RENDER_API_KEY` | [Render API key](https://dashboard.render.com/u/settings#api-keys) (same workspace as dev services) |
| `RENDER_OWNER_ID` | *(optional)* Workspace ID; if omitted, resolved from the service |
| `RENDER_SERVICE_ID_PAYMENTS` | Service ID from Render dashboard URL (`srv-…`) |
| `RENDER_SERVICE_ID_PROVIDERS` | … |
| `RENDER_SERVICE_ID_COUPONS` | … |
| `RENDER_SERVICE_ID_PREFERENCES` | … |
| `RENDER_SERVICE_ID_UTILS` | … |
| `RENDER_SERVICE_ID_REVIEWS` | … |
| `RENDER_SERVICE_ID_TICKETS` | … |
| `RENDER_SERVICE_ID_IMAGE_UPLOADER` | … |
| `RENDER_SERVICE_ID_CHAT` | … |

### Deployment notification email (optional)

After **Deploy Backend** finishes, a summary email is sent when **notify on deploy** is enabled (default).

| Secret | Description |
|--------|-------------|
| `DEPLOY_NOTIFY_EMAILS` | Comma-separated recipients (e.g. `ops@serveaso.com,ronit@serveaso.com`) |
| `SENDGRID_API_KEY` | [SendGrid](https://sendgrid.com) API key with **Mail Send** permission |
| `DEPLOY_NOTIFY_FROM` | *(optional)* From address verified in SendGrid (default `deploy@serveaso.com`) |

Email includes: environment, build version (`<sha>-<run>`), per-service CI status, Render deploy id/status (dev), commit SHA, link to the GitHub Actions run.

If secrets are unset, the notify step is skipped (deploy still succeeds).

**Payments only:** set `RENDER_API_KEY` + `RENDER_SERVICE_ID_PAYMENTS`; other services can omit service IDs until you want logs for them too.

On **Deploy Backend** → `dev`, leave **wait_for_render** enabled (default). The workflow runs three steps:

1. **Render — resolve hook and service id**
2. **Render — trigger deploy hook**
3. **Render — wait for deploy** — polls until status is **`live`** (only success) or fails the job on `build_failed`, `update_failed`, timeout, or missing API secrets.

Logs upload as a workflow artifact (`render-logs-<service>-<run>`).

If **wait_for_render** is enabled, **`RENDER_API_KEY`** and **`RENDER_SERVICE_ID_*`** are **required** — the job fails if they are missing (no silent success).

Disable **wait_for_render** only if you want to fire the hook and not verify the deploy in CI.

**Troubleshooting**

| Symptom | Likely cause |
|---------|----------------|
| GitHub green but Render failed | Old workflow run, or `wait_for_render` off / missing API secrets — upgrade to latest `main` |
| `404` on “Resolving Render workspace” | Wrong `RENDER_SERVICE_ID_*` (must be `srv-…` from hook URL or dashboard, not `dep-…`), or `RENDER_API_KEY` from a different Render workspace. Latest workflow derives `srv-…` from the deploy hook URL automatically — ensure `RENDER_DEPLOY_HOOK_CHAT` is the chat service’s hook. |
| Hook returns `dep-…` but watch shows a different `dep-…` | Watch uses deploy id from hook response when present |
| `400` fetching logs | Bad `startTime` or workspace; script retries without time filter |
| `update_failed` / `build_failed` | Real Render deploy failure — job should fail; open service → **Deploys** in Render dashboard |
| Deploy stuck **`pending`** 20+ min then CI fails | Render queue or deploy skipped behind another; latest `main` exits **0** with warning unless `RENDER_WATCH_STRICT_TIMEOUT=true`. Check Render **Deploys** for `dep-…` and service **Suspended** state |

Optional env for the watch step: `RENDER_DEPLOY_WAIT_SECONDS` (default **2400**), `RENDER_WATCH_STRICT_TIMEOUT=true` to fail on queue timeout.

---

## EC2 server prerequisites

On the production instance:

- **Node.js 20+** and **npm**
- **pm2** installed globally (`npm i -g pm2`) for Node services
- **Docker** + **Compose plugin** for **providers**
- Deploy user in the `docker` group (providers)
- Outbound access for `npm ci` / `prisma generate`

First-time pm2 setup (once per server):

```bash
pm2 startup
pm2 save
```

---

## Services

| Service | Dev | Prod | Process manager |
|---------|-----|------|-----------------|
| payments | Render hook | EC2 + pm2 | `ecosystem.config.js` |
| providers | Render hook | EC2 + Docker | `docker compose` |
| coupons | Render hook | EC2 + pm2 | `ecosystem.config.js` |
| preferences | Render hook | EC2 + pm2 | `ecosystem.config.js` |
| utils | Render hook | EC2 + pm2 | `ecosystem.config.js` |
| reviews | Render hook | EC2 + pm2 (`npm run build`) | `ecosystem.config.js` |
| image-uploader | Render hook | EC2 + pm2 | `ecosystem.config.js` |
| chat | Render hook | EC2 + pm2 | `backend/server.js` |

Config registry: [`.github/deploy/services.json`](../.github/deploy/services.json)

---

## Submodules

Workflows check out **recursive submodules**. If repos are private, add a `PAT` or deploy key with submodule access to the checkout step.

---

## Legacy per-service workflows

Older workflows may still exist inside submodule repos (e.g. `services/payments/.github/workflows/deploy.yml`). Prefer the monorepo **Deploy Backend** workflow for a single entry point and versioned prod releases.
