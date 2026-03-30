const express = require('express');
const router = express.Router();
const { addToQueue } = require('../utils/queue');

router.post('/', async (req, res) => {
  const interaction = req.body;
  await addToQueue(interaction);
  res.json({ success: true });
});

module.exports = router;