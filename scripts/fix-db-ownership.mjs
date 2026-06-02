/**
 * Reassign public tables/sequences to role `serveaso` (local dev).
 * Run when providers fails with "must be owner of table …" after psql created tables as another user.
 */
import pg from "pg";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const targetRole = process.env.POSTGRES_USER || "serveaso";

function loadEnvFromPayments() {
  const envPath = path.join(root, "services/payments/.env.development");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i < 1) continue;
    const key = t.slice(0, i).trim();
    const val = t.slice(i + 1).trim();
    if (!process.env[key]) process.env[key] = val;
  }
}

loadEnvFromPayments();

const superUrl =
  process.env.POSTGRES_SUPERUSER_URL ||
  `postgresql://postgres:${process.env.POSTGRES_PASSWORD || "serveaso"}@${process.env.POSTGRES_HOST || "127.0.0.1"}:${process.env.POSTGRES_PORT || 5432}/${process.env.POSTGRES_DB || "serveaso"}`;

const pool = new pg.Pool({ connectionString: superUrl });

async function main() {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: tables } = await client.query(
      `SELECT tablename
         FROM pg_tables
        WHERE schemaname = 'public'
          AND tableowner <> $1`,
      [targetRole]
    );
    const { rows: sequences } = await client.query(
      `SELECT sequencename
         FROM pg_sequences
        WHERE schemaname = 'public'
          AND sequenceowner <> $1`,
      [targetRole]
    );

    for (const { tablename } of tables) {
      const safe = tablename.replace(/"/g, '""');
      await client.query(`ALTER TABLE public."${safe}" OWNER TO "${targetRole}"`);
    }
    for (const { sequencename } of sequences) {
      const safe = sequencename.replace(/"/g, '""');
      await client.query(`ALTER SEQUENCE public."${safe}" OWNER TO "${targetRole}"`);
    }

    // Always ensure privileges, even when ownership was already correct.
    await client.query(`GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${targetRole}"`);
    await client.query(`GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${targetRole}"`);
    await client.query(`GRANT USAGE, CREATE ON SCHEMA public TO "${targetRole}"`);
    await client.query(`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${targetRole}"`);
    await client.query(`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${targetRole}"`);

    await client.query("COMMIT");
    console.log(
      `✅ Updated ownership/grants in public schema for ${targetRole} (${tables.length} tables, ${sequences.length} sequences)`
    );
  } catch (err) {
    await client.query("ROLLBACK").catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

main()
  .catch((err) => {
    console.error("❌ ownership fix failed:", err.message);
    console.error(
      "   Try: POSTGRES_SUPERUSER_URL=postgresql://postgres:serveaso@127.0.0.1:5432/serveaso node scripts/fix-db-ownership.mjs"
    );
    process.exit(1);
  })
  .finally(() => pool.end());
