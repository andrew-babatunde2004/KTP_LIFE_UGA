require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { pool, query } = require("../database");

const seedPhotosDir = path.join(__dirname, "..", "db", "seed-photos");
const uploadsDir = path.join(__dirname, "..", "uploads");
const allowedExtensions = new Set([".jpg", ".jpeg", ".png", ".webp"]);

function titleFromFilename(filename) {
  const base = path.basename(filename, path.extname(filename));
  return base
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

async function seedPhotos() {
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }

  const files = fs
    .readdirSync(seedPhotosDir)
    .filter((file) => allowedExtensions.has(path.extname(file).toLowerCase()));

  if (files.length === 0) {
    console.log("No seed images found in db/seed-photos/. Add .jpg, .png, or .webp files.");
    return;
  }

  for (const file of files) {
    const sourcePath = path.join(seedPhotosDir, file);
    const destFilename = `seed-${file}`;
    const destPath = path.join(uploadsDir, destFilename);
    const imagePath = `uploads/${destFilename}`;

    fs.copyFileSync(sourcePath, destPath);

    const existing = await query("SELECT id FROM photos WHERE image_path = $1", [
      imagePath,
    ]);
    if (existing.rows.length > 0) {
      console.log(`Skipping existing photo: ${file}`);
      continue;
    }

    await query(
      `INSERT INTO photos (title, image_path, caption)
       VALUES ($1, $2, $3)`,
      [titleFromFilename(file), imagePath, "Sample chapter photo"]
    );

    console.log(`Seeded photo: ${file}`);
  }
}

async function main() {
  try {
    await seedPhotos();
    console.log("Photo seed complete");
  } catch (err) {
    console.error("Photo seed failed:", err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
