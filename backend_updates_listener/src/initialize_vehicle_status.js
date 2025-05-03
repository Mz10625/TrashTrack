const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://locationtracking-33ef2-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

async function initializeVehicleStatusTracking() {
  try {
    console.log('Starting initialization of vehicle status tracking...');
    
    const vehiclesSnapshot = await db.collection('vehicles').get();
    
    if (vehiclesSnapshot.empty) {
      console.log('No vehicles found to initialize.');
      return;
    }
    
    console.log(`Found ${vehiclesSnapshot.size} vehicles to initialize.`);
    
    let batch = db.batch();
    let batchCount = 0;
    const BATCH_LIMIT = 500; // Firestore batch limit is 500 operations
    
    for (const doc of vehiclesSnapshot.docs) {
      const vehicleData = doc.data();
      const vehicleId = doc.id;
      
      const trackingRef = db.collection('vehicle_status_tracking').doc(vehicleId);
      
      batch.set(trackingRef, {
        status: vehicleData.status || 'Inactive',
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      
      batchCount++;
      
      if (batchCount >= BATCH_LIMIT) {
        console.log(`Committing batch of ${batchCount} operations...`);
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      console.log(`Committing final batch of ${batchCount} operations...`);
      await batch.commit();
    }
    
    console.log('Vehicle status tracking initialization completed successfully!');
  } catch (error) {
    console.error('Error initializing vehicle status tracking:', error);
  } finally {
    process.exit(0);
  }
}

initializeVehicleStatusTracking();