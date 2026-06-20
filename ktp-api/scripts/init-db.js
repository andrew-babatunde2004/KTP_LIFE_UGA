require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { pool } = require("../database");

async function runSqlFile(filename) {
  const filePath = path.join(__dirname, "..", "db", filename);
  const sql = fs.readFileSync(filePath, "utf8");
  await pool.query(sql);
  console.log(`Ran ${filename}`);
}

async function init() {
  const seedOnly = process.argv.includes("--seed-only");
  const schemaOnly = process.argv.includes("--schema-only");

  try {
    if (!seedOnly) {
      await runSqlFile("schema.sql");
    }
    if (!schemaOnly) {
      await runSqlFile("seed.sql");
    }
    console.log("Database ready");
  } catch (err) {
    console.error("Init failed:", err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

init();
