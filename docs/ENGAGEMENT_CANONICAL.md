# Canonical engagements model

All bookings live in **`public.engagements`** (`booking_type`: `ON_DEMAND`, `SHORT_TERM`, `MONTHLY`).

The legacy table **`serviceprovider_engagement`** was removed in dev via [`040_merge_serviceprovider_engagement.sql`](../database/sql/040_merge_serviceprovider_engagement.sql). That migration:

1. Backfilled legacy rows into `engagements` (with a temporary `legacy_spe_id` for ID mapping).
2. Repointed `booking_transaction`, `customer_holidays`, `customer_payments`, `customer_used_coupons`, and `provider_reviews` to `engagements.engagement_id`.
3. Dropped `serviceprovider_engagement` and the reviews XOR column `serviceprovider_engagement_id`.

## Application rules

- **APIs and clients** must send and store **`engagements.engagement_id` only**.
- **Reviews** link only through `provider_reviews.engagement_id`.
- **Reporting** can use view `v_engagement_bookings` (canonical rows only).

## Code

- [`engagementCanonical.js`](../services/payments/src/services/engagementCanonical.js) — `resolveEngagementRef(engagementId)` loads a row from `engagements`.
- Apply via DB_Migrations: `npm run db:migrate` (includes `040_merge_serviceprovider_engagement.sql`).

## After schema change

If you use Prisma in **coupons** or other services that still introspect `serviceprovider_engagement`, run `prisma db pull` against the updated database and fix any broken relations.

## Fresh database

`services/payments/src/config/db/schema.sql` defines `engagements` and FKs to it only — no legacy table.
