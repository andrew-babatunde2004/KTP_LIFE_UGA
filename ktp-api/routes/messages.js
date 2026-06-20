const express = require("express");
const messagesController = require("../controllers/messagesController");

const router = express.Router();

router.get("/", messagesController.getMessages);
router.get("/:id", messagesController.getMessageById);
router.post("/", messagesController.createMessage);
router.put("/:id", messagesController.updateMessage);
router.delete("/:id", messagesController.deleteMessage);

module.exports = router;
