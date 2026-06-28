const { query } = require("../database");

function toCalendarEventJSON(row) {
  return {
    id: String(row.id),
    title: row.title,
    startDate: row.start_date,
    endDate: row.end_date,
    description: row.description,
  };
}

async function findAll() {
  const result = await query("SELECT * FROM events ORDER BY start_date ASC");
  return result.rows.map(toCalendarEventJSON);
}

async function findById(id) {
  const result = await query("SELECT * FROM events WHERE id = $1", [id]);
  if (result.rows.length === 0) return null;
  return toCalendarEventJSON(result.rows[0]);
}

async function create(event) {
  const result = await query("INSERT INTO events (title, start_date, end_date, description) VALUES ($1, $2, $3, $4) RETURNING *", [event.title, event.startDate, event.endDate, event.description]);
  return toCalendarEventJSON(result.rows[0]);
}

async function update(id, event) {
  const result = await query("UPDATE events SET title = $1, start_date = $2, end_date = $3, description = $4 WHERE id = $5 RETURNING *", [event.title, event.startDate, event.endDate, event.description, id]);
  return toCalendarEventJSON(result.rows[0]);
}

async function remove(id) {
  const result = await query("DELETE FROM events WHERE id = $1 RETURNING id", [id]);
  return result.rows.length > 0;
}

module.exports = {
  findAll,
  findById,
  create,
  update,
  remove
};