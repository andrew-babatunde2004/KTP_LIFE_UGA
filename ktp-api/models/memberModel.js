const db = require("../database");

function findAll() {
  return new Promise((resolve, reject) => {
    db.all("SELECT * FROM members", (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}


function findById(id) {
  // TODO: Query one member by id from SQLite.
}

function create(data) {
  return new Promise((resolve, reject) => {
    const sql = `
      INSERT INTO members (name, email, role, year, status)
      VALUES (?, ?, ?, ?, ?)
    `;

    db.run(
      sql,
      [data.name, data.role, data.year, data.group],
      function (err) {
        if (err) {
          // returns a rejection request with the error that caused the rejection
          reject(err);
        } else {
          //sends a resolve request that updates the database with the new memeber?
          resolve({
            id: this.lastID,
            name: data.name,
            email: data.role,
            role: data.year,
            year: data.group,
          }
          );
        }
      });
  });
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
