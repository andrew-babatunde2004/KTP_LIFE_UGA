const express = require("express");
const membersController = require("../controllers/membersController");

const router = express.Router();

router.get("/", membersController.getMembers);
router.get("/:id", membersController.getMemberById);
router.post("/", membersController.createMember);
router.put("/:id", membersController.updateMember);
router.delete("/:id", membersController.deleteMember);

module.exports = router;
