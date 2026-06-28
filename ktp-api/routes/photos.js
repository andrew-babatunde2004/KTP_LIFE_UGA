const express = require("express");
const photosController = require("../controllers/photosController");
const upload = require("../middleware/upload");

const router = express.Router();

router.get("/", photosController.getPhotos);
//router.get("/:id", photosController.getPhotoById);
// multer is used to upload the image to the server the upload single image is mutler
router.post("/", upload.single("image"), photosController.createPhoto);
//router.put("/:id", photosController.updatePhoto);
//router.delete("/:id", photosController.deletePhoto);

module.exports = router;