const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.DATABASE_URL
});

const db = admin.firestore();

app.listen(process.env.PORT || 3000, () => {
  console.log(`Server is running on port ${process.env.PORT || 3000}`);
  
  const vehiclesRef = db.collection('vehicles');
  
  vehiclesRef.onSnapshot(snapshot => {
    snapshot.docChanges().forEach(async change => {
      if (change.type === 'modified') {
        const vehicleData = change.doc.data();
        
        // We need to track previous status - Firestore doesn't provide previousData directly
        // We'll use a separate collection to track the previous status
        const statusTrackingRef = db.collection('vehicle_status_tracking').doc(change.doc.id);
        const statusTracking = await statusTrackingRef.get();
        
        const previousStatus = statusTracking.exists ? statusTracking.data().status : null;
        
        if (previousStatus === 'Inactive' && vehicleData.status === 'Active') {
          
          const wardNumber = vehicleData.ward_no;
          // console.log(`Vehicle ${change.doc.id} in ward ${wardNumber} changed from Inactive to Active`);
          
          await notifyUsersInWard(wardNumber, change.doc.id, vehicleData);
        }
        
        await statusTrackingRef.set({
          status: vehicleData.status,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    });
  }, error => {
    console.error('Error listening to vehicle changes:', error);
  });
});

// Function to notify users in the same ward
async function notifyUsersInWard(wardNumber, vehicleId, vehicleData) {
  try {
    // Get all users belonging to the same ward
    const usersSnapshot = await db.collection('users')
      .where('ward_number', '==', wardNumber)
      .get();
    
    if (usersSnapshot.empty) {
      console.log(`No users found in ward ${wardNumber}`);
      return;
    }
    
    // Collect FCM tokens of users in the ward
    const tokens = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });
    
    if (tokens.length === 0) {
      console.log('No FCM tokens found for users in this ward');
      return;
    }
    
    // Prepare notification message
    const message = {
      notification: {
        title: 'Trash Pickup Alert',
        body: `Don't miss today's waste pickup in your ward! Please ensure your garbage is placed at the collection point.`
      },
      data: {
        vehicleId: vehicleId,
        wardNumber: wardNumber.toString(),
        vehicleType: vehicleData.vehicle_type || '',
        updatedAt: new Date().toISOString()
      }
    };
    
    // Send the notification using the correct method for batched messages
    const batchResponse = await sendNotificationsInBatches(tokens, message);
    console.log(`Successfully sent ${batchResponse.successCount} notifications out of ${tokens.length}`);
    
    // Handle failed tokens
    if (batchResponse.failedTokens.length > 0) {
      await handleFailedTokens(batchResponse.failedTokens);
    }
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
}

// Function to send notifications in batches (FCM has a limit of 500 recipients per request)
async function sendNotificationsInBatches(tokens, messageData) {
  const batchSize = 500; // FCM maximum batch size
  const batches = [];
  
  // Split tokens into batches
  for (let i = 0; i < tokens.length; i += batchSize) {
    batches.push(tokens.slice(i, i + batchSize));
  }
  
  let successCount = 0;
  const failedTokens = [];
  
  // Process each batch
  for (const batch of batches) {
    try {
      // In firebase-admin v13.3.0, we need to use sendEach or send for individual messages
      const responses = await admin.messaging().sendEach(
        batch.map(token => ({
          token: token,
          notification: messageData.notification,
          data: messageData.data
        }))
      );
      
      successCount += responses.successCount;
      
      if (responses.failureCount > 0) {
        responses.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(batch[idx]);
            console.error('Failed to send notification:', resp.error);
          }
        });
      }
    } catch (error) {
      console.error('Error sending batch notifications:', error);
      // If the entire batch fails, add all tokens to failed tokens
      failedTokens.push(...batch);
    }
  }
  
  return {
    successCount,
    failedTokens
  };
}

// Handle failed FCM tokens
async function handleFailedTokens(failedTokens) {
  try {
    // Find users with the failed tokens and update or remove their tokens
    for (const token of failedTokens) {
      const userSnapshot = await db.collection('users')
        .where('fcmToken', '==', token)
        .get();
      
      if (!userSnapshot.empty) {
        // Remove or mark invalid FCM token
        userSnapshot.forEach(async doc => {
          await db.collection('users').doc(doc.id).update({
            fcmToken: admin.firestore.FieldValue.delete() // or mark as invalid
          });
          console.log(`Removed invalid FCM token for user ${doc.id}`);
        });
      }
    }
  } catch (error) {
    console.error('Error handling failed tokens:', error);
  }
}

// API endpoint to manually trigger a check (for testing)
app.post('/api/check-vehicles', async (req, res) => {
  try {
    // Get vehicles that are active but might not have triggered a notification
    const vehiclesSnapshot = await db.collection('vehicles')
      .where('status', '==', 'Active')
      .get();
    
    let processedCount = 0;
    
    for (const doc of vehiclesSnapshot.docs) {
      const vehicleData = doc.data();
      const wardNumber = vehicleData.ward_number;
      
      // Check if we've already processed this status change
      const statusTrackingRef = db.collection('vehicle_status_tracking').doc(doc.id);
      const statusTracking = await statusTrackingRef.get();
      
      if (!statusTracking.exists || statusTracking.data().status !== 'Active') {
        // Notify users about this active vehicle
        await notifyUsersInWard(wardNumber, doc.id, vehicleData);
        
        // Update tracking document
        await statusTrackingRef.set({
          status: 'Active',
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        
        processedCount++;
      }
    }
    
    res.status(200).json({ 
      message: 'Vehicle check completed', 
      processed: processedCount 
    });
  } catch (error) {
    console.error('Error in manual check:', error);
    res.status(500).json({ error: 'Failed to check vehicles' });
  }
});

// API endpoint to register FCM tokens
app.post('/api/register-token', async (req, res) => {
  try {
    const { userId, token } = req.body;
    
    if (!userId || !token) {
      return res.status(400).json({ error: 'User ID and token are required' });
    }
    
    await db.collection('users').doc(userId).update({
      fcmToken: token,
      tokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({ message: 'FCM token registered successfully' });
  } catch (error) {
    console.error('Error registering FCM token:', error);
    res.status(500).json({ error: 'Failed to register FCM token' });
  }
});