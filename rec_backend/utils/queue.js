const { db } = require('./firebase');

module.exports.addToQueue = async (interaction) => {
  await db.collection('interaction_queue').add({
    ...interaction,
    added_at: Date.now()
  });
};

module.exports.getBatchFromQueue = async (batchSize = 50) => {
  const snapshot = await db.collection('interaction_queue')
    .orderBy('added_at')
    .limit(batchSize)
    .get();

  const batch = [];
  const deletes = [];

  snapshot.forEach(doc => {
    batch.push(doc.data());
    deletes.push(doc.ref.delete());
  });

  await Promise.all(deletes);
  return batch;
};