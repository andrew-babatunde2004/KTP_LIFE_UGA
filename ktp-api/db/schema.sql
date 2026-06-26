-- Enable UUID support
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS
-- Seeded by Authentik webhook when admin creates a user.
-- Profile fields are NULL until the user completes onboarding.
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  -- Identity (comes from Authentik)
  id            UUID        PRIMARY KEY,
  username      TEXT        NOT NULL UNIQUE,
  member_group  TEXT        NOT NULL CHECK (member_group IN (
                  'activeMembers', 'pledges', 'eBoard', 'alumni'
                )),

  -- Profile (filled by the user during onboarding)
  full_name           TEXT,
  preferred_name      TEXT,
  dob                 DATE,
  major               TEXT,
  graduation_date     DATE,
  phone               TEXT,
  email               TEXT,
  linkedin            TEXT,
  pledge_class        TEXT,
  profile_picture_url TEXT,

  -- Bucket for future fields — add new keys here without a schema change.
  -- For permanent/queryable fields, use ALTER TABLE users ADD COLUMN instead.
  extra         JSONB       NOT NULL DEFAULT '{}',

  -- Status
  profile_complete  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update updated_at whenever a row changes
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- MESSAGES (stub — expand into conversations later)
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        TEXT        NOT NULL,
  read        BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
