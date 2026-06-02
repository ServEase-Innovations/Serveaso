/**
 * Load repo-root `.env.local` / `.env` and sync POSTGRES_DB ↔ DB_NAME.
 * Used by predev migrations and other root scripts.
 */
import { createRequire } from "module";
import { fileURLToPath } from "url";
import path from "path";

const require = createRequire(import.meta.url);
const { loadMonorepoPostgresEnv } = require("./postgres-env.cjs");

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const result = loadMonorepoPostgresEnv({ root });

if (result.loaded.length) {
  console.log("[env] loaded monorepo postgres env:", result.loaded.join(", "));
}

export { loadMonorepoPostgresEnv };
