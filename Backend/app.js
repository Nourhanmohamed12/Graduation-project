// index.js or app.js
const express = require('express');
const cors = require('cors');
const favoriteRoutes = require('./routes/favorites');
require('./db'); // initializes and connects to MySQL

const app = express();
const PORT = 5000;

app.use(cors());
app.use(express.json());
app.use('/favorites', favoriteRoutes);

// Your existing places route
const db = require('./db');
app.get('/places/:category', (req, res) => {
  const category = req.params.category;
  const query = 'SELECT Landmark_ID, name, image_url, description, rating, locationString, link_location FROM places WHERE category = ?';

  db.query(query, [category], (err, results) => {
    if (err) {
      console.error('Error fetching data:', err);
      return res.status(500).json({ error: 'Failed to fetch places' });
    }
    res.json(results);
  });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});