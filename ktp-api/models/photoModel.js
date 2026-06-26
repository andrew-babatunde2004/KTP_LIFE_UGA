const { query } = require("../database");

function toPhotoJSON(row) {
  return {
    id: String(row.id),
    title: row.title,
    imagePath: row.image_path,
    caption: row.caption,
    uploadedBy: row.uploaded_by,
  };
}

async function findAll() {
  const result = await query("SELECT * FROM photos ORDER BY created_at DESC");
  return result.rows.map(toPhotoJSON);
}

async function findById(id) {
  const result = await query("SELECT * FROM photos WHERE id = $1", [id]);
  return toPhotoJSON(result.rows[0]);
}