// initialize-tracking.js - Script to initialize the status tracking collection

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://locationtracking-33ef2-default-rtdb.firebaseio.com" // Replace with your Firebase project URL
});

const db = admin.firestore();

async function initializeVehicleStatusTracking() {
  try {
    console.log('Starting initialization of vehicle status tracking...');
    
    // Get all vehicles from the vehicles collection
    const vehiclesSnapshot = await db.collection('vehicles').get();
    
    if (vehiclesSnapshot.empty) {
      console.log('No vehicles found to initialize.');
      return;
    }
    
    console.log(`Found ${vehiclesSnapshot.size} vehicles to initialize.`);
    
    // Initialize batch processing
    let batch = db.batch();
    let batchCount = 0;
    const BATCH_LIMIT = 500; // Firestore batch limit is 500 operations
    
    // Process each vehicle
    for (const doc of vehiclesSnapshot.docs) {
      const vehicleData = doc.data();
      const vehicleId = doc.id;
      
      // Reference to the tracking document
      const trackingRef = db.collection('vehicle_status_tracking').doc(vehicleId);
      
      // Add to batch
      batch.set(trackingRef, {
        status: vehicleData.status || 'Inactive', // Default to Inactive if no status
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      
      batchCount++;
      
      // If we've reached the batch limit, commit and start a new batch
      if (batchCount >= BATCH_LIMIT) {
        console.log(`Committing batch of ${batchCount} operations...`);
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit any remaining operations
    if (batchCount > 0) {
      console.log(`Committing final batch of ${batchCount} operations...`);
      await batch.commit();
    }
    
    console.log('Vehicle status tracking initialization completed successfully!');
  } catch (error) {
    console.error('Error initializing vehicle status tracking:', error);
  } finally {
    // Exit the process
    process.exit(0);
  }
}

// Run the initialization
initializeVehicleStatusTracking();