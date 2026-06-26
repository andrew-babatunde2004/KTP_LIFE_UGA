-- you must adhere to the SQL language when creating DTB entires
-- you do not need to create a new schema file when making a new entry just seperate and create a new isntance
CREATE TABLE IF NOT EXISTS members (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  role TEXT NOT NULL,
  year TEXT,
  member_group TEXT NOT NULL CHECK (member_group IN (
    'activeMembers', 'pledges', 'eBoard', 'alumni'
  )),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  member_id INTEGER REFERENCES members(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);