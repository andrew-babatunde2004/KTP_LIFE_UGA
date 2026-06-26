-- dummy data for production and testing
-- if needed remove before pushing to production
INSERT INTO members (name, role, year, member_group) VALUES
  ('Andrew Babatunde', 'Computer Science', '2027', 'activeMembers'),
  ('Danny Rifai', 'Data Science Track', '2026', 'activeMembers');

INSERT INTO events (title, start_date, end_date, description) VALUES
  (
    'Chapter Meeting',
    '2026-06-25 19:00:00-04',
    '2026-06-25 20:30:00-04',
    'Weekly chapter meeting'
  ),
  (
    'Professional Development Workshop',
    '2026-07-02 18:00:00-04',
    '2026-07-02 19:30:00-04',
    'Resume and interview prep with alumni'
  ),
  (
    'Social Event',
    '2026-07-10 17:00:00-04',
    '2026-07-10 19:00:00-04',
    'End-of-semester chapter social'
  );
