const express = require('express');
const router = express.Router();
const { spawn } = require('child_process');
const path = require('path');

router.get('/recommend', (req, res) => {
  const userId = req.query.user_id;
  const landmarkId = req.query.landmark_id;   // lowercase

  if (!userId || !landmarkId) {
    return res.status(400).json({ error: 'Missing user_id or landmark_id' });
  }

  const scriptPath = path.join(__dirname, '..', 'python', 'recommend.py');
  const pythonProcess = spawn('python', [scriptPath]);

  let outputData = '';
  let errorData = '';

  pythonProcess.stdout.on('data', (data) => {
    outputData += data.toString();
  });
  pythonProcess.stderr.on('data', (data) => {
    errorData += data.toString();
  });

  pythonProcess.on('close', (code) => {
    // only non-zero exit is an error
    if (code !== 0) {
      console.error(`Python error: ${errorData}`);
      return res.status(500).json({ error: errorData || 'Failed to generate recommendations' });
    }

    try {
      const result = JSON.parse(outputData);
      if (result.error) return res.status(500).json(result);
      return res.json(result);
    } catch (err) {
      console.error('JSON parse error:', err, 'raw:', outputData);
      return res.status(500).json({ error: 'Invalid JSON from Python' });
    }
  });

  pythonProcess.stdin.write(
    JSON.stringify({ user_id: userId, landmark_id: landmarkId })
  );
  pythonProcess.stdin.end();
});

module.exports = router;



//////// WITH CACHING /////////////

// const express = require('express');
// const router = express.Router();
// const { spawn } = require('child_process');
// const path = require('path');
// const { getFromCache, saveToCache } = require("C:\\Users\\Dell G3\\Downloads\\project\\rec_backend\\utils\\cache.js"); // adjust path if needed

// router.get('/recommend', async (req, res) => {
//   const userId = req.query.user_id;
//   const landmarkId = req.query.landmark_id;

//   if (!userId || !landmarkId) {
//     return res.status(400).json({ error: 'Missing user_id or landmark_id' });
//   }

//   try {
//     // Try cache first
//     const cached = await getFromCache(userId, landmarkId);
//     if (cached) {
//       return res.json({ source: 'cache', recommendations: cached });
//     }

//     // If not cached, call Python
//     const recommendations = await callPythonRecommender(userId, landmarkId);
//     await saveToCache(userId, landmarkId, recommendations);
//     return res.json({ source: 'generated', recommendations });
//   } catch (err) {
//     console.error('Recommendation error:', err);
//     return res.status(500).json({ error: 'Recommendation failed' });
//   }
// });

// async function callPythonRecommender(userId, landmarkId) {
//   return new Promise((resolve, reject) => {
//     const scriptPath = path.join(__dirname, '..', 'python', 'recommend.py');
//     const pythonProcess = spawn('python', [scriptPath]);

//     let outputData = '';
//     let errorData = '';

//     pythonProcess.stdout.on('data', (data) => {
//       outputData += data.toString();
//     });

//     pythonProcess.stderr.on('data', (data) => {
//       errorData += data.toString();
//     });

//     pythonProcess.on('close', (code) => {
//       if (code !== 0 || errorData) {
//         return reject(new Error(errorData || `Python exited with code ${code}`));
//       }

//       try {
//         const result = JSON.parse(outputData);
//         if (result.error) return reject(new Error(result.error));
//         resolve(result);  // direct list of landmark dicts
//       } catch (err) {
//         reject(new Error('Invalid JSON from Python: ' + outputData));
//       }
//     });

//     pythonProcess.stdin.write(JSON.stringify({ user_id: userId, landmark_id: landmarkId }));
//     pythonProcess.stdin.end();
//   });
// }

// module.exports = router;
