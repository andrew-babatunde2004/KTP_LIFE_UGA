// this file handels how members are written into the postgres DB


const { query } = require("../database");

function toDirectoryJSON(row) {
  return {
    id: String(row.id),
    name: row.name,
    role: row.role,
    year: row.year,
    group: row.member_group,
  };
}

async function findAll(groupFilter) {
 let sql = "SELECT * FROM members";
 const params = [];
 if (groupFilter) {
  sql += " WHERE member_group = $1";
  params.push(groupFilter);
 }
 sql += " ORDER BY name ASC";

 const result = await query(sql, params);
 return result.rows.map(toDirectoryJSON);
}


async function findById(id) {
  const result = await query("SELECT * FROM members WHERE id = $1", [id]);
  if (result.rows.length === 0) return null;
  return toDirectoryJSON(result.rows[0]);
}

async function create(data) {
  const result = await query(
    `INSERT INTO members (name, email, role, year , member_group)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *`,
    [data.name, data.email ?? null, data.role, data.year ?? null, data.member_group]
  );
  return toDirectoryJSON(result.rows[0]);
}


async function update(id, data) {
  const result = await query(
    `UPDATE members
     SET name = COALESCE($1, name),
         email = COALESCE($2, email),
         role = COALESCE($3, role),
         year = COALESCE($4, year),
         member_group = COALESCE($5, member_group)
     WHERE id = $6
     RETURNING *`,
    [data.name, data.email, data.role, data.year, data.member_group, id]
  );
  if (result.rows.length === 0) return null;
  return toDirectoryJSON(result.rows[0]);
}

async function remove(id) {
  const result = await query(
    "DELETE FROM members WHERE id = $1 RETURNING id",
    [id]
  );
  return result.rows.length > 0;
}

module.exports = {
  findAll,
  findById,
  create,
  update,
  remove
};
