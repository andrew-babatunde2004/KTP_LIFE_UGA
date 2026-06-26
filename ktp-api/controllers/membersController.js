const memberModel = require("../models/memberModel");

// this handles the requrests given by the application or the http request
// all that should be done here is creating a async function and using a const to use the functions we defined in
// memberModel make sure to catch errors and return failed messages for debugging

async function getMembers(req, res) {
  try {
    // TODO: Add filtering, sorting, and pagination later.
    const members = await memberModel.findAll();
    res.json(members);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to fetch members" });
  }
}

function getMemberById(req, res) {
  // TODO: Fetch one member by id from the model.
  res.status(501).json({ message: "Not implemented" });
}

async function createMember(req, res) {
  try {
    const newMember = await memberModel.create(req.body);
    res.status(201).json(newMember);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to create member" });
  }

}

function updateMember(req, res) {
  // TODO: Update a member by id using request body data.
  res.status(501).json({ message: "Not implemented" });
}

function deleteMember(req, res) {
  // TODO: Delete a member by id.
  res.status(501).json({ message: "Not implemented" });
}

// exports the functions we defined in this file so that we can call them within other javascript files
module.exports = {
  getMembers,
  getMemberById,
  createMember,
  updateMember,
  deleteMember
};
