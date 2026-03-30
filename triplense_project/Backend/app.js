const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// MySQL connection
const connection = mysql.createConnection({
  host: 'localhost',
  user: 'project',     // <-- Replace with your MySQL username
  password: 'Triplens@2025', // <-- Replace with your MySQL password
  database: 'tourism'
});

connection.connect((err) => {
  if (err) {
    console.error('MySQL connection failed:', err);
    return;
  }
  console.log('Connected to MySQL database');
});

// Route to get places by category
app.get('/places/:category', (req, res) => {
  const category = req.params.category;

  const query = 'SELECT name, image_url, description, long_description, rating, locationString, link_location FROM places WHERE category = ?';
  connection.query(query, [category], (err, results) => {
    if (err) {
      console.error('Error fetching data:', err);
      return res.status(500).json({ error: 'Failed to fetch places' });
    }
    res.json(results);
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
