# Backend CI/CD (GitHub Actions)

For database layout, table inventory, and design tradeoffs, see **[DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md)**.

Deployments are driven from the **Serveaso** monorepo (this repo). Each backend lives under `services/*` (Git submodules).

## Workflows

| Workflow | Purpose |
|----------|---------|
| [**Deploy Backend**](../.github/workflows/deploy-backend.yml) | Manual deploy to **dev** (Render) or **prod** (EC2) |
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
| `RENDER_SERVICE_ID_IMAGE_UPLOADER` | … |
| `RENDER_SERVICE_ID_CHAT` | … |

**Payments only:** set `RENDER_API_KEY` + `RENDER_SERVICE_ID_PAYMENTS`; other services can omit service IDs until you want logs for them too.

On **Deploy Backend** → `dev`, leave **wait_for_render** enabled (default) to poll until `live` or `build_failed`. Logs also upload as a workflow artifact (`render-logs-<service>-<run>`).

If only deploy hooks are configured, dev deploy still works; the workflow prints a warning and does not wait for logs.

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
