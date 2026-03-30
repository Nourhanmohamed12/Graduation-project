const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { execPython } = require('./pythonService'); // Import the Python service

const app = express();
const port = 4000;

app.use(cors());

// Configure Multer for file uploads
const upload = multer({ dest: 'uploads/' });

app.post('/predict', upload.single('image'), async (req, res) => {
    if (!req.file) {
        return res.status(400).send('No file uploaded.');
    }

    const imagePath = path.join(__dirname, req.file.path);

    try {
        const result = await execPython(imagePath); // Use the Python service

        // Remove the uploaded file after prediction
        fs.unlink(imagePath, (err) => {
            if (err) console.error('Failed to delete uploaded image:', err);
        });

        res.json(result);
    } catch (err) {
        console.error('Error processing Python script:', err);
        res.status(500).send('Internal server error.');
    }
});



app.listen(4000, '0.0.0.0', () => {
    console.log('Server running on http://0.0.0.0:4000');
  });
  
