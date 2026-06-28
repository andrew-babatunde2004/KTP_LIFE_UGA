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

async function create(photo) {
  const result = await query("INSERT INTO photos (title, image_path, caption, uploaded_by) VALUES ($1, $2, $3, $4) RETURNING *", [photo.title, photo.imagePath, photo.caption, photo.uploadedBy]);
  return toPhotoJSON(result.rows[0]);
}

async function remove(id) {
    const result = await query("DELETE FROM photos WHERE id = $1 RETURNING id", [id]);
    return result.rows.length > 0;
}

module.exports = {
    findAll,
    create,
    remove
}