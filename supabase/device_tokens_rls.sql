-- ============================================================
-- device_tokens: Table + RLS for FCM push notification tokens
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS device_tokens (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token      text NOT NULL UNIQUE,
  section    text NOT NULL,
  platform   text DEFAULT 'android',
  updated_at timestamptz DEFAULT now()
);

-- 2. Create index for fast lookups by section (used by send_push)
CREATE INDEX IF NOT EXISTS idx_device_tokens_section ON device_tokens(section);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- 3. Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- 4. Drop old policies if they exist (safe to re-run)
DROP POLICY IF EXISTS "Users can insert their own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can view their own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON device_tokens;

-- 5. Create granular policies
-- Users can INSERT their own tokens
CREATE POLICY "Users can insert their own tokens"
  ON device_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can SELECT their own tokens  
CREATE POLICY "Users can view their own tokens"
  ON device_tokens
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can UPDATE their own tokens (for token refresh)
CREATE POLICY "Users can update their own tokens"
  ON device_tokens
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can DELETE their own tokens (e.g. on logout)
CREATE POLICY "Users can delete their own tokens"
  ON device_tokens
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- NOTE: The Edge Function uses SUPABASE_SERVICE_ROLE_KEY which
-- bypasses RLS entirely. This is correct — the send_push function
-- needs to read ALL tokens for a given section to broadcast
-- notifications to all users in that section.
