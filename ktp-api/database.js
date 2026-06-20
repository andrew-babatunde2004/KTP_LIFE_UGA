const sqlite3 = require("sqlite3").verbose();
const path = require("path");

// TODO: Add database initialization, migrations, and error handling later.
const dbPath = path.join(__dirname, "db", "ktp.db");
const db = new sqlite3.Database(dbPath);

module.exports = db;
