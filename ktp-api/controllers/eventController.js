const eventModel = require("../models/eventModel");


async function getEvents(req, res) {
    try {
        const events = await eventModel.findAll();
        res.json(events);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Failed to fetch events" });
    }
    }