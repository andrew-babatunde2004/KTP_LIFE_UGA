const express = require("express");
const cors = require("cors");
require("dotenv").config();
const membersRoutes = require("./routes/members");
//const calendarRouters = require("./routes/events")
// TODO: Re-enable messages when message model/controller logic is ready.
// const messagesRoutes = require("./routes/messages");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// TODO: Add shared middleware, request logging, or validation here.

app.get("/", (req, res) => {
  res.json({ message: "KTP API is running" });
});

// Register routes
app.use("/members", membersRoutes);
//app.use("/events", calendarRouters )
// TODO: Re-enable messages when needed.
// app.use("/messages", messagesRoutes);

app.listen(PORT, () => {
  console.log(`KTP API server running on port ${PORT}`);
});
