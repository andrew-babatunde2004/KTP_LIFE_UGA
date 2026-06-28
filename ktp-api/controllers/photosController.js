const photoModel = require("../models/photoModel");

async function getPhotos(req, res) {
    try {
        const photos = await photoModel.findAll();
        res.json(photos);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Failed to fetch photos" });
    }
}

async function createPhoto(req, res) {
    try {
        const photo = await photoModel.create(req.body)
        res.status(201).json(photo);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Failed to create photo" });
    }
}

// heh fix this later
//async function deletePhoto(req, res) {
  //  try {
    //    const photo = await photoModel.remove(req.params.id);
      //  res.status(204).send();
    //} catch (err) {
    //    console.error(err);
    //    res.status(500).json({ message: "Failed to delete photo" });
    //}
//}

module.exports = {
    getPhotos,
    createPhoto,
  //  deletePhoto
}