-- ============================================================================
-- TABLE: users_profile (ALTER TABLE)
-- PURPOSE: Adds app_mode column to users_profile for seamless personal/business mode persistence
-- ============================================================================

ALTER TABLE IF EXISTS public.users_profile 
ADD COLUMN IF NOT EXISTS app_mode TEXT DEFAULT 'personal';
