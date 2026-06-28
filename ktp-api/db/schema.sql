CREATE TABLE IF NOT EXISTS users (
  authentik_id UUID PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  first_name TEXT,
  last_name TEXT,
  preferred_name TEXT,
  dob DATE,
  major TEXT,
  graduation_date DATE,
  phone TEXT,
  email TEXT UNIQUE,
  linkedin_url TEXT,
  pledge_class TEXT,
  profile_picture_asset_id TEXT,
  member_group TEXT CHECK (member_group IN ('active', 'pledge', 'eboard', 'chair', 'alumni')),
  profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(authentik_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS photos (
  id SERIAL PRIMARY KEY,
  immich_asset_id TEXT NOT NULL,
  title TEXT,
  caption TEXT,
  uploaded_by UUID REFERENCES users(authentik_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
