# Epoch Migration Remaining Plan

This plan tracks remaining work to complete epoch-first migration across backend services and DB while keeping backward compatibility.

## Status legend

- `done`: epoch-first implemented and validated
- `partial`: epoch available but legacy fields/inputs still canonical in parts
- `pending`: no meaningful epoch-first contract yet

## Service execution matrix

1. `payments` (`done`)
   - Request-side epoch input support added for core create/update endpoints (`/api/engagements`, `PUT /api/engagements/:id`, `/api/v2/createEngagements`).
   - Extended epoch-input fallback in secondary write paths: customer leaves, provider leaves, provider availability day blocks, and V2 vacation apply route.
   - Added epoch-capable admin filter inputs (`from_epoch`, `to_epoch`, `start_date_epoch`, `end_date_epoch`) and pricing quote epoch aliases (`start_date_epoch`, `end_date_epoch` / camelCase variants).
   - Legacy date/time inputs are still accepted as fallback during transition.
   - API docs/readme sweep completed; optional contract tests remain as hardening.
2. `providers` (`done`)
   - Added epoch-first/alias inputs for discovery routes (`nearby`, `nearby-monthly`) and provider/customer/vendor write payloads.
   - Added epoch mirror fields in provider/customer/vendor CRUD responses (`dob_epoch`, `enrolled_date_epoch`, `created_date_epoch`) and kept existing discovery epoch mirrors.
   - Legacy string/date fields remain accepted as fallback for compatibility.
3. `reviews` (`done`)
   - Added request compatibility aliases for review endpoints (`engagementId`/`engagement_id`, `customerId`/`customer_id`).
   - Added explicit response epoch mirror field (`created_at_epoch`) for listed reviews while keeping existing fields.
   - Added service README epoch contract notes.
4. `tickets` (`done`)
   - Added epoch mirror fields in ticket/comment response payloads (`*_epoch`).
   - Added request-side compatibility aliases (`customer_id`, `engagement_id`, `assigned_admin_email`) while keeping legacy camelCase inputs.
   - Documented epoch contract in service README.
5. `coupons` (`done`)
   - Response epoch mirrors added for coupon and coupon_redemption datetime fields.
   - Added request-side epoch aliases for coupon date inputs (`start_date_epoch`, `end_date_epoch`, `created_at_epoch`).
   - Added camelCase/snake_case compatibility for validate/reserve/confirm/release payload keys.
6. `preferences` (`done`)
   - Added epoch mirror fields for returned location/settings timestamps (`createdAt_epoch`, `updatedAt_epoch`).
   - Added request compatibility alias support for `customer_id` alongside `customerId`.
   - Added service README epoch contract notes.
7. `utils` (`done`)
   - Added epoch mirror fields for active utility payloads (`updatedAt_epoch` in platform settings, engagement list date mirrors).
   - Kept migration intentionally scoped due to broad legacy/admin endpoints; active API outputs now follow epoch-first compatibility pattern.

## DB execution matrix

1. `engagements`, `provider_availability` (`done`)
   - Already had canonical epoch columns in active booking flows.
2. `service_days`, `provider_daily_slots`, `provider_weekly_slots` (`done`)
   - Added persistent epoch mirror columns + backfill in idempotent migration `database/sql/094_epoch_db_columns.sql`.
3. `support_tickets`, `support_ticket_comments`, `support_ticket_events` (`done`)
   - Added persistent epoch mirror columns + backfill in `database/sql/094_epoch_db_columns.sql`.
4. `coupons`, `coupon_redemptions`, `in_app_notifications` (`done`)
   - Added persistent epoch mirror columns + backfill in `database/sql/094_epoch_db_columns.sql`.

## Completion criteria

- All booking/scheduling APIs use epoch as primary comparison/sorting source.
- All external API responses include epoch mirrors for datetime fields.
- Legacy string/date fields retained only for compatibility window.
- Migration docs updated per service and root summary.
- Typecheck/build pass after each batch.
