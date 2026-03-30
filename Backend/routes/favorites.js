const express = require('express');
const router = express.Router();
const db = require('../db');

router.post('/', (req, res) => {
  const { name, image_url } = req.body;

  if (!name || !image_url) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  const checkQuery = 'SELECT * FROM favorite WHERE name = ?';
  db.query(checkQuery, [name], (err, results) => {
    if (err) return res.status(500).json({ message: 'Database error' });

    if (results.length > 0) {
      return res.status(409).json({ message: 'Already in favorites' });
    }

    const insertQuery = 'INSERT INTO favorite (name, image_url) VALUES (?, ?)';
    db.query(insertQuery, [name, image_url], (err, result) => {
      if (err) return res.status(500).json({ message: 'Insert error' });

      res.status(200).json({ message: 'Favorite added successfully' });
    });
  });
});

router.delete('/', (req, res) => {
  const { name } = req.body;

  if (!name) {
    return res.status(400).json({ message: 'Missing name' });
  }

  const deleteQuery = 'DELETE FROM favorite WHERE name = ?';
  db.query(deleteQuery, [name], (err, result) => {
    if (err) return res.status(500).json({ message: 'Delete error' });

    res.status(200).json({ message: 'Favorite removed successfully' });
  });
});


// ✅ GET - fetch all favorites
router.get('/', (req, res) => {
  const query = 'SELECT * FROM favorite';

  db.query(query, (err, results) => {
    if (err) {
      console.error('Database error:', err);
      return res.status(500).json({ message: 'Database error' });
    }

    res.status(200).json(results); // send array of favorites
  });
});

module.exports = router;
