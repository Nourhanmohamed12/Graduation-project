const express = require('express');
const cors = require('cors');
const app = express();

// Enable CORS so Flutter can connect from any origin (adjust for production)
app.use(cors());
app.use(express.json());

// Routes
const recommendRouter = require('./rec_routes/recommend_route');
app.use('/', recommendRouter);

const interactRoutes = require('./rec_routes/interact');
app.use('/interact', interactRoutes);

// Choose a port that doesn't conflict with your other services
const PORT = 6000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Recommendation backend running on port ${PORT}`);
});


////// WITHOUT CACHING /////////////

// const express = require('express');
// const cors = require('cors');
// const admin = require('firebase-admin'); // ✅ Add this

// // ✅ Initialize Firebase Admin with your service account
// const serviceAccount = require('./rec-firebase-adminsdk.json');
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount),
// });

// const app = express();
// app.use(cors());
// app.use(express.json());

// // Routes
// const recommendRouter = require('./rec_routes/recommend_route');
// app.use('/', recommendRouter);

// const interactRoutes = require('./rec_routes/interact');
// app.use('/interact', interactRoutes);

// // Start server
// const PORT = 6000;
// app.listen(PORT, '0.0.0.0', () => {
//   console.log(`Recommendation backend running on port ${PORT}`);
// });
