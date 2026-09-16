-- =====================================================
-- SUPABASE ROW LEVEL SECURITY (RLS) FIX
-- =====================================================
-- This script enables RLS on all public tables to fix
-- the security vulnerabilities detected by Supabase linter.
--
-- ⚠️ IMPORTANT: Review policies before running in production!
-- =====================================================

-- Enable RLS on all tables
-- Note: This will BLOCK ALL ACCESS until policies are created

-- Critical: Authentication & Passwords
ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Critical: Payment & Financial Data
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transaction ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_topups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_transaction ENABLE ROW LEVEL SECURITY;

-- Critical: Engagement & Booking Data
ALTER TABLE public.engagements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_modifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_provider_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_provider_declines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engagement_tracking_status ENABLE ROW LEVEL SECURITY;

-- Service Days & Scheduling
ALTER TABLE public.service_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_day_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_daily_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_weekly_slots ENABLE ROW LEVEL SECURITY;

-- Personal Information
ALTER TABLE public.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serviceprovider ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.address ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_comments ENABLE ROW LEVEL SECURITY;

-- Reviews & Feedback
ALTER TABLE public.provider_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customerfeedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_provider_feedback ENABLE ROW LEVEL SECURITY;

-- Support & Tickets
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_comments ENABLE ROW LEVEL SECURITY;

-- Coupons & Promotions
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupon_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_used_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_provider_used_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons_legacy ENABLE ROW LEVEL SECURITY;

-- Pricing
ALTER TABLE public.pricing_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_rule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_quote_log ENABLE ROW LEVEL SECURITY;

-- Attendance & Leave Management
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_balance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_provider_leave ENABLE ROW LEVEL SECURITY;

-- Requests & Comments
ALTER TABLE public.customerrequest ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customerrequestcomment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serviceproviderrequest ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_provider_request_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customerconcern ENABLE ROW LEVEL SECURITY;

-- Provider Management
ALTER TABLE public.provider_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.serviceprovider_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shortlisted_service_provider ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_provider_payment ENABLE ROW LEVEL SECURITY;

-- Notifications & Tracking
ALTER TABLE public.in_app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracking_sessions ENABLE ROW LEVEL SECURITY;

-- Admin & System
ALTER TABLE public.admin_alert_reads ENABLE ROW LEVEL SECURITY;

-- Migration Tables (Usually safe to keep these restricted)
ALTER TABLE public._serveaso_schema_migrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._prisma_migrations ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- CREATE POLICIES FOR BACKEND ACCESS
-- =====================================================
-- Since you're using backend services (not Supabase Auth),
-- you need to create policies that allow your service role
-- to access the data.
--
-- Option A: Allow ALL access from service role (simpler)
-- Option B: Create specific policies per table (more secure)
-- =====================================================

-- Option A: Allow service role full access to all tables
-- (Recommended if all access goes through your backend)

DO $$
DECLARE
    tbl record;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
        AND tablename NOT IN ('_prisma_migrations', '_serveaso_schema_migrations')
    LOOP
        EXECUTE format('
            CREATE POLICY "Service role full access" ON public.%I
            FOR ALL
            TO service_role
            USING (true)
            WITH CHECK (true);
        ', tbl.tablename);
    END LOOP;
END$$;

-- =====================================================
-- VERIFY RLS IS ENABLED
-- =====================================================
-- Run this query to verify all tables have RLS enabled:
-- 
-- SELECT 
--     schemaname,
--     tablename,
--     rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- All tables should show rowsecurity = true
-- =====================================================

-- =====================================================
-- IMPORTANT NOTES:
-- =====================================================
-- 1. After running this script, ONLY the service_role will have access
-- 2. anon and authenticated roles will be BLOCKED
-- 3. Your backend services should use SERVICE_ROLE_KEY (not ANON_KEY)
-- 4. Frontend apps should NEVER use SERVICE_ROLE_KEY
-- 5. Test thoroughly in development before applying to production
-- =====================================================


-- =====================================================
-- FIX: Function Search Path Mutable (WARNINGS)
-- =====================================================
-- These functions have mutable search_path which could
-- allow attackers to hijack function behavior by
-- manipulating the schema search order.
--
-- Fix: Set search_path explicitly to 'pg_catalog, public'
-- =====================================================

-- Fix: update_tracking_sessions_updated_at
ALTER FUNCTION public.update_tracking_sessions_updated_at()
SET search_path = pg_catalog, public;

-- Fix: update_tracking_status_updated_at
ALTER FUNCTION public.update_tracking_status_updated_at()
SET search_path = pg_catalog, public;

-- =====================================================
-- Verify the fix worked:
-- =====================================================
-- Run this query to check function settings:
--
-- SELECT 
--     n.nspname as schema,
--     p.proname as function_name,
--     pg_get_function_identity_arguments(p.oid) as arguments,
--     p.prosecdef as security_definer,
--     (SELECT string_agg(unnest::text, ', ') 
--      FROM unnest(p.proconfig)) as config_settings
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
-- AND p.proname IN (
--     'update_tracking_sessions_updated_at',
--     'update_tracking_status_updated_at'
-- );
--
-- Both should show: config_settings = 'search_path=pg_catalog, public'
-- =====================================================

-- =====================================================
-- EXPLANATION:
-- =====================================================
-- What is search_path?
-- - It's like PATH in Unix/Linux
-- - Tells PostgreSQL where to look for tables/functions
-- - Default is "public" schema first
--
-- Why is this a security issue?
-- - Attacker could create a malicious table/function
-- - Put it in a schema that comes before "public"
-- - Your function would use attacker's code instead
--
-- How does the fix help?
-- - Explicitly sets search order: pg_catalog (system), then public
-- - pg_catalog is protected (can't be modified)
-- - Functions now always use correct tables
--
-- Example attack (prevented by fix):
-- 1. Attacker creates schema "evil"
-- 2. Attacker creates table "evil.tracking_sessions"
-- 3. Without fix: Function might use evil.tracking_sessions
-- 4. With fix: Function always uses public.tracking_sessions
-- =====================================================
