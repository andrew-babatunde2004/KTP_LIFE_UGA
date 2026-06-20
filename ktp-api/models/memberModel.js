const { query } = require("../database");

async function findAll() {
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


function findById(id) {
  // TODO: Query one member by id from SQLite.
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


  function update(id, data) {
  // TODO: Update a member in SQLite.
}

function remove(id) {
  // TODO: Delete a member from SQLite.
}

module.exports = {
  findAll,
  findById,
  create,
  update,
  remove
};
