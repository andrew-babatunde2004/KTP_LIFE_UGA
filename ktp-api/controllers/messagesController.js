function getMessages(req, res) {
  // TODO: Fetch messages from the model.
  res.status(501).json({ message: "Not implemented" });
}

function getMessageById(req, res) {
  // TODO: Fetch one message by id from the model.
  res.status(501).json({ message: "Not implemented" });
}

function createMessage(req, res) {
  // TODO: Create a message using request body data.
  res.status(501).json({ message: "Not implemented" });
}

function updateMessage(req, res) {
  // TODO: Update a message by id using request body data.
  res.status(501).json({ message: "Not implemented" });
}

function deleteMessage(req, res) {
  // TODO: Delete a message by id.
  res.status(501).json({ message: "Not implemented" });
}

module.exports = {
  getMessages,
  getMessageById,
  createMessage,
  updateMessage,
  deleteMessage
};
