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

app.listen(process.env.PORT || 5000,'0.0.0.0', () => {
  console.log(`Server is running on port ${process.env.PORT || 3000}`);
  
  const vehiclesRef = db.collection('vehicles');
  
  vehiclesRef.onSnapshot(snapshot => {
    snapshot.docChanges().forEach(async change => {
      if (change.type === 'modified') {
        const vehicleData = change.doc.data();
        
        const statusTrackingRef = db.collection('vehicle_status_tracking').doc(change.doc.id);
        const statusTracking = await statusTrackingRef.get();
        
        const previousStatus = statusTracking.exists ? statusTracking.data().status : null;
        
        if (previousStatus === 'Inactive' && vehicleData.status === 'Active') {
          
          const wardNumber = vehicleData.ward_no;
          console.log(`Vehicle ${change.doc.id} in ward ${wardNumber} changed from Inactive to Active`);
          
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

async function notifyUsersInWard(wardNumber, vehicleId, vehicleData) {
  try {
    const usersSnapshot = await db.collection('users')
      .where('ward_number', '==', wardNumber)
      .get();
    
    if (usersSnapshot.empty) {
      console.log(`No users found in ward ${wardNumber}`);
      return;
    }
    
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
    
    const batchResponse = await sendNotificationsInBatches(tokens, message);
    console.log(`Successfully sent ${batchResponse.successCount} notifications out of ${tokens.length}`);
    
    if (batchResponse.failedTokens.length > 0) {
      await handleFailedTokens(batchResponse.failedTokens);
    }
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
}

// send notifications in batches (FCM has a limit of 500 recipients per request)
async function sendNotificationsInBatches(tokens, messageData) {
  const batchSize = 500;
  const batches = [];
  
  for (let i = 0; i < tokens.length; i += batchSize) {
    batches.push(tokens.slice(i, i + batchSize));
  }
  
  let successCount = 0;
  const failedTokens = [];
  
  for (const batch of batches) {
    try {
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
      failedTokens.push(...batch);
    }
  }

  return {
    successCount,
    failedTokens
  };
}

async function handleFailedTokens(failedTokens) {
  try {
    for (const token of failedTokens) {
      const userSnapshot = await db.collection('users')
        .where('fcmToken', '==', token)
        .get();
      
      if (!userSnapshot.empty) {
        userSnapshot.forEach(async doc => {
          await db.collection('users').doc(doc.id).update({
            fcmToken: admin.firestore.FieldValue.delete()
          });
          console.log(`Removed invalid FCM token for user ${doc.id}`);
        });
      }
    }
  } catch (error) {
    console.error('Error handling failed tokens:', error);
  }
}

