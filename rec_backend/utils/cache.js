// const admin = require('firebase-admin');

// // Initialize Firebase Admin SDK
// if (!admin.apps.length) {
//   const serviceAccount = require('../rec-firebase-adminsdk.json');
//   admin.initializeApp({
//     credential: admin.credential.cert(serviceAccount)
//   });
// }

// const db = admin.firestore();
// const cacheCollection = db.collection('recommendation_cache');

// // Generate a unique key for each (user_id, landmark_id) pair
// function generateKey(userId, landmarkId) {
//   return `${userId}_${landmarkId}`;
// }

// // Retrieve from Firestore cache
// async function getFromCache(userId, landmarkId) {
//   const key = generateKey(userId, landmarkId);
//   const doc = await cacheCollection.doc(key).get();
//   if (doc.exists) {
//     return doc.data().recommendations;
//   }
//   return null;
// }

// // Save to Firestore cache
// async function saveToCache(userId, landmarkId, recommendations) {
//   const key = generateKey(userId, landmarkId);
//   await cacheCollection.doc(key).set({
//     user_id: userId,
//     landmark_id: landmarkId,
//     recommendations,
//     timestamp: new Date().toISOString()
//   });
// }

// module.exports = {
//   getFromCache,
//   saveToCache
// };
