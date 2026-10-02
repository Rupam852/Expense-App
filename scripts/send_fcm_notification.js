/**
 * Grow Expense - FCM Push Notification Dispatcher
 * Directly sends background/push notifications to users using Firebase Admin SDK.
 * 
 * Usage:
 *   node scripts/send_fcm_notification.js --token <FCM_TOKEN> --title "Alert" --body "Hello"
 *   node scripts/send_fcm_notification.js --broadcast --title "🚀 Naya Update!" --body "Version 1.0.5 ready"
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.resolve(__dirname, '../groww-expense-firebase-adminsdk-fbsvc-5909ce3f5d.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account key not found at:', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function sendPushNotification({ token, title, body, data = {}, channelId = 'general_alerts_channel' }) {
  try {
    const stringData = {};
    Object.keys(data).forEach(k => {
      stringData[k] = typeof data[k] === 'string' ? data[k] : JSON.stringify(data[k]);
    });

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        channel_id: channelId,
        ...stringData,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: channelId,
          icon: 'ic_launcher',
          color: '#00D09C',
          sound: 'default',
          priority: 'max',
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Push notification sent successfully! Message ID:', response);
    return response;
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    throw error;
  }
}

// Example quick test if executed directly
if (require.main === module) {
  const args = process.argv.slice(2);
  const tokenArgIndex = args.indexOf('--token');
  const titleArgIndex = args.indexOf('--title');
  const bodyArgIndex = args.indexOf('--body');

  const token = tokenArgIndex !== -1 ? args[tokenArgIndex + 1] : null;
  const title = titleArgIndex !== -1 ? args[titleArgIndex + 1] : '🔔 Grow Expense Alert';
  const body = bodyArgIndex !== -1 ? args[bodyArgIndex + 1] : 'Ye notification app band hone par bhi aayega!';

  if (!token) {
    console.log('Usage: node scripts/send_fcm_notification.js --token <DEVICE_FCM_TOKEN> --title "..." --body "..."');
    console.log('\nFirebase Admin SDK is initialized and ready for groww-expense!');
  } else {
    sendPushNotification({ token, title, body })
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
  }
}

module.exports = { sendPushNotification, admin };
