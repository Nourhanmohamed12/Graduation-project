// routes/places.js
const express = require('express');
const router = express.Router();
const db = require('../db');

// GET places by category
router.get('/category/:name', (req, res) => {
  const category = req.params.name;
  const query = 'SELECT name, image_url FROM places WHERE category = ?';

  db.query(query, [category], (err, results) => {
    if (err) {
      console.error('Error fetching places:', err);
      return res.status(500).json({ error: 'Database error' });
    }

    res.json(results);
  });
});

module.exports = router;
