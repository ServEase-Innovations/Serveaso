/**
 * Runs before `npm run dev`: ensure DB_Migrations are applied (idempotent).
 * Set SKIP_DEV_MIGRATIONS=true to skip (faster restarts when schema is already up to date).
 */
import { spawnSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");

function loadPaymentsEnv() {
  const envPath = path.join(root, "services/payments/.env.development");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i < 1) continue;
    const key = t.slice(0, i).trim();
    const val = t.slice(i + 1).trim();
    if (process.env[key] === undefined || process.env[key] === "") {
      process.env[key] = val;
    }
  }
}

loadPaymentsEnv();

if (process.env.SKIP_DEV_MIGRATIONS === "true") {
  console.log("[predev] SKIP_DEV_MIGRATIONS=true — skipping database migrations");
  process.exit(0);
}

function run(label, args) {
  console.log(`[predev] ${label}…`);
  const result = spawnSync("npm", args, {
    cwd: root,
    stdio: "inherit",
    shell: process.platform === "win32",
    env: process.env,
  });
  if (result.status !== 0) {
    console.error(
      `[predev] ${label} failed. Fix Postgres (docker compose up -d) and connection env in services/payments/.env.development`
    );
    process.exit(result.status ?? 1);
  }
}

const dbModules = path.join(root, "database", "node_modules");
if (!fs.existsSync(dbModules)) {
  run("db:install", ["run", "db:install"]);
}

run("db:baseline", ["run", "db:baseline"]);
run("db:migrate", ["run", "db:migrate"]);

const ownershipFix = spawnSync("node", ["scripts/fix-db-ownership.mjs"], {
  cwd: root,
  stdio: "inherit",
  env: process.env,
});
if (ownershipFix.status !== 0) {
  console.warn("[predev] ownership fix skipped (non-fatal for some setups)");
}

console.log("[predev] Database migrations up to date");
